"""
Quadratic APN coefficient trees and exact one-input extensions.

For homogeneous quadratic `F`, an extension `F(x) + t L(x)` is APN iff
`L(a)` lies outside the polar image `Im B(a,.)` for every nonzero `a`.
The optimized counter quotients the free action `L -> L+B(.,b)` and returns
one representative per orbit, with the raw count multiplied by `2^nv`.
See Beierle et al. (2025, v2), Theorem 4.1 and Lemma 4.5.
Knuth weights count coefficient tuples, not equivalence classes.
"""
module QuadraticAPNTree
using Random
using ..VBF: linear_basis
export images, free_values!, probe, exact_count, gl_order, lut, logsumexp,
       reference_completions, count_completions, encode_coeffs, decode_coeffs,
       coeff_matrix_from_lut, probe_to_penultimate, EnumerationLimitError

"A finite enumeration stopped before obtaining an exact answer."
struct EnumerationLimitError <: Exception
    max_nodes::Int
end
Base.showerror(io::IO, e::EnumerationLimitError) = print(io, "enumeration node budget exhausted (",e.max_nodes,"); no exact count established")
mutable struct Budget
    nodes::Int
    maximum::Int
end
function Budget(max_nodes::Integer)
    0 <= max_nodes <= typemax(Int) || throw(ArgumentError("invalid max_nodes"))
    Budget(0,Int(max_nodes))
end
function tick!(b::Budget)
    b.nodes < b.maximum || throw(EnumerationLimitError(b.maximum))
    b.nodes += 1
end

function check_matrix(C, nv, m)
    1 <= nv <= 8 && 1 <= m <= 8 || throw(ArgumentError("supports 1 <= nv,m <= 8"))
    size(C,1) >= nv && size(C,2) >= nv || throw(ArgumentError("coefficient matrix is too small"))
    for i in 1:nv, j in 1:nv
        C[i,j] == C[j,i] || throw(ArgumentError("expected symmetric coefficients"))
        0 <= C[i,j] < 1<<m || throw(ArgumentError("coefficient outside output dimension"))
        i == j && C[i,j] != 0 && throw(ArgumentError("expected zero diagonal"))
    end
    nothing
end

"Encode byte-valued symmetric quadratic coefficients in lexicographic pair order."
function encode_coeffs(C::Matrix{UInt16}, n::Int)
    check_matrix(C,n,8)
    join(string(C[a,b];base=16,pad=2) for a in 1:n for b in a+1:n)
end
"Decode lexicographic pairs into a symmetric matrix with zero diagonal."
function decode_coeffs(coeffs::AbstractString,n::Int)
    1 <= n <= 8 || throw(ArgumentError("supports 1 <= n <= 8"))
    length(coeffs)==n*(n-1) || throw(ArgumentError("wrong coefficient string length"))
    bytes=hex2bytes(coeffs); C=zeros(UInt16,n,n);t=0
    for a in 1:n,b in a+1:n
        t+=1;C[a,b]=C[b,a]=bytes[t]
    end
    C
end

"Extract the homogeneous degree-two part of a byte LUT; rejects degree > 2."
function coeff_matrix_from_lut(lut::AbstractVector)
    n=trailing_zeros(length(lut))
    1 <= n <= 8 && length(lut)==1<<n || throw(ArgumentError("expected power-of-two LUT of 2..256 entries"))
    all(x->x isa Integer && 0<=x<=255,lut) || throw(ArgumentError("expected byte values"))
    anf=UInt16.(lut)
    for bit in 0:n-1,x in 0:(1<<n)-1
        x&(1<<bit)==0 || (anf[x+1] ⊻= anf[(x⊻(1<<bit))+1])
    end
    any(x->count_ones(x)>2 && anf[x+1]!=0,0:(1<<n)-1) && throw(ArgumentError("LUT is not quadratic"))
    C=zeros(UInt16,n,n)
    for i in 1:n,j in i+1:n
        C[i,j]=C[j,i]=anf[((1<<(i-1))|(1<<(j-1)))+1]
    end
    C
end


"""
    images(C, nv, m) -> Vector{Vector{UInt16}} or nothing

Image `I_alpha = { B(alpha, x) : x }` of the bilinear form of the pure quadratic
function on `nv` variables with coefficient matrix `C`, for every `alpha` in
`1:2^nv-1`. Returns `nothing` when some kernel is larger than `{0, alpha}`, that is,
when the function is not APN.
"""
function images(C::Matrix{UInt16}, nv::Int, m::Int)
    check_matrix(C,nv,m)
    out = Vector{Vector{UInt16}}(undef, (1 << nv) - 1)
    rows = zeros(UInt16, nv)
    for α in 1:(1 << nv) - 1
        for j in 1:nv
            r = UInt16(0)
            for i in 1:nv
                (α >> (i - 1)) & 1 == 1 && (r ⊻= C[i, j])
            end
            rows[j] = r
        end
        basis = linear_basis(rows; nbits=m)
        length(basis) == nv - 1 || return nothing
        els = Vector{UInt16}(undef, 1 << (nv - 1))
        els[1] = 0
        for (t, b) in enumerate(basis)
            h = 1 << (t - 1)
            for s in 1:h
                els[h + s] = els[s] ⊻ b
            end
        end
        out[α] = els
    end
    out
end

"""
    free_values!(forb, L, I, k, m) -> forb

Mark in `forb` the values that `L(e_k)` must avoid, given `L` on
`span(e_1..e_{k-1})` (indices `0:2^(k-1)-1`): the union of `L(a) + I_{a|e_k}`.
"""
function free_values!(forb::BitVector, L::Vector{UInt16}, I, k::Int, m::Int)
    1 <= k <= 8 && 1 <= m <= 8 && length(forb)==1<<m || throw(ArgumentError("invalid forbidden-set dimensions"))
    fill!(forb, false)
    hk = 1 << (k - 1)
    for a in 0:hk - 1
        base = L[a + 1]
        for y in I[a | hk]
            forb[(base ⊻ y) + 1] = true
        end
    end
    forb
end

"""
    probe(rng, n, m) -> (logw, C, nreached)

One plain Knuth probe down to `n` variables. `logw = -Inf` on a dead end.
"""
function probe(rng::AbstractRNG, n::Int, m::Int)
    2 <= n <= 8 && 1 <= m <= 8 || throw(ArgumentError("supports 2 <= n <= 8, 1 <= m <= 8"))
    C = zeros(UInt16, n, n)
    forb = falses(1 << m)
    logw = 0.0
    free = Vector{UInt16}(undef, 1 << m)
    for nv in 1:n - 1
        I = images(C, nv, m)
        I === nothing && error("internal: non-APN node")
        L = zeros(UInt16, 1 << nv)
        for k in 1:nv
            free_values!(forb, L, I, k, m)
            d = 0
            @inbounds for b in 0:(1 << m) - 1
                if !forb[b + 1]
                    d += 1
                    free[d] = b
                end
            end
            d == 0 && return (-Inf, C, nv)
            logw += log(d)
            b = free[rand(rng, 1:d)]
            C[k, nv + 1] = b
            C[nv + 1, k] = b
            hk = 1 << (k - 1)
            @inbounds for a in 0:hk - 1
                L[(a | hk) + 1] = L[a + 1] ⊻ b
            end
        end
    end
    (logw, C, n)
end

"""
    exact_count(n, m) -> BigInt

Exact number `T(n,m)` of leaves of the extension tree, by depth-first search.
Small cases only (the tree has `T(n,m)` leaves).
"""
function exact_count(n::Int, m::Int; max_nodes::Integer=10_000_000)
    1 <= n <= 8 && 1 <= m <= 8 || throw(ArgumentError("supports 1 <= n,m <= 8"))
    C = zeros(UInt16, n, n)
    check_matrix(C,n,m)
    _dfs(C, 1, n, m, Budget(max_nodes))
end

function _dfs(C, nv, n, m, budget)
    tick!(budget)
    nv == n && return big(1)
    I = images(C, nv, m)
    L = zeros(UInt16, 1 << nv)
    _dfs_k(C, nv, 1, n, m, I, L, budget)
end

function _dfs_k(C, nv, k, n, m, I, L, budget)
    tick!(budget)
    if k > nv
        return _dfs(C, nv + 1, n, m, budget)
    end
    forb = free_values!(falses(1 << m), L, I, k, m)
    tot = big(0)
    hk = 1 << (k - 1)
    for b in 0:(1 << m) - 1
        forb[b + 1] && continue
        C[k, nv + 1] = b; C[nv + 1, k] = b
        for a in 0:hk - 1
            L[(a | hk) + 1] = L[a + 1] ⊻ UInt16(b)
        end
        tot += _dfs_k(C, nv, k + 1, n, m, I, L, budget)
    end
    C[k, nv + 1] = 0; C[nv + 1, k] = 0
    tot
end

"`|GL(n,2)|` as a `BigInt`."
gl_order(n::Integer) = (n >= 0 || throw(ArgumentError("negative dimension")); prod((big(2)^n - big(2)^i for i in 0:n-1); init=big(1)))

"""
    lut(C, n) -> Vector{UInt16}

Lookup table of the pure quadratic function with coefficient matrix `C`
(`lut[x+1] = F(x)`), for checks with VBF.
"""
function lut(C::Matrix{UInt16}, n::Int)
    check_matrix(C,n,8)
    out = zeros(UInt16, 1 << n)
    for x in 0:(1 << n) - 1
        v = UInt16(0)
        for i in 1:n, j in i + 1:n
            ((x >> (i - 1)) & 1 == 1 && (x >> (j - 1)) & 1 == 1) && (v ⊻= C[i, j])
        end
        out[x + 1] = v
    end
    out
end

"Numerically stable `log(sum(exp.(v)))`."
logsumexp(v) = (mx = maximum(v); isfinite(mx) ? mx + log(sum(exp.(v .- mx))) : mx)

function reference_completions(C::Matrix{UInt16}, nv::Int, m::Int; keep::Int = 0, max_nodes::Integer=10_000_000)
    keep >= 0 || throw(ArgumentError("negative keep"))
    I = images(C, nv, m)
    I === nothing && return (0,Vector{Vector{UInt16}}())
    L = zeros(UInt16, 1 << nv)
    sols = Vector{Vector{UInt16}}()
    forbs = [falses(1 << m) for _ in 1:nv]
    cnt = _reference_rec(I, L, 1, nv, m, forbs, sols, keep, Budget(max_nodes))
    cnt, sols
end

function _reference_rec(I, L, k, nv, m, forbs, sols, keep, budget)
    tick!(budget)
    forb = free_values!(forbs[k], L, I, k, m)
    if k == nv
        c = (1 << m) - count(forb)
        if keep > length(sols)
            for b in 0:(1 << m) - 1
                forb[b + 1] && continue
                # L(e_1..e_{nv-1}) are pairwise distinct and nonzero (0 is in every I_alpha).
                sol = UInt16[L[(1 << (i - 1)) + 1] for i in 1:nv - 1]
                push!(sol, UInt16(b))
                push!(sols, sol)
                length(sols) >= keep && break
            end
        end
        return c
    end
    tot = big(0)
    hk = 1 << (k - 1)
    for b in 0:(1 << m) - 1
        forb[b + 1] && continue
        @inbounds for a in 0:hk - 1
            L[(a | hk) + 1] = L[a + 1] ⊻ UInt16(b)
        end
        tot += _reference_rec(I, L, k + 1, nv, m, forbs, sols, keep, budget)
    end
    tot
end

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
    I = images(C, nv, m)
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

function _count_half(f::M4, b21)
    c = 0
    for v in 0:255
        hasbit(f, v) && continue
        (v ⊻ b21) < v && continue
        c += 1
    end
    c
end

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
    budget::Budget
end

@inline cmask(c::Ctx, α::Int, v::UInt16) = @inbounds c.cm[(α - 1) * c.ncos + c.cid[v + 1, α] + 1]

"""
    count_completions(C, nv, m; want_solution=false, max_nodes=10_000_000)

Exact raw extension count, optionally with one representative per polar-translation
orbit. Supports 2 <= nv <= 7 and byte outputs. A node-budget stop throws
`EnumerationLimitError` and supplies no exact count or exhaustion claim.
"""
function count_completions(C::Matrix{UInt16}, nv::Int, m::Int; want_solution::Bool = false, max_nodes::Integer=10_000_000)
    2 <= nv <= 7 || throw(ArgumentError("optimized extensions support 2 <= nv <= 7"))
    budget=Budget(max_nodes)
    p = prepare(C, nv, m)
    p === nothing && return (0, want_solution ? Vector{Vector{UInt16}}() : nothing)
    na = (1 << nv) - 1
    ncos = maximum(length(p.cmask[α]) for α in 1:na)
    cm = Vector{M4}(undef, na * ncos)
    for α in 1:na, c in 1:length(p.cmask[α])
        cm[(α - 1) * ncos + c] = p.cmask[α][c]
    end
    P = Matrix{M4}(undef, nv + 1, nv)
    c = Ctx(nv, ncos, p.cid, cm, P, zeros(UInt16, 1 << nv), zeros(Int, 1 << nv),
            fill(false, nv), zeros(Int, nv), p.Bij[2, 1], want_solution, Vector{Vector{UInt16}}(),budget)
    for k in 1:nv
        P[1, k] = mor(p.outside, cmask(c, 1 << (k - 1), UInt16(0)))
    end
    seen = falses(256)
    tot = 0
    f1 = P[1, 1]
    for v in 0:(1 << m) - 1
        hasbit(f1, v) && continue
        cidv = p.cid[v + 1, 1]
        seen[cidv + 1] && continue
        seen[cidv + 1] = true
        tot += _choose(c, 1, 1, UInt16(v))
    end
    (tot << nv, want_solution ? c.sols : nothing)
end

# choose basis vector k as the d-th chosen vector with value b
function _choose(c::Ctx, d::Int, k::Int, b::UInt16)
    tick!(c.budget)
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
            f = mor(f, cmask(c, A[a + 1] | hk, L[a + 1]))
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
            fr = 256 - popc(c.P[d, kk])
            if fr < best
                best = fr; k = kk
            end
        end
    end
    f = c.P[d, k]
    if d == nv && !c.want
        d == 2 && return _count_half(f, c.b21)
        return 256 - popc(f)
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
"Knuth probe to n-1 variables; weights count coefficient tuples."
function probe_to_penultimate(rng, n::Int, m::Int)
    3 <= n <= 8 && 1 <= m <= 8 || throw(ArgumentError("supports 3 <= n <= 8, 1 <= m <= 8"))
    C = zeros(UInt16, n, n)
    forb = falses(1 << m)
    free = Vector{UInt16}(undef, 1 << m)
    logw = 0.0
    for nv in 1:n - 2
        I = images(C, nv, m)
        L = zeros(UInt16, 1 << nv)
        for k in 1:nv
            free_values!(forb, L, I, k, m)
            d = 0
            @inbounds for b in 0:(1 << m) - 1
                forb[b + 1] || (d += 1; free[d] = b)
            end
            d == 0 && return (-Inf, C)
            logw += log(d)
            b = free[rand(rng, 1:d)]
            C[k, nv + 1] = b
            C[nv + 1, k] = b
            hk = 1 << (k - 1)
            @inbounds for a in 0:hk - 1
                L[(a | hk) + 1] = L[a + 1] ⊻ b
            end
        end
    end
    (logw, C)
end

end
