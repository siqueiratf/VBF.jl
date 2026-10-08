# Implements fast exact counters for the last extension step (n-1 -> n variables)
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8)
# Source: Beierle et al. (2025, v2), Theorem 4.1 and Lemma 4.5
#
# Math:
#   For a quadratic APN (nv,m)-function G with bilinear form B, the number of APN
#   completions is e(G) = #{ L linear : L(alpha) not in I_alpha for all alpha != 0 },
#   I_alpha = Im B(alpha, .).  The group Lambda = { x -> B(x, beta) : beta in F_2^nv } of
#   linear maps acts freely on the set of completions (Lemma 4.5): L + B(., beta) is a
#   completion iff L is one, and B(., beta) = 0 only for beta = 0.  So e(G) = 2^nv * c,
#   where c counts canonical completions:
#     - beta moves L(e_1) through its coset L(e_1) + I_{e_1} (2^(nv-1) values), so L(e_1)
#       runs over one representative per non-trivial coset of I_{e_1};
#     - only beta in {0, e_1} fixes L(e_1); beta = e_1 maps L(e_2) to L(e_2) + B(e_2, e_1),
#       so L(e_2) is taken up to this involution (keep the smaller of the two values).
#   The constraint "L(a) + L(e_k) not in I_{a|e_k}" means "L(e_k) not in the coset
#   L(a) + I_{a|e_k}".  Each coset is a precomputed 256-bit mask (m <= 8), so a level's
#   forbidden set is an OR of masks.
#
# Pseudocode (FL3, the production counter):
#   1. Precompute coset ids cid[v, alpha] and coset masks of every I_alpha.
#   2. For each canonical L(e_1): choose(d=1).
#   3. choose(d, k, b): set L(e_k) = b on the span of the chosen vectors;
#        forward checking: update the forbidden mask of every unchosen e_kk with the
#        new cosets; if a mask is full, return 0.
#        At depth nv return 1 (or record the solution).
#   4. level(d): pick e_2 at d = 2 (symmetry reduction), else the unchosen e_kk with the
#        fewest free values (fail-first); at the last level count free values directly.
#   5. e(G) = 2^nv * (number of canonical leaves).
#
# Module FL:  plain backtracking with coset masks (reference).
# Module FL2: FL + forward checking.
# Module FL3: FL2 + fail-first ordering (used by sampler.jl).
# All three return (e, solutions); `want_solution = true` lists the canonical solutions
# [L(e_1), ..., L(e_nv)] (in original coordinates), one per Lambda-orbit.
# VBF API used: none.
module FL

using ..QK

const M4 = NTuple{4,UInt64}
@inline mor(a::M4, b::M4) = (a[1] | b[1], a[2] | b[2], a[3] | b[3], a[4] | b[4])
@inline popc(a::M4) = count_ones(a[1]) + count_ones(a[2]) + count_ones(a[3]) + count_ones(a[4])
@inline hasbit(a::M4, v::Integer) = (a[(v >> 6) + 1] >> (v & 63)) & 1 == 1
function setbit(a::M4, v::Integer)
    w = (v >> 6) + 1
    t = collect(a)
    t[w] |= UInt64(1) << (v & 63)
    (t[1], t[2], t[3], t[4])
end

struct Pre
    nv::Int
    m::Int
    cid::Matrix{UInt8}      # cid[v+1, alpha]: coset id of v in F_2^m / I_alpha
    cmask::Vector{Vector{M4}} # cmask[alpha][c+1]: mask of coset c of I_alpha
    outside::M4             # values >= 2^m (forbidden when m < 8)
    Bij::Matrix{UInt16}     # B(e_i, e_j)
    I1::Vector{UInt16}      # elements of I_{e1}
end

function prepare(C::Matrix{UInt16}, nv::Int, m::Int)
    I = QK.images(C, nv, m)
    I === nothing && return nothing
    na = (1 << nv) - 1
    cid = zeros(UInt8, 256, na)
    cmask = Vector{Vector{M4}}(undef, na)
    for α in 1:na
        inI = falses(256)
        for y in I[α]
            inI[y + 1] = true
        end
        ids = fill(0xff, 256)
        masks = M4[]
        nxt = 0
        for v in 0:(1 << m) - 1
            ids[v + 1] != 0xff && continue
            mk = (UInt64(0), UInt64(0), UInt64(0), UInt64(0))
            for y in I[α]
                w = v ⊻ y
                ids[w + 1] = UInt8(nxt)
                mk = setbit(mk, w)
            end
            push!(masks, mk)
            nxt += 1
        end
        cid[:, α] = ids
        cmask[α] = masks
    end
    outside = (UInt64(0), UInt64(0), UInt64(0), UInt64(0))
    for v in (1 << m):255
        outside = setbit(outside, v)
    end
    Bij = zeros(UInt16, nv, nv)
    for i in 1:nv, j in 1:nv
        Bij[i, j] = C[i, j]
    end
    Pre(nv, m, cid, cmask, outside, Bij, I[1])
end

# forbidden mask for L(e_k) given L on span(e_1..e_{k-1})
@inline function forb(p::Pre, L::Vector{UInt16}, k::Int)
    hk = 1 << (k - 1)
    f = p.outside
    @inbounds for a in 0:hk - 1
        α = a | hk
        f = mor(f, p.cmask[α][p.cid[L[a + 1] + 1, α] + 1])
    end
    f
end

"""
    count_completions(C, nv, m; want_solution = false) -> (e, sols)

Exact `e(G)` as an `Int`. With `want_solution = true`, `sols` lists the canonical
solutions (one per orbit of the free action); otherwise `sols` is `nothing`.
"""
function count_completions(C::Matrix{UInt16}, nv::Int, m::Int; want_solution::Bool = false)
    nv >= 2 || error("nv >= 2 needed")
    p = prepare(C, nv, m)
    p === nothing && return (0, nothing)
    L = zeros(UInt16, 1 << nv)
    sol = Ref{Any}(nothing)
    # level 1: one representative per non-trivial coset of I_{e1}
    f1 = forb(p, L, 1)
    reps = UInt16[]
    seen = Set{UInt8}()
    for v in 0:(1 << m) - 1
        hasbit(f1, v) && continue
        c = p.cid[v + 1, 1]
        c in seen && continue
        push!(seen, c)
        push!(reps, v)
    end
    tot = 0
    b21 = p.Bij[2, 1]
    for r in reps
        L[2] = r
        tot += _rec(p, L, 2, nv, b21, sol, want_solution)
    end
    (tot << nv, sol[])
end

function _rec(p::Pre, L, k, nv, b21, sol, want)
    f = forb(p, L, k)
    if k == nv && !want
        c = 256 - popc(f)
        k == 2 && (c = _count_half(f, b21))
        return c
    end
    hk = 1 << (k - 1)
    tot = 0
    @inbounds for w in 1:4
        word = ~f[w]
        while word != 0
            t = trailing_zeros(word)
            word &= word - 1
            b = UInt16(((w - 1) << 6) + t)
            k == 2 && (b ⊻ b21) < b && continue
            if k == nv
                sol[] === nothing && (sol[] = Vector{Vector{UInt16}}())
                push!(sol[], [[L[(1 << (i - 1)) + 1] for i in 1:nv - 1]; b])
                tot += 1
                continue
            end
            for a in 0:hk - 1
                L[(a | hk) + 1] = L[a + 1] ⊻ b
            end
            tot += _rec(p, L, k + 1, nv, b21, sol, want)
        end
    end
    tot
end

function _count_half(f::M4, b21)
    c = 0
    for v in 0:255
        hasbit(f, v) && continue
        (v ⊻ b21) < v && continue
        c += 1
    end
    c
end

end

# Forward-checking version (same result as count_completions).
module FL2
using ..QK, ..FL
const M4 = FL.M4
@inline full(a::M4) = (a[1] & a[2] & a[3] & a[4]) == typemax(UInt64)

struct Ctx
    nv::Int
    ncos::Int
    cid::Matrix{UInt8}
    cm::Vector{M4}
    P::Matrix{M4}          # P[d, k']: forbidden mask for level k' given L on span(e_1..e_{d-1})
    L::Vector{UInt16}
    b21::UInt16
    want::Bool
    sols::Vector{Vector{UInt16}}
end

@inline cmask(c::Ctx, α::Int, v::UInt16) = @inbounds c.cm[(α - 1) * c.ncos + c.cid[v + 1, α] + 1]

function count_completions(C::Matrix{UInt16}, nv::Int, m::Int; want_solution::Bool = false)
    p = FL.prepare(C, nv, m)
    p === nothing && return (0, nothing)
    na = (1 << nv) - 1
    ncos = maximum(length(p.cmask[α]) for α in 1:na)
    cm = Vector{M4}(undef, na * ncos)
    for α in 1:na, c in 1:length(p.cmask[α])
        cm[(α - 1) * ncos + c] = p.cmask[α][c]
    end
    P = Matrix{M4}(undef, nv + 1, nv)
    c = Ctx(nv, ncos, p.cid, cm, P, zeros(UInt16, 1 << nv), p.Bij[2, 1], want_solution, Vector{Vector{UInt16}}())
    for k in 1:nv
        P[1, k] = FL.mor(p.outside, cmask(c, 1 << (k - 1), UInt16(0)))
    end
    # level 1: one representative per non-trivial coset of I_{e1}
    seen = falses(256)
    tot = 0
    f1 = P[1, 1]
    for v in 0:(1 << m) - 1
        FL.hasbit(f1, v) && continue
        cidv = p.cid[v + 1, 1]
        seen[cidv + 1] && continue
        seen[cidv + 1] = true
        tot += _choose(c, 1, UInt16(v))
    end
    (tot << nv, want_solution ? c.sols : nothing)
end

# set L(e_d) = b, update future masks, recurse; returns canonical count below
function _choose(c::Ctx, d::Int, b::UInt16)
    hd = 1 << (d - 1)
    L = c.L
    @inbounds for a in 0:hd - 1
        L[(a | hd) + 1] = L[a + 1] ⊻ b
    end
    nv = c.nv
    if d == nv
        c.want && push!(c.sols, [L[(1 << (i - 1)) + 1] for i in 1:nv])
        return 1
    end
    P = c.P
    @inbounds for k in d + 1:nv
        hk = 1 << (k - 1)
        f = P[d, k]
        for a in hd:(2hd - 1)
            f = FL.mor(f, cmask(c, a | hk, L[a + 1]))
        end
        full(f) && return 0
        P[d + 1, k] = f
    end
    _level(c, d + 1)
end

function _level(c::Ctx, d::Int)
    f = c.P[d, d]
    nv = c.nv
    if d == nv && !c.want
        d == 2 && return FL._count_half(f, c.b21)
        return 256 - FL.popc(f)
    end
    tot = 0
    @inbounds for w in 1:4
        word = ~f[w]
        while word != 0
            t = trailing_zeros(word)
            word &= word - 1
            b = UInt16(((w - 1) << 6) + t)
            d == 2 && (b ⊻ c.b21) < b && continue
            tot += _choose(c, d, b)
        end
    end
    tot
end
end

# Forward checking + dynamic ordering of basis vectors 3..nv (fail-first).
module FL3
using ..QK, ..FL
const M4 = FL.M4
@inline full(a::M4) = (a[1] & a[2] & a[3] & a[4]) == typemax(UInt64)

mutable struct Ctx
    nv::Int
    ncos::Int
    cid::Matrix{UInt8}
    cm::Vector{M4}
    P::Matrix{M4}          # P[d, k]: forbidden mask for basis vector k given the first d-1 chosen vectors
    L::Vector{UInt16}      # L over span of chosen vectors, chosen-order index
    A::Vector{Int}         # A[a+1]: original-coordinate alpha of chosen-order index a
    used::Vector{Bool}
    perm::Vector{Int}
    b21::UInt16
    want::Bool
    sols::Vector{Vector{UInt16}}
end

@inline cmask(c::Ctx, α::Int, v::UInt16) = @inbounds c.cm[(α - 1) * c.ncos + c.cid[v + 1, α] + 1]

function count_completions(C::Matrix{UInt16}, nv::Int, m::Int; want_solution::Bool = false)
    p = FL.prepare(C, nv, m)
    p === nothing && return (0, nothing)
    na = (1 << nv) - 1
    ncos = maximum(length(p.cmask[α]) for α in 1:na)
    cm = Vector{M4}(undef, na * ncos)
    for α in 1:na, c in 1:length(p.cmask[α])
        cm[(α - 1) * ncos + c] = p.cmask[α][c]
    end
    P = Matrix{M4}(undef, nv + 1, nv)
    c = Ctx(nv, ncos, p.cid, cm, P, zeros(UInt16, 1 << nv), zeros(Int, 1 << nv),
            fill(false, nv), zeros(Int, nv), p.Bij[2, 1], want_solution, Vector{Vector{UInt16}}())
    for k in 1:nv
        P[1, k] = FL.mor(p.outside, cmask(c, 1 << (k - 1), UInt16(0)))
    end
    seen = falses(256)
    tot = 0
    f1 = P[1, 1]
    for v in 0:(1 << m) - 1
        FL.hasbit(f1, v) && continue
        cidv = p.cid[v + 1, 1]
        seen[cidv + 1] && continue
        seen[cidv + 1] = true
        tot += _choose(c, 1, 1, UInt16(v))
    end
    (tot << nv, want_solution ? c.sols : nothing)
end

# choose basis vector k as the d-th chosen vector with value b
function _choose(c::Ctx, d::Int, k::Int, b::UInt16)
    hd = 1 << (d - 1)
    L = c.L; A = c.A
    hk0 = 1 << (k - 1)
    @inbounds for a in 0:hd - 1
        L[(a | hd) + 1] = L[a + 1] ⊻ b
        A[(a | hd) + 1] = A[a + 1] | hk0
    end
    c.used[k] = true; c.perm[d] = k
    nv = c.nv
    if d == nv
        if c.want
            sol = zeros(UInt16, nv)
            for i in 1:nv
                sol[c.perm[i]] = L[(1 << (i - 1)) + 1]
            end
            push!(c.sols, sol)
        end
        c.used[k] = false
        return 1
    end
    P = c.P
    ok = true
    @inbounds for kk in 1:nv
        c.used[kk] && continue
        hk = 1 << (kk - 1)
        f = P[d, kk]
        for a in hd:(2hd - 1)
            f = FL.mor(f, cmask(c, A[a + 1] | hk, L[a + 1]))
        end
        if full(f)
            ok = false
            break
        end
        P[d + 1, kk] = f
    end
    r = ok ? _level(c, d + 1) : 0
    c.used[k] = false
    r
end

function _level(c::Ctx, d::Int)
    nv = c.nv
    # pick next basis vector: e2 at d == 2 (symmetry reduction), else fewest free values
    if d == 2
        k = 2
    else
        k = 0; best = 1000
        @inbounds for kk in 1:nv
            c.used[kk] && continue
            fr = 256 - FL.popc(c.P[d, kk])
            if fr < best
                best = fr; k = kk
            end
        end
    end
    f = c.P[d, k]
    if d == nv && !c.want
        d == 2 && return FL._count_half(f, c.b21)
        return 256 - FL.popc(f)
    end
    tot = 0
    @inbounds for w in 1:4
        word = ~f[w]
        while word != 0
            t = trailing_zeros(word)
            word &= word - 1
            b = UInt16(((w - 1) << 6) + t)
            d == 2 && (b ⊻ c.b21) < b && continue
            tot += _choose(c, d, k, b)
        end
    end
    tot
end
end
