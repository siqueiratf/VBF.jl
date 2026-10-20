# Faster Lee-Brickell re-extension of U_8 at n = 10 (replaces extensions_isd of
# exchange_n10.jl in production; that function stays as the reference).
#
# The code is {(<w', x>)_{w in Z} : x in F_2^46} with w' = w | 1 << 45, so bit 45 of
# x selects the all-ones row. A wanted word is 1 + c_t with weight |Z(t)| <= |Z|/3.
# Each iteration takes a random information set of independent columns w', the
# dual vectors d_i with <w'_j, d_i> = delta_ij, the packed codewords of the d_i,
# and then tests the weights of every d_i and d_i + d_j (p <= 2).
include(joinpath(@__DIR__, "exchange_n10.jl"))
using Random

const ONE = UInt64(1) << NP                             # bit 45: the all-ones row
const TMASK = ONE - UInt64(1)

struct ISDProblem
    Z::Vector{UInt64}                                   # flats of U^perp, with bit 45 set
    k::Int                                              # rank of the columns
    W::Int                                              # words of a packed codeword
end
function ISDProblem(Ub, flats)
    Z = [w | ONE for w in flats if orth(w, Ub)]
    ISDProblem(Z, rank_f2(Z), cld(length(Z), 64))
end

# Dual vectors of a random information set. Returns false if the draw is short.
function draw_dual!(d, P::ISDProblem, perm, rng)
    shuffle!(rng, perm)
    basis = zeros(UInt64, 64); sel = UInt64[]
    for idx in perm                                     # incremental xor basis by highest bit
        x = P.Z[idx]; y = x
        while y != 0
            h = 63 - leading_zeros(y)
            basis[h+1] == 0 && break
            y ⊻= basis[h+1]
        end
        y == 0 && continue
        basis[63-leading_zeros(y)+1] = y; push!(sel, x)
        length(sel) == P.k && break
    end
    length(sel) == P.k || return false
    # RREF of the k selected columns, with identity tags E.
    rows = copy(sel); tags = [UInt64(1) << (i - 1) for i in 1:P.k]; piv = zeros(Int, P.k); r = 0
    for c in 0:NP
        p = 0
        for i in r+1:P.k
            if (rows[i] >> c) & 1 == 1; p = i; break; end
        end
        p == 0 && continue
        r += 1
        rows[r], rows[p] = rows[p], rows[r]; tags[r], tags[p] = tags[p], tags[r]
        for i in 1:P.k
            if i != r && (rows[i] >> c) & 1 == 1
                rows[i] ⊻= rows[r]; tags[i] ⊻= tags[r]
            end
        end
        piv[r] = c
    end
    # d_i = sum_r E[r, i] * e_{p_r}
    fill!(d, 0)
    for rr in 1:P.k, i in 1:P.k
        (tags[rr] >> (i - 1)) & 1 == 1 && (d[i] |= UInt64(1) << piv[rr])
    end
    true
end

function pack_rows!(R, d, P::ISDProblem)
    fill!(R, 0)
    @inbounds for (z, w) in enumerate(P.Z)
        word = (z - 1) >> 6 + 1; b = UInt64(1) << ((z - 1) & 63)
        for i in 1:P.k
            isodd(count_ones(w & d[i])) && (R[word, i] |= b)
        end
    end
end

@inline function weight2(R, i, j, W)
    s = 0
    @inbounds for x in 1:W
        s += count_ones(R[x, i] ⊻ R[x, j])
    end
    s
end
@inline function weight1(R, i, W)
    s = 0
    @inbounds for x in 1:W
        s += count_ones(R[x, i])
    end
    s
end

# All APN extensions S = U + <t, v> found in `iters` iterations.
function extensions_fast(Ub, flats; iters = 60_000, rng = Xoshiro(1))
    P = ISDProblem(Ub, flats)
    L = length(P.Z); wmax = L ÷ 3
    d = zeros(UInt64, P.k); R = zeros(UInt64, P.W, P.k); perm = collect(1:L)
    found = Set{UInt64}(); sols = Set{Vector{UInt64}}()
    test(x) = begin
        t = x & TMASK
        if (x & ONE) != 0 && !(t in found)
            push!(found, t)
            Zt = [w & TMASK for w in P.Z if isodd(count_ones(w & x))]    # support of 1 + c_t: <w, t> = 0
            for v in solve_ones(Zt)
                S = vcat(Ub, t, v)
                rank_f2(S) == n && is_apn_space(S, flats) && push!(sols, canon(S))
            end
        end
    end
    for _ in 1:iters
        draw_dual!(d, P, perm, rng) || continue
        pack_rows!(R, d, P)
        for i in 1:P.k
            weight1(R, i, P.W) <= wmax && test(d[i])
            for j in i+1:P.k
                weight2(R, i, j, P.W) <= wmax && test(d[i] ⊻ d[j])
            end
        end
    end
    sols, L, length(found)
end

# Prefilter (Lemma 3.12 of Beierle et al., as in the n = 8 search): the
# (10,8)-function of U has delta <= 8 only if no nonzero point lies in more than
# 3 flats of U^perp. A flat x ^ y covers the points x, y, x + y.
function flat_points()
    pts = Dict{UInt64,NTuple{3,Int}}()
    for x in 1:(1 << n)-1, y in x+1:(1 << n)-1
        w = UInt64(0)
        for i in 1:n, j in i+1:n
            (bit(x, i) & bit(y, j)) ⊻ (bit(x, j) & bit(y, i)) == 1 && (w |= UInt64(1) << PAIR[i, j])
        end
        haskey(pts, w) || (pts[w] = (x, y, x ⊻ y))
    end
    pts
end
function passes_delta8(Ub, flats, pts)
    cnt = zeros(Int, 1 << n)
    for w in flats
        orth(w, Ub) || continue
        for a in pts[w]
            (cnt[a+1] += 1) > 3 && return false
        end
    end
    true
end
