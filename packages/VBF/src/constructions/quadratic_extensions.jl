# Implements the Fourier extension (n, n-2) -> (n, n) of quadratic functions
# Beierle et al. (2025), Fourier extension of quadratic component spaces
#
# Math:
#   V = Alt(n) = F_2^N, N = n(n-1)/2, with the basis x_i x_j (1 <= i < j <= n, i outer,
#   j inner; bit k of a UInt32 is the k-th pair). A quadratic form is a vector of V (its
#   alternating matrix). The coordinate dot product pairs V with itself.
#   Flats: the decomposable bivectors x^y, entries x_i y_j + x_j y_i. There are
#   [n choose 2]_2 of them (651 for n = 6, 10,795 for n = 8). For a form s,
#   s . (x^y) = s(x, y).
#   Lemma (Beierle et al. 2025, Lemma 3.14 / Remark 3.15): a quadratic (n, n)-function
#   with component space S is APN iff S^perp contains no flat.
#   Let U be a d-dim subspace (d = n-2), W = U^perp (dim D = N-d). Put U in reduced row
#   echelon form with pivot set P and let Q be the other N-d bit positions. A coset
#   t + U has a unique representative with zero bits on P; its Q-bits tau(t) are
#   coordinates on V/U = F_2^D. For w in W, w . t = w|_Q . tau(t), and w -> w|_Q is
#   injective on W. Thus
#       g(tau) = sum_{flats w in W} (-1)^{w|_Q . tau}
#   is the D-bit Walsh-Hadamard transform of the indicator of {w|_Q : w flat in W}.
#   Poisson: sigma_U(t) = sum_{u in U} fhat(t+u) = 2^d g(tau(t)).
#   S = U + lift(T), T = {0, u, v, u+v} 2-dim in V/U, is APN iff no flat w in W
#   vanishes on T, iff g(0)+g(u)+g(v)+g(u+v) = 0.
#   Z(u) = {flat w in W : w . u = 0}; |Z(u)| = (g(0)+g(u))/2. For a valid T the sets
#   Z(u), Z(v), Z(u+v) partition the flats of W, so the smallest has at most g(0)/3
#   elements: g(u) <= -g(0)/3 (Remark 3.16). For a candidate u, the valid v are the
#   solutions of the linear system {w . v = 1 : w in Z(u)}: an affine subspace that we
#   solve exactly. This replaces the second pruning inequality of Remark 3.16.
#   Lemma 4.6 (v1) prefilter: the (n, n-2)-function U has an APN extension only if its
#   differential uniformity is <= 8, i.e. no nonzero a lies in more than 3 flats of W.
#
# Pseudocode (extensions(U)):
#   R, P = rref(U); Q = complement of P
#   C = [w|_Q for w in flats if w . u = 0 for all u in R]
#   if some point a lies in > 3 flats of C: return no extension (Lemma 4.6)
#   g = FWHT(indicator of C) on 2^D Int16 entries
#   for u with 3 g(u) <= -g(0):
#       solve {c . v = 1 : c in C, c . u = 0}; for each solution v: add T = {u, v, u+v}
#   return the distinct T (each checked: g(0)+g(u)+g(v)+g(u+v) = 0)
#
# Also: coefficient strings, component forms, ranks, subspaces of Comp(F) with a given
# number of bent elements, the bent counts of all cosets x + V of a subspace V (Fourier),
# the U-class key, and a brute-force reference for small n.
# VBF APIs supply representations, GF(2) elimination and Walsh transforms;
# histogram fingerprints use the SHA standard library.

"""
    QuadraticExtensions

Fourier extensions of quadratic component spaces. Forms use square-free Boolean
ANF coordinates and decomposable bivectors test the APN condition. See the
file's derivation and small-dimension brute-force verifier. Experiment storage,
reference comparisons and independent validation belong to the consuming
`VBFSearch` application.

Coefficient conversion helpers encode the square-free quadratic part only;
they do not preserve affine terms of an arbitrary quadratic function. Packed
form ranks use the alternating-matrix representation specific to this module.

Histogram keys are necessary filters only; matching keys do not establish
EA/CCZ equivalence and must not justify skipping an exhaustive search.
"""
module QuadraticExtensions

export Geometry, geometry, form_rank, form_rank_slow, coeffs_from_hex, hex_from_coeffs,
       coord_forms, forms_to_coeffs, lut_from_coeffs, comp_forms, rref, span_dim,
       extensions, extensions_bruteforce, ExtWork, s_key, lift, fwht!, each_rref,
       subspaces_of_comp, best_hyperplane_bent, bent_fourier, flat_fourier, BETA8,
       coset_bent_counts!, bent_mask, gauss_binom, V5Work, v5_extensions, function_of, max_bent_dim,
       PolarRankTable, PackedPolarRankTable

using ..VBF: SBox, linear_basis, rank_f2, gauss_jordan!, rref_from_echelon!, walsh_hadamard!
using SHA

"Fingerprint a histogram; equality is not an equivalence certificate."
function hist_key(h::AbstractDict)
    io = IOBuffer()
    for (v, c) in sort!(collect(h)); print(io, v, ':', c, ','); end
    d = sha256(take!(io))
    (reinterpret(UInt64, d[1:8])[1], reinterpret(UInt64, d[9:16])[1])
end

# --- geometry ---------------------------------------------------------------------

struct Geometry
    n::Int
    N::Int
    pair::Matrix{Int}               # pair[i, j] = bit index of x_i x_j (0-based)
    pairs::Vector{Tuple{Int,Int}}
    flats::Vector{UInt32}           # decomposable bivectors x^y (sorted)
    flatpts::Vector{NTuple{3,Int}}  # the 3 nonzero points of the 2-dim subspace of a flat
    rt::Matrix{UInt64}              # rank tables: 7-bit chunk -> rows packed as bytes
end

@inline bit(x, i) = (x >> (i - 1)) & 1
@inline par(x) = isodd(count_ones(x))

function wedge(pair, n, x, y)
    v = UInt32(0)
    for i in 1:n, j in i+1:n
        (bit(x, i) & bit(y, j)) ⊻ (bit(x, j) & bit(y, i)) == 1 && (v |= UInt32(1) << pair[i, j])
    end
    v
end

"Gaussian binomial coefficient [n choose k]_2."
gauss_binom(n, k) = prod(big(2)^(n - i) - 1 for i in 0:k-1; init = big(1)) ÷
                    prod(big(2)^(k - i) - 1 for i in 0:k-1; init = big(1))

"Geometry of Alt(n) (n <= 8): pair indices, flats and rank tables."
function geometry(n::Int)
    2 <= n <= 8 || throw(ArgumentError("dimension must be between 2 and 8"))
    N = n * (n - 1) ÷ 2
    pair = zeros(Int, n, n); pairs = Tuple{Int,Int}[]; k = 0
    for i in 1:n, j in i+1:n
        pair[i, j] = k; pair[j, i] = k; push!(pairs, (i, j)); k += 1
    end
    pts = Dict{UInt32,NTuple{3,Int}}()
    for x in 1:(1 << n)-1, y in x+1:(1 << n)-1
        y < (x ⊻ y) || continue                  # one basis per 2-dim subspace
        pts[wedge(pair, n, x, y)] = (x, y, x ⊻ y)
    end
    flats = sort!(collect(keys(pts)))
    length(flats) == gauss_binom(n, 2) || error("flat count")
    rt = zeros(UInt64, 4, 128)
    for c in 0:3, x in 0:127, b in 0:6
        k = 7c + b
        (k < N && (x >> b) & 1 == 1) || continue
        i, j = pairs[k+1]
        rt[c+1, x+1] |= (UInt64(1) << (8(i - 1) + j - 1)) | (UInt64(1) << (8(j - 1) + i - 1))
    end
    Geometry(n, N, pair, pairs, flats, [pts[f] for f in flats], rt)
end

#   Rank of the alternating matrix of a form. The rows of the n x n matrix are the bytes
#   of a UInt64 (n <= 8). One elimination step takes the first nonzero row p and its
#   lowest bit lb and XORs p into every row with bit lb (the pivot row becomes 0). Each
#   step removes one row, so the number of steps is the rank.
"Rank of the alternating matrix of the form w (fast, n <= 8)."
@inline function form_rank(G::Geometry, w::UInt32)
    rt = G.rt
    @inbounds M = rt[1, (w & 0x7f)+1] ⊻ rt[2, ((w >> 7) & 0x7f)+1] ⊻
                  rt[3, ((w >> 14) & 0x7f)+1] ⊻ rt[4, ((w >> 21) & 0x7f)+1]
    rk = 0
    while M != 0
        i = trailing_zeros(M) & ~7
        p = (M >> i) & 0xff
        lb = p & (~p + 1)
        sel = ((M & (lb * 0x0101010101010101)) >> trailing_zeros(lb)) * 0xff
        M ⊻= sel & (p * 0x0101010101010101)
        rk += 1
    end
    rk
end

"Reference rank (row elimination on an explicit matrix)."
function form_rank_slow(G::Geometry, v::UInt32)
    r = zeros(UInt16, G.n)
    for (k, (i, j)) in enumerate(G.pairs)
        if (v >> (k - 1)) & 1 == 1
            r[i] |= UInt16(1) << (j - 1); r[j] |= UInt16(1) << (i - 1)
        end
    end
    rk = 0
    for i in 1:G.n
        p = r[i]; p == 0 && continue
        rk += 1; lb = p & (~p + one(UInt16))
        for j in i+1:G.n
            (r[j] & lb) != 0 && (r[j] ⊻= p)
        end
    end
    rk
end

include("quadratic_rank_table.jl")

# --- coefficients, forms, LUT -------------------------------------------------------

"c_ij (i<j, pair order) from hex, two hex digits per coefficient."
coeffs_from_hex(s::AbstractString) = [parse(UInt16, s[2k-1:2k], base = 16) for k in 1:length(s)÷2]
hex_from_coeffs(c) = join(string(x, base = 16, pad = 2) for x in c)

"Coordinate forms f_l (l = 1..m): bit k of f_l = bit l of c_k."
coord_forms(c::Vector{UInt16}, m::Int) =
    [reduce(|, (UInt32((c[k] >> (l - 1)) & 1) << (k - 1) for k in eachindex(c)); init = UInt32(0))
     for l in 1:m]

"Component forms: comp[b+1] = form of b.F for b = 0..2^m-1."
function comp_forms(f::Vector{UInt32})
    m = length(f); comp = zeros(UInt32, 1 << m)
    for b in 1:(1 << m)-1
        comp[b+1] = comp[(b & (b - 1))+1] ⊻ f[trailing_zeros(b)+1]
    end
    comp
end

"bent[b+1] = (rank of b.F == n)."
bent_mask(G::Geometry, comp::Vector{UInt32}) =
    BitVector([b > 0 && form_rank(G, comp[b+1]) == G.n for b in 0:length(comp)-1])

"Coefficients c_k (bit l = bit k of s_l) from a basis s_1..s_m of the component space."
function forms_to_coeffs(s::AbstractVector{UInt32}, N::Int)
    c = zeros(UInt16, N)
    for (l, v) in enumerate(s), k in 1:N
        (v >> (k - 1)) & 1 == 1 && (c[k] |= UInt16(1) << (l - 1))
    end
    c
end

"LUT of x -> XOR_{i<j} x_i x_j c_ij (x_1 = least significant bit)."
function lut_from_coeffs(G::Geometry, c::Vector{UInt16})
    n = G.n; lut = zeros(UInt16, 1 << n)
    for x in 1:(1 << n)-1                       # Gray-free incremental: F(x) from F(x - lowbit)
        lb = trailing_zeros(x) + 1; xr = x & (x - 1)
        y = lut[xr+1]
        for j in 1:n                            # add c_{lb,j} for the bits j of xr
            bit(xr, j) == 1 && (y ⊻= c[G.pair[lb, j]+1])
        end
        lut[x+1] = y
    end
    lut
end

# --- F_2 linear algebra on UInt32 vectors ---------------------------------------------

"""
    rref(vs::AbstractVector{UInt32}) -> (rows, pivots)

Canonical reduced basis with highest-bit pivots in decreasing order. Reversing
bits adapts VBF's lowest-bit-first elimination without changing the quotient
coordinates used by `lift` and the extension enumeration.
"""
function rref(vs::AbstractVector{UInt32})
    rows = bitreverse.(linear_basis(bitreverse.(vs)))
    rows, [31 - leading_zeros(r) for r in rows]
end
span_dim(vs::AbstractVector{UInt32}) = rank_f2(vs)

"Canonical key of a subspace: its RREF rows (pivots decreasing)."
s_key(vs) = rref(vs)[1]

@inline function pext(w::UInt32, mask::UInt32)
    r = UInt32(0); k = 0; m = mask
    while m != 0
        b = trailing_zeros(m)
        r |= ((w >> b) & UInt32(1)) << k
        k += 1; m &= m - UInt32(1)
    end
    r
end
@inline function pdep(t::UInt32, mask::UInt32)
    r = UInt32(0); k = 0; m = mask
    while m != 0
        b = trailing_zeros(m)
        r |= ((t >> k) & UInt32(1)) << b
        k += 1; m &= m - UInt32(1)
    end
    r
end

"Lift tau in V/U coordinates to the representative t in V (zero on the pivots)."
lift(tau::UInt32, Qmask::UInt32) = pdep(tau, Qmask)

function pivots_masks(R, piv, N)
    Pmask = reduce(|, (UInt32(1) << p for p in piv); init = UInt32(0))
    Pmask, ((UInt32(1) << N) - UInt32(1)) & ~Pmask
end

# --- Walsh-Hadamard transform -----------------------------------------------------------

"In-place unnormalized Walsh transform; delegates to VBF's checked signed-vector kernel."
fwht!(a::Vector{<:Signed}) = walsh_hadamard!(a)

# --- the extension step ---------------------------------------------------------------

"Reusable work buffers for one task."
mutable struct ExtWork
    buf::Vector{Int16}       # 2^D, the transform g
    cnt::Vector{Int}         # per point a of F_2^n: flats of W through a
    hist::Vector{Int}        # histogram of g (for the U-class key)
end
ExtWork(D::Int, n::Int = 8) = ExtWork(zeros(Int16, 1 << D), zeros(Int, 1 << n), Int[])

"""
    extensions(G, Ub, work; du_filter=true, key=false, max_kernel=12, max_T=10^6)

All 2-dim T in V/U such that U + lift(T) is APN (no flat in its orthogonal). `Ub` spans
U. Returns `(; R, Qmask, D, nW, ncand, Ts, du_reject, degenerate, capped, key)`. `Ts`
holds (u, v) in V/U coordinates with u < v < u xor v. `key` is the U-class key (the
histogram of g) when `key = true`, else `nothing`.
"""
function extensions(G::Geometry, Ub::AbstractVector{UInt32}, work::ExtWork;
                    du_filter::Bool = true, key::Bool = false,
                    max_kernel::Int = 12, max_T::Int = 10^6)
    R, piv = rref(Ub)
    D = G.N - length(R)
    _, Qmask = pivots_masks(R, piv, G.N)
    C = UInt32[]; Cidx = Int[]
    @inbounds for (fi, w) in enumerate(G.flats)
        ok = true
        for r in R
            par(w & r) && (ok = false; break)
        end
        ok && (push!(C, pext(w, Qmask)); push!(Cidx, fi))
    end
    nW = length(C)
    empty_T = Tuple{UInt32,UInt32}[]
    if du_filter                                # Lemma 4.6: DU(U) <= 8
        cnt = work.cnt; fill!(cnt, 0)
        bad = false
        @inbounds for fi in Cidx, p in G.flatpts[fi]
            cnt[p+1] += 1
            cnt[p+1] > 3 && (bad = true)
        end
        bad && return (; R, Qmask, D, nW, ncand = 0, Ts = empty_T, du_reject = true,
                         degenerate = false, capped = false, key = nothing)
    end
    a = work.buf
    length(a) == (1 << D) || (a = work.buf = zeros(Int16, 1 << D))
    fill!(a, Int16(0))
    @inbounds for c in C
        a[c+1] = Int16(1)
    end
    fwht!(a)
    g0 = Int(a[1])
    cand = UInt32[]
    if key
        h = work.hist; resize!(h, 2nW + 1); fill!(h, 0)
        @inbounds for t in 1:length(a)
            x = Int(a[t]); h[x+nW+1] += 1
            t > 1 && 3x <= -g0 && push!(cand, UInt32(t - 1))
        end
        ukey = hist_key(Dict(i - nW - 1 => h[i] for i in eachindex(h) if h[i] > 0))
    else
        @inbounds for t in 2:length(a)
            3 * Int(a[t]) <= -g0 && push!(cand, UInt32(t - 1))
        end
        ukey = nothing
    end
    Tset = Set{Tuple{UInt32,UInt32}}()
    degenerate = false; capped = false
    Z = UInt32[]
    for u in cand
        empty!(Z)
        for c in C
            par(c & u) || push!(Z, c)
        end
        if isempty(Z)                      # U + <u> already has no flat in its perp
            degenerate = true; continue
        end
        sol = solve_ones(Z, D)
        sol === nothing && continue
        v0, K = sol
        if length(K) > max_kernel
            capped = true; continue
        end
        for m in 0:(1 << length(K))-1
            v = v0
            for (i, k) in enumerate(K)
                (m >> (i - 1)) & 1 == 1 && (v ⊻= k)
            end
            x, y, _ = sort3(u, v, u ⊻ v)
            push!(Tset, (x, y))
        end
        length(Tset) > max_T && (capped = true; break)
    end
    Ts = sort!(collect(Tset))
    @inbounds for (u, v) in Ts                  # self-check of the Fourier criterion
        g0 + a[u+1] + a[v+1] + a[(u⊻v)+1] == 0 || error("Fourier criterion violated")
    end
    (; R, Qmask, D, nW, ncand = length(cand), Ts, du_reject = false, degenerate, capped,
       key = ukey)
end

@inline function sort3(a, b, c)
    a > b && ((a, b) = (b, a)); b > c && ((b, c) = (c, b)); a > b && ((a, b) = (b, a))
    a, b, c
end

"""
Solve {c . v = 1 : c in Z} over F_2^D, with `0 <= D <= 31`. Returns
(particular solution with free variables zero, kernel basis in increasing free-bit
order), or nothing when inconsistent. Scratch buffers are overwritten.

Reduce constraints incrementally, rejecting a contradictory row immediately,
then use VBF's elimination on at most `D` independent augmented rows. Unlike
`solve_f2`, the number of constraints is not bounded by the RHS scalar width.
"""
function solve_ones(Z::Vector{UInt32}, D::Int, rows::Vector{UInt32} = UInt32[],
                    piv::Vector{Int} = Int[], K::Vector{UInt32} = UInt32[])
    0 <= D <= 31 || throw(ArgumentError("affine dimension must be between 0 and 31"))
    aug = UInt32(1) << D                      # right-hand side bit
    all(c -> c < aug, Z) || throw(ArgumentError("constraint exceeds the affine dimension"))
    empty!(rows); empty!(piv); empty!(K)
    # At dimension zero every present equation is 0 = 1.
    D == 0 && return isempty(Z) ? (UInt32(0), K) : nothing
    resize!(rows,D)
    fill!(rows,UInt32(0))
    mask=aug-UInt32(1)
    @inbounds for c in Z
        _solve_ones_insert!(rows,c,aug,mask) || return nothing
    end
    _solve_ones_finish!(rows,piv,K,D)
end

"""Insert an augmented equation, returning false on an exact contradiction."""
@inline function _solve_ones_insert!(rows,c,aug,mask)
    row=c|aug
    @inbounds while !iszero(row&mask)
        p=trailing_zeros(row&mask)+1
        basis=rows[p]
        if iszero(basis)
            rows[p]=row
            return true
        end
        row⊻=basis
    end
    row!=aug
end

"""Recover the canonical particular solution and free-bit-ordered kernel."""
function _solve_ones_finish!(rows,piv,K,D)
    filter!(!iszero,rows)
    rank = rref_from_echelon!(rows)
    resize!(rows, rank)
    append!(piv, (trailing_zeros(r) for r in rows))
    v0 = UInt32(0)                             # free variables 0
    for (r, p) in zip(rows, piv)
        (r >> D) & 1 == 1 && (v0 |= UInt32(1) << p)
    end
    pivset = UInt32(0)
    for p in piv; pivset |= UInt32(1) << p; end
    for f in 0:D-1
        (pivset >> f) & 1 == 1 && continue
        k = UInt32(1) << f
        for (r, p) in zip(rows, piv)
            (r >> f) & 1 == 1 && (k |= UInt32(1) << p)
        end
        push!(K, k)
    end
    v0, K
end

"""Solve nonempty c⋅v=1 constraints with c⋅t=0 from an internal quotient list.

The quotient coordinates are already valid. Selection and elimination share
one scan, so an inconsistent prefix avoids gathering the remaining constraints.
Empty selected systems retain the V5 algorithm's degenerate-system rejection.
"""
function _solve_ones_annihilating(C,t,D,rows,piv,K)
    0<=D<=31 || throw(ArgumentError("affine dimension must be between 0 and 31"))
    aug=UInt32(1)<<D;mask=aug-UInt32(1)
    empty!(piv);empty!(K);resize!(rows,D);fill!(rows,UInt32(0));found=false
    @inbounds for c in C
        par(c&t) && continue
        found=true
        _solve_ones_insert!(rows,c,aug,mask) || return nothing
    end
    found || return nothing
    _solve_ones_finish!(rows,piv,K,D)
end

"""
Reference: all 2-dim T in V/U (u < v < u xor v) such that no flat of U^perp vanishes
on T, by direct enumeration of all pairs. Only for small D (n = 6: D = 11).
"""
function extensions_bruteforce(G::Geometry, Ub::AbstractVector{UInt32})
    R, piv = rref(Ub)
    D = G.N - length(R)
    _, Qmask = pivots_masks(R, piv, G.N)
    C = [pext(w, Qmask) for w in G.flats if all(r -> !par(w & r), R)]
    out = Tuple{UInt32,UInt32}[]
    for u in UInt32(1):UInt32((1 << D) - 1), v in u+UInt32(1):UInt32((1 << D) - 1)
        v < (u ⊻ v) || continue
        ok = true
        for c in C
            (!par(c & u) && !par(c & v)) && (ok = false; break)
        end
        ok && push!(out, (u, v))
    end
    out
end

# --- subspaces of the component space -----------------------------------------------------

"All r x m reduced row echelon matrices over F_2 (rows as UInt32, pivot = highest bit)."
function each_rref(m::Int, r::Int)
    out = Vector{Vector{UInt32}}()
    function rec(pivs::Vector{Int})
        if length(pivs) == r
            pivmask = reduce(|, (1 << p for p in pivs); init = 0)
            free = [[q for q in 0:pivs[k]-1 if (pivmask >> q) & 1 == 0] for k in 1:r]
            nf = sum(length, free; init = 0)
            for x in 0:(1 << nf)-1
                rs = [UInt32(1) << p for p in pivs]; t = 0
                for k in 1:r, q in free[k]
                    (x >> t) & 1 == 1 && (rs[k] |= UInt32(1) << q); t += 1
                end
                push!(out, rs)
            end
            return
        end
        lo = isempty(pivs) ? m : pivs[end]
        for p in lo-1:-1:0                   # strictly decreasing pivots
            rec(vcat(pivs, p))
        end
    end
    rec(Int[])
    out
end

"""
    subspaces_of_comp(comp, bent, k; keep) -> Vector{NamedTuple}

All k-dim subspaces of the b-space F_2^m (kernels of the (m-k)-dim dual subspaces) whose
bent count satisfies `keep(nbent)`. Each entry has `els` (nonzero b), `bbasis` (RREF
basis in b-space), `forms` (forms of `bbasis`) and `nbent`.
"""
function subspaces_of_comp(comp::Vector{UInt32}, bent::BitVector, k::Int; keep::Function)
    m = trailing_zeros(length(comp))
    out = NamedTuple[]
    for A in each_rref(m, m - k)
        els = Int[]; nb = 0
        for b in 1:(1 << m)-1
            any(a -> par(a & UInt32(b)), A) && continue
            push!(els, b); bent[b+1] && (nb += 1)
        end
        keep(nb) || continue
        bb = rref(UInt32.(els))[1]
        push!(out, (; els, bbasis = bb, forms = [comp[Int(b)+1] for b in bb], nbent = nb))
    end
    out
end

"(best bent count, number of hyperplanes reaching it) over the hyperplanes of a subspace."
function best_hyperplane_bent(els::Vector{Int}, bb::Vector{UInt32}, bent::BitVector)
    R, piv = rref(bb)
    coords = map(els) do b                    # coordinates = bits at the RREF pivots
        x = 0
        for (i, p) in enumerate(piv); ((b >> p) & 1 == 1) && (x |= 1 << (i - 1)); end
        x
    end
    best = 0; nbest = 0
    for h in 1:(1 << length(R))-1
        c = 0
        for (b, x) in zip(els, coords)
            par(UInt32(x & h)) && continue
            bent[b+1] && (c += 1)
        end
        c > best ? (best = c; nbest = 1) : (c == best && (nbest += 1))
    end
    best, nbest
end

# --- Fourier values that depend only on the rank -------------------------------------------

rank_rep(G::Geometry, r::Int) =
    reduce(⊻, (UInt32(1) << G.pair[2k-1, 2k] for k in 1:r÷2); init = UInt32(0))

"phi(r) = fhat(s) = sum_{flats w} (-1)^{s . w} for a form s of rank r = 0, 2, ..., n."
flat_fourier(G::Geometry) =
    [sum(w -> par(w & rank_rep(G, r)) ? -1 : 1, G.flats) for r in 0:2:G.n]

"""
beta(r) = Bhat(w) = sum_s B(s) (-1)^{s . w} (B = bent indicator) for w of rank
r = 0, 2, ..., n. Sweeps all 2^N forms (n = 8: about 5 s with 2 threads).
"""
function bent_fourier(G::Geometry)
    reps = [rank_rep(G, r) for r in 0:2:G.n]
    nr = length(reps); total = 1 << G.N
    nch = min(total, 512); step = total ÷ nch
    parts = [zeros(Int, nr) for _ in 1:nch]
    Threads.@threads for ci in 1:nch
        acc = parts[ci]
        for s in UInt32((ci - 1) * step):UInt32(ci * step - 1)
            form_rank(G, s) == G.n || continue
            for k in 1:nr
                acc[k] += par(s & reps[k]) ? -1 : 1
            end
        end
    end
    sum(parts)
end

"Fourier coefficients of the bent indicator at n = 8; recompute with `bent_fourier(geometry(8))`."
const BETA8 = [112881664, -888832, 28672, -4096, 4096]

# --- bent counts of all cosets x + V (Fourier) ---------------------------------------------
#
#   For a d-dim V (RREF rows R, pivots P, D = N - d) and the bent indicator B:
#       #bent(x + V) = 2^-D sum_{y in V^perp} Bhat(y) (-1)^{y . x},
#   and Bhat(y) = beta(rank y) depends only on the rank (GL(n) acts transitively on the
#   forms of a given rank and preserves the pairing). V^perp is parametrized by its Q-bits
#   c: y(c) = pdep(c, Q) + sum_{k: r_k has bit q} e_{p_k}. A Gray-code walk fills
#   buf[c+1] = beta(rank y(c)) / gcd(beta); one D-bit FWHT gives 2^D/gcd * #bent(x + V)
#   for all cosets at once. For n = 8 the sum of |beta/gcd| is below 2^31 (Int32 is safe).

"""
    coset_bent_counts!(buf, G, V, beta) -> (; R, Qmask, D, scale)

After the call, buf[tau+1] = scale * (number of bent forms in lift(tau) + V) for all
tau in F_2^D, with scale = 2^D / gcd(beta).
"""
function coset_bent_counts!(buf::Vector{Int32}, G::Geometry, V::AbstractVector{UInt32},
                            beta::Vector{Int}; rank_table::Union{Nothing,_PolarRankLookup}=nothing)
    rank_table===nothing || rank_table.n==G.n ||
        throw(ArgumentError("polar rank table has the wrong input dimension"))
    R, piv = rref(V)
    D = G.N - length(R)
    _, Qmask = pivots_masks(R, piv, G.N)
    gb = gcd(beta); betap = beta .÷ gb
    scale = (1 << D) ÷ gb
    length(buf) == (1 << D) || resize!(buf, 1 << D)
    yb = UInt32[]
    m = Qmask
    while m != 0
        q = trailing_zeros(m); m &= m - UInt32(1)
        y = UInt32(1) << q
        for (r, p) in zip(R, piv)
            (r >> q) & 1 == 1 && (y |= UInt32(1) << p)
        end
        push!(yb, y)
    end
    y = UInt32(0); c = 0
    @inbounds buf[1] = Int32(betap[1])
    @inbounds for i in 1:(1 << D)-1
        # Large quotients run millions of allocation-free iterations. Let other
        # search tasks collect without waiting for the complete rank table.
        (i & 4095) == 0 && GC.safepoint()
        j = trailing_zeros(i)
        y ⊻= yb[j+1]; c ⊻= 1 << j
        rk=rank_table===nothing ? form_rank(G,y) : _polar_rank(rank_table,y)
        buf[c+1] = Int32(betap[(rk >> 1)+1])
    end
    fwht!(buf)
    (; R, Qmask, D, scale)
end

# --- extensions through a 5-dim (generally (n-3)-dim) subspace ------------------------------
#
#   Fix V5 (dim d5 = n-3, D5 = N - d5) and its flats C5 = {w|_Q5 : w flat in V5^perp}.
#   g5 = FWHT of the indicator of C5 (one D5-bit transform per V5). For U = V5 + <x>:
#   the flats of U^perp are the w in C5 with w . x = 0, and for t in V/V5
#       g_U(t mod x) = (g5(t) + g5(t + x)) / 2,    nW(U) = g_U(0) = (g5(0) + g5(x)) / 2.
#   A candidate u = t mod x needs 3 g_U(t) <= -nW(U), so min(g5(t), g5(t+x)) <= -nW(U)/3.
#   One sorted list of the t with small g5 serves every x: per x we walk its prefix
#   instead of a 2^22-point transform. The valid v solve {c . v = 1 : c in C5, c . x = 0,
#   c . t = 0} in F_2^D5; x is in the kernel, so v is taken modulo x.
#   The x come from the coset bent counts: #bent(x + V5) = target.

"Work buffers for `v5_extensions` (2^D5 Int32 counts, 2^D5 Int16 transform)."
mutable struct V5Work
    cnt::Vector{Int32}
    g5::Vector{Int16}
    pts::Vector{Int}
end
V5Work(D5::Int, n::Int = 8) = V5Work(zeros(Int32, 1 << D5), zeros(Int16, 1 << D5), zeros(Int, 1 << n))

include("quadratic_extension_du7.jl")
include("quadratic_extension_histograms.jl")

"""
    v5_extensions(G, V5, need, work; beta, du_filter=true, max_kernel=12, max_x=typemax(Int))

All APN S = V5 + <x, t, v> such that U = V5 + <x> has `need` bent elements in the coset
x + V5 (so b(U) = b(V5) + need). Returns `(; Ss, nX, nX_used, du_reject, ncand, nT,
key, capped)`: `Ss` the set of S (RREF keys), `key` a V5-class key (histograms of the
coset bent counts and of g5).

Optional `coset_observer(event)` runs after each complete eligible coset, including
a differential-uniformity rejection. Its event contains `index`, `next_x`,
`total_x`, the lifted `representative`, per-coset `Ss`, `du_reject`, `ncand`, `nT`
and `capped`. Each per-coset set is independent: the same output space in two
cosets appears in both events, while the returned aggregate `Ss` remains unique.
An interrupted or unstarted coset produces no event. A capped event explicitly
does not establish exhaustive coverage of its completions.

The opt-in `selected_coset_indices` vector executes only those original
eligible-coset indices. It cannot be combined with a cursor or `max_x` limit.
Selected results have `selected_scope=true`, `selected_coset_indices`, and
`next_x=nothing`: enumerating this subset alone never certifies all cosets.
Observers retain original logical indices. See `VBF.v5_extensions_by_symmetry`
for verified orbit planning and reconstruction of the omitted outputs.

`du7_filter=:bitsets` (or `:auto`) applies a necessary differential-uniformity
test to each intermediate seven-space before reading partner Walsh values.
`:triangles` uses verified odd three-flat contradictions instead. Both preserve
completion sets, caps and coset cursors. Bitset mode counts surviving candidates
in `ncand`; triangle mode retains the original candidate count. The default
`:none` retains the original work counters. Pruning is
disabled when `du_filter=false`. `rank_table` optionally shares a precomputed
[`PolarRankTable`](@ref) or [`PackedPolarRankTable`](@ref) during Fourier bent-count preparation.
"""
function v5_extensions(G::Geometry, V5::AbstractVector{UInt32}, need::Int, work::V5Work;
                       beta::Vector{Int}, du_filter::Bool = true, max_kernel::Int = 12,
                       max_x::Int = typemax(Int), should_skip::Function = k -> false,
                       start_x::Int = 1, should_stop::Function = () -> false,
                       coset_observer = nothing, selected_coset_indices = nothing,
                       du7_filter::Symbol=:none, rank_table::Union{Nothing,_PolarRankLookup}=nothing)
    max_x >= 0 && start_x >= 1 || error("invalid coset cursor or chunk size")
    du7_filter in (:none,:auto,:bitsets,:triangles) || throw(ArgumentError("unknown DU7 filter"))
    use_du7=du_filter && du7_filter!==:none
    selected_scope = selected_coset_indices !== nothing
    selected_scope && (start_x != 1 || max_x != typemax(Int)) &&
        throw(ArgumentError("selected cosets cannot be combined with cursor or max_x"))
    r = coset_bent_counts!(work.cnt, G, V5, beta;rank_table)
    R, Qmask, D = r.R, r.Qmask, r.D
    cnt = work.cnt
    hc,X = _v5_bent_histogram(cnt,r.scale,need,length(R))
    nX = length(X)
    start_x <= nX+1 || error("coset cursor exceeds extension space")
    stop_x = max_x > nX ? nX : min(nX,start_x+max_x-1)
    indices = if selected_scope
        selected_coset_indices isa AbstractVector{<:Integer} ||
            throw(ArgumentError("selected coset indices must be an integer vector"))
        all(i -> 1 <= i <= nX, selected_coset_indices) ||
            throw(ArgumentError("selected coset index exceeds eligible domain"))
        chosen = Int.(selected_coset_indices)
        issorted(chosen) && length(unique(chosen)) == length(chosen) ||
            throw(ArgumentError("selected coset indices must be increasing and distinct"))
        chosen
    else
        collect(start_x:stop_x)
    end
    finish = result -> selected_scope ? merge(result, (;
        selected_scope=true, selected_coset_indices=copy(indices), next_x=nothing)) : result
    X = X[indices]
    # flats of V5^perp and g5
    C = UInt32[]; Cidx = Int[]
    @inbounds for (fi, w) in enumerate(G.flats)
        ok = true
        for rr in R
            par(w & rr) && (ok = false; break)
        end
        ok && (push!(C, pext(w, Qmask)); push!(Cidx, fi))
    end
    g5 = work.g5
    length(g5) == (1 << D) || resize!(g5, 1 << D)
    fill!(g5, Int16(0))
    @inbounds for c in C; g5[c+1] = Int16(1); end
    fwht!(g5)
    g0 = Int(g5[1])
    hg = _v5_flat_histogram(g5)
    key = hist_key(Dict(vcat([(Int(k), v) for (k, v) in hc], [(100_000_000 + Int(k), v) for (k, v) in hg])))
    Ss = Set{Vector{UInt32}}()
    should_skip(key) &&
        return finish((; Ss, nX, nX_used = 0, next_x=start_x, du_reject = 0, ncand = 0, nT = 0, key, capped = false, skipped = true))
    isempty(X) && return finish((; Ss, nX, nX_used = 0, next_x=start_x, du_reject = 0, ncand = 0, nT = 0, key, capped = false, skipped = false))
    # sorted list of t with small g5 (enough for the largest threshold)
    nWmin = minimum((g0 + Int(g5[x+1])) ÷ 2 for x in X)
    L = UInt32[]
    @inbounds for t in 2:length(g5)
        3 * Int(g5[t]) <= -nWmin && push!(L, UInt32(t - 1))
    end
    sort!(L, by = t -> g5[t+1])
    Lv = [Int(g5[t+1]) for t in L]
    # bitmap of {t : g5(t) <= thb} (2^D5 bits, cache resident). For a prefix element t
    # with a = g5(t) >= -2 nW(U)/3 - thb, a partner b = g5(t+x) > thb cannot satisfy
    # a + b <= -2 nW(U)/3, so the bitmap rejects most pairs without a read of g5.
    thb = -(nWmin ÷ 6)
    bm = zeros(UInt64, max(1, (1 << D) >> 6))
    @inbounds for t in 0:(1 << D)-1
        g5[t+1] <= thb && (bm[(t >> 6)+1] |= UInt64(1) << (t & 63))
    end
    du7_plan=use_du7 && du7_filter!==:triangles ? _du7_prepare(C,Cidx,G,L) : nothing
    du7_bits=du7_plan===nothing ? nothing : _DU7Bits(du7_plan)
    # Keep both candidate branches on one iterator type: mixed iteration states
    # otherwise box millions of indices in the filtered inner loop.
    unfiltered_bad=du7_bits===nothing ? zeros(UInt64,cld(length(L),64)) : UInt64[]
    use_triangles=use_du7 && du7_plan===nothing
    triangle_pairs=NTuple{2,UInt32}[]
    triangle_first=use_triangles ? zeros(UInt32,1<<G.n) : UInt32[]
    triangle_second=use_triangles ? zeros(UInt32,1<<G.n) : UInt32[]
    lifted = [lift(x, Qmask) for x in X]
    du_rej = 0; ncand = 0; nT = 0; capped = false
    pts = work.pts
    Cx = UInt32[]; Tseen = Set{NTuple{3,UInt32}}()
    srows = UInt32[]; spiv = Int[]; sK = UInt32[]
    nX_used = 0
    for (xi, x) in enumerate(X)
        should_stop() && break
        nX_used += 1
        first_ncand = ncand; coset_capped = false
        coset_Ss = coset_observer === nothing ? nothing : Set{Vector{UInt32}}()
        nWU = (g0 + Int(g5[x+1])) ÷ 2
        empty!(Cx)
        empty!(triangle_pairs)
        du_filter && fill!(pts, 0)
        bad = false
        @inbounds for (c, fi) in zip(C, Cidx)
            par(c & x) && continue
            push!(Cx, c)
            if du_filter                         # Lemma 4.6 for U = V5 + <x>
                for p in G.flatpts[fi]
                    pts[p+1] += 1
                    if use_triangles
                        degree=pts[p+1]
                        degree==1 && (triangle_first[p+1]=c)
                        degree==2 && (triangle_second[p+1]=c)
                        degree==3 && triangle_first[p+1]⊻triangle_second[p+1]==c &&
                            push!(triangle_pairs,(triangle_first[p+1],triangle_second[p+1]))
                    end
                    if pts[p+1]>3
                        bad=true
                        break
                    end
                end
                bad && break
            end
        end
        if bad
            du_rej += 1
            coset_observer === nothing || coset_observer((;
                index=indices[xi], next_x=selected_scope ? nothing : indices[xi]+1, total_x=nX,
                representative=lifted[xi], Ss=coset_Ss,
                du_reject=1, ncand=0, nT=0, capped=false))
            continue
        end
        empty!(Tseen)
        last_candidate=searchsortedlast(Lv,fld(-nWU,3))
        candidate_indices=du7_bits===nothing ? _DU7ValidIndices(unfiltered_bad,last_candidate) :
            _du7_valid_indices!(du7_bits,_du7_state(du7_plan,x),last_candidate)
        @inbounds for i in candidate_indices
            t = L[i]; tx = t ⊻ x
            (t == x) && continue
            a = Lv[i]
            (3a >= -2nWU - 3thb && (bm[(tx >> 6)+1] >> (tx & 63)) & 1 == 0) && continue
            b = Int(g5[tx+1])
            # visit each coset {t, t+x} once: from its smaller-g5 member (ties: smaller t)
            (b < a || (b == a && tx < t)) && 3 * b <= -nWU && continue
            3 * (a + b) <= -2nWU || continue
            ncand += 1
            use_triangles && _du7_triangle_reject(triangle_pairs,t) && continue
            sol = _solve_ones_annihilating(Cx, t, D, srows, spiv, sK)
            sol === nothing && continue
            v0, K = sol
            length(K) > max_kernel && (capped = true; coset_capped = true; continue)
            for m in 0:(1 << length(K))-1
                v = v0
                for (j, k) in enumerate(K)
                    (m >> (j - 1)) & 1 == 1 && (v ⊻= k)
                end
                tk = sort3(min(t, t ⊻ x), min(v, v ⊻ x), min(t ⊻ v, t ⊻ v ⊻ x))
                tk in Tseen && continue
                push!(Tseen, tk)
                S = rref(vcat(R, lifted[xi], lift(t, Qmask), lift(v, Qmask)))[1]
                length(S) == G.n || error("dimension of S")
                push!(Ss, S)
                coset_Ss === nothing || push!(coset_Ss, S)
            end
        end
        nT += length(Tseen)
        coset_observer === nothing || coset_observer((;
            index=indices[xi], next_x=selected_scope ? nothing : indices[xi]+1, total_x=nX,
            representative=lifted[xi], Ss=coset_Ss,
            du_reject=0, ncand=ncand-first_ncand, nT=length(Tseen), capped=coset_capped))
    end
    finish((; Ss, nX, nX_used, next_x=start_x+nX_used, du_reject = du_rej, ncand, nT, key, capped, skipped = false))
end

"""Construct a square quadratic SBox from a basis of alternating coordinate forms."""
function function_of(G::Geometry, S::AbstractVector{UInt32})
    c = forms_to_coeffs(S, G.N)
    c, SBox{G.n}(UInt8.(lut_from_coeffs(G, c)))
end

"""Largest bent-element count among all k-dimensional subspaces of a component space."""
function max_bent_dim(comp::Vector{UInt32}, bent::BitVector, k::Int)
    best = Ref(0); nbest = Ref(0)
    subspaces_of_comp(comp, bent, k; keep = nb -> begin
        nb > best[] ? (best[] = nb; nbest[] = 1) : (nb == best[] && (nbest[] += 1)); false
    end)
    best[], nbest[]
end
end
