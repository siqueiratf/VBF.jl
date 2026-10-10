"""
Hyperplane restrictions and polar-image relations of quadratic APNs.

Counts of admissible radical selections are necessary combinatorial bounds;
they are not claims that every selection has an APN extension. Node-capped
counts explicitly distinguish exact counts from lower bounds.
"""
module QuadraticRestrictions
using ..VBF: QuadraticAPNTree, rank_f2
export hyperplane_basis, restrict_coeffs, rank_hist, annihilators, ker_phi_dim,
       distinct_pi, count_admissible, relation_dims
"Insert `r` into an F_2 echelon basis with distinct leading bits; return true if independent."
function insert_row!(piv::Vector{UInt64}, r0::UInt64)
    r = r0
    for p in piv
        r = min(r, r ⊻ p)
    end
    r == 0 && return false
    push!(piv, r)
    sort!(piv; rev = true)
    true
end

f2rank(rows) = rank_f2(UInt64.(rows))

"Basis of H = ker(u): e_j + u_j e_p for j != p, where p is the lowest set bit of u."
function hyperplane_basis(u::Int, n::Int)
    2 <= n <= 8 && 0 < u < 1<<n || throw(ArgumentError("invalid hyperplane normal or dimension"))
    p = trailing_zeros(u)
    [(1 << j) ⊻ (((u >> j) & 1) << p) for j in 0:n - 1 if j != p]
end

d2(lut, a, b) = UInt16(lut[(a ⊻ b) + 1] ⊻ lut[a + 1] ⊻ lut[b + 1] ⊻ lut[1])

"Pure quadratic coefficients of F restricted to span(basis), in the coordinates of basis."
function restrict_coeffs(lut::AbstractVector, basis::Vector{Int})
    QuadraticAPNTree.coeff_matrix_from_lut(lut) # Validate degree before discarding affine terms.
    n=trailing_zeros(length(lut))
    all(x->0<x<1<<n,basis) && rank_f2(UInt16.(basis);nbits=n)==length(basis) || throw(ArgumentError("expected independent basis inside LUT domain"))
    k = length(basis)
    C = zeros(UInt16, k, k)
    for i in 1:k, j in i + 1:k
        C[i, j] = C[j, i] = d2(lut, basis[i], basis[j])
    end
    C
end

"Component rank histogram of the pure quadratic function C (nv inputs, m outputs): ranks nv..0."
function rank_hist(C::Matrix{UInt16}, nv::Int, m::Int)
    h = zeros(Int, nv + 1)               # h[r+1] = number of b with rank r
    for b in 1:(1 << m) - 1
        rows = UInt64[]
        for i in 1:nv
            r = UInt64(0)
            for j in 1:nv
                isodd(count_ones(UInt16(b) & C[i, j])) && (r |= UInt64(1) << (j - 1))
            end
            push!(rows, r)
        end
        h[f2rank(rows) + 1] += 1
    end
    # report even ranks from the top: (nv_even, nv_even-2, ..., 0)
    top = iseven(nv) ? nv : nv - 1
    Tuple(h[r + 1] for r in top:-2:0)
end

"Nonzero annihilator W_alpha \\ 0 of I_alpha for every alpha (sorted)."
function annihilators(C::Matrix{UInt16}, nv::Int, m::Int)
    I = QuadraticAPNTree.images(C, nv, m)
    I === nothing && return nothing
    W = Vector{Vector{UInt16}}(undef, (1 << nv) - 1)
    for α in 1:(1 << nv) - 1
        bas = [I[α][(1 << t) + 1] for t in 0:nv - 2]      # basis of I_alpha (dim nv-1)
        W[α] = [UInt16(w) for w in 1:(1 << m) - 1 if all(y -> iseven(count_ones(w & y)), bas)]
    end
    W
end

"dim ker Phi = dim { L : w . L(alpha) = 0 for all alpha != 0, w in I_alpha^perp }."
function ker_phi_dim(W, nv::Int, m::Int)
    nv * m <= 64 || error("nv*m > 64")
    piv = UInt64[]
    for α in 1:(1 << nv) - 1, w in W[α]
        row = UInt64(0)
        for i in 1:nv
            (α >> (i - 1)) & 1 == 1 || continue
            for k in 1:m
                (w >> (k - 1)) & 1 == 1 && (row |= UInt64(1) << ((i - 1) * m + k - 1))
            end
        end
        insert_row!(piv, row)
    end
    nv * m - length(piv)
end

"""
Number of distinct restrictions pi|_H over the canonical solutions `sols`
(pi(alpha) = the unique w in W_alpha with w . L(alpha) = 0).
"""
function distinct_pi(W, sols, nv::Int)
    keys = Set{Vector{UInt16}}()
    for L in sols
        key = Vector{UInt16}(undef, (1 << nv) - 1)
        for α in 1:(1 << nv) - 1
            v = UInt16(0)
            for i in 1:nv
                (α >> (i - 1)) & 1 == 1 && (v ⊻= L[i])
            end
            ann = [w for w in W[α] if iseven(count_ones(w & v))]
            length(ann) == 1 || error("solution is not valid at alpha=$α")
            key[α] = ann[1]
        end
        push!(keys, key)
    end
    length(keys)
end

"Radicals: rad[b] = nonzero points alpha of H with b in W_alpha (Rad(G_b) minus 0)."
function radicals(W, nv::Int, m::Int)
    rad = [Int[] for _ in 1:(1 << m) - 1]
    for α in 1:(1 << nv) - 1, b in W[α]
        push!(rad[b], α)
    end
    rad
end

mask_of(pts) = (x = UInt128(0); for p in pts; x |= UInt128(1) << (p - 1); end; x)

"Options of b as point masks: the whole radical, then every hyperplane (minus 0)."
function options(pts::Vector{Int})
    isempty(pts) && return UInt128[]
    basis = Int[]
    piv = UInt64[]
    for p in pts
        insert_row!(piv, UInt64(p)) && push!(basis, p)
    end
    d = length(basis)
    # coordinates: element k of span (k in 1:2^d-1) = xor of basis[i] with bit i-1 of k
    el = zeros(Int, 1 << d)
    for k in 1:(1 << d) - 1
        t = trailing_zeros(k)
        el[k + 1] = el[(k ⊻ (1 << t)) + 1] ⊻ basis[t + 1]
    end
    opts = UInt128[mask_of(pts)]
    for λ in 1:(1 << d) - 1
        push!(opts, mask_of([el[k + 1] for k in 1:(1 << d) - 1 if iseven(count_ones(λ & k))]))
    end
    opts
end

"""
    count_admissible(C, nv, m; cap) -> (count::BigInt, exact::Bool, info)

Number of admissible selections. `exact = false` means the node cap was hit and `count`
is a lower bound.
"""
function count_admissible(C::Matrix{UInt16}, nv::Int, m::Int; cap::Int = 2_000_000)
    1 <= nv <= 7 && 1 <= m <= 8 && nv*m <= 64 || throw(ArgumentError("unsupported dimensions"))
    W = annihilators(C, nv, m)
    W === nothing && throw(ArgumentError("expected quadratic APN coefficients"))
    rad = radicals(W, nv, m)
    npts = (1 << nv) - 1
    big_b = [b for b in eachindex(rad) if length(rad[b]) >= 3]       # dim >= 2
    c1 = zeros(Int, npts)                                            # dim-1 radicals per point
    for b in eachindex(rad)
        length(rad[b]) == 1 && (c1[rad[b][1]] += 1)
    end
    opts = [filter(!iszero, options(rad[b])) for b in big_b]
    # order: fewest options first
    perm = sortperm(length.(opts))
    opts = opts[perm]
    full = (UInt128(1) << npts) - 1
    cap >= 0 || throw(ArgumentError("negative node cap"))
    nodes = Ref(0)
    hit = Ref(false)
    function leafval(covered)
        v = big(1)
        rest = full & ~covered
        while rest != 0
            p = trailing_zeros(rest) + 1
            rest &= rest - 1
            c1[p] == 0 && return big(0)
            v *= c1[p]
        end
        v
    end
    function rec(i, covered)
        nodes[] += 1
        if nodes[] > cap
            hit[] = true
            return big(0)
        end
        i > length(opts) && return leafval(covered)
        tot = big(0)
        for o in opts[i]
            o & covered == 0 || continue
            tot += rec(i + 1, covered | o)
            hit[] && return tot
        end
        tot
    end
    cnt = rec(1, UInt128(0))
    hist = Dict{Int,Int}()
    for b in eachindex(rad)
        d = round(Int, log2(length(rad[b]) + 1))
        hist[d] = get(hist, d, 0) + 1
    end
    (cnt, !hit[], (big = length(big_b), rad_dims = sort(collect(hist)), nodes = nodes[]))
end

"GF(2) rank of BitVector rows."
function bv_rank(rows::Vector{BitVector})
    piv = Dict{Int,BitVector}()
    r = 0
    for v0 in rows
        v = copy(v0)
        while true
            l = findlast(v)
            l === nothing && break
            if haskey(piv, l)
                v .⊻= piv[l]
            else
                piv[l] = v
                r += 1
                break
            end
        end
    end
    r
end

"(|P|, dim ker eps, dim K_loc) for G."
function relation_dims(C::Matrix{UInt16}, nv::Int, m::Int)
    1 <= nv <= 7 && 1 <= m <= 8 && nv*m <= 64 || throw(ArgumentError("unsupported dimensions"))
    W = annihilators(C, nv, m)
    W === nothing && throw(ArgumentError("expected quadratic APN coefficients"))
    rad = radicals(W, nv, m)
    P = Tuple{Int,Int}[]
    for b in eachindex(rad), α in rad[b]
        push!(P, (α, b))
    end
    idx = Dict(p => i for (i, p) in enumerate(P))
    # rank of eps
    piv = UInt64[]
    for (α, b) in P
        row = UInt64(0)
        for i in 1:nv
            (α >> (i - 1)) & 1 == 1 || continue
            for k in 1:m
                (b >> (k - 1)) & 1 == 1 && (row |= UInt64(1) << ((i - 1) * m + k - 1))
            end
        end
        insert_row!(piv, row)
    end
    reps = length(piv)
    rels = BitVector[]
    for α in 1:(1 << nv) - 1                       # row relations
        v = falses(length(P))
        for b in W[α]
            v[idx[(α, b)]] = true
        end
        push!(rels, v)
    end
    for b in eachindex(rad)                         # line relations inside Rad_b
        s = Set(rad[b])
        for a1 in rad[b], a2 in rad[b]
            a1 < a2 && (a1 ⊻ a2) in s && a2 < (a1 ⊻ a2) || continue
            v = falses(length(P))
            v[idx[(a1, b)]] = v[idx[(a2, b)]] = v[idx[(a1 ⊻ a2, b)]] = true
            push!(rels, v)
        end
    end
    (length(P), length(P) - reps, bv_rank(rels))
end

end
