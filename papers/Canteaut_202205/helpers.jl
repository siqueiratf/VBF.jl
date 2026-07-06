# Shared helpers for the Canteaut–Couvreur–Perrin (2022) reproduction.
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: General — Jacobian tools, rank table, GF(2) solver, Banff list
#
# Pseudocode (Jac_lin):
#   jac_lin_cols(F, a):
#     col j = F(a ⊕ eⱼ) ⊕ F(a) ⊕ F(eⱼ) ⊕ F(0)   [Definition 12, Eq. (3)]
#   rank_table(F):
#     for each a ≠ 0: rank of the linear map x ↦ Jac_lin F(a) · x  [Def. 19]
#   Jac_lin F(a) · x = F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0)  [Proposition 14]
# VBF API used: SBox, F2LinearMap, rank_f2, gold_apn, qam_to_sbox,
#               polynomial_terms, terms_to_lut, conway_polynomial

using VBF

# -- Jacobian linear part ---------------------------------------------------

"""
    jac_lin_cols(F::SBox{N,T}, a::Integer) -> Vector{T}

Columns of Jac_lin F(a): n vectors in F₂ⁿ where
  col[j+1] = F(a ⊕ eⱼ) ⊕ F(a) ⊕ F(eⱼ) ⊕ F(0).

Jac_lin F(a) is the linear part of the Jacobian of the quadratic function F
evaluated at a (Definition 12, Eq. (3)). Each column is an element of F₂ᵐ = T.
"""
function jac_lin_cols(F::SBox{N,T}, a::Integer) where {N,T}
    Fa = F.lut[a+1]
    F0 = F.lut[1]
    cols = Vector{T}(undef, N)
    @inbounds for j in 0:(N-1)
        ej = T(1) << j
        cols[j+1] = F.lut[(Int(a) ⊻ Int(ej)) + 1] ⊻ Fa ⊻ F.lut[Int(ej) + 1] ⊻ F0
    end
    return cols
end

"""
    jac_lin_apply(cols::Vector{T}, x::Integer) -> T

Evaluate the linear map defined by `cols` at `x`: XOR of col[j+1] for each bit j set in x.
Implements the matrix–vector product Jac_lin F(a) · x.
"""
function jac_lin_apply(cols::Vector{T}, x::Integer) where {T}
    y = zero(T)
    @inbounds for j in 0:(length(cols)-1)
        if ((x >> j) & 1) == 1
            y ⊻= cols[j+1]
        end
    end
    return y
end

"""
    jac_lin_rank(F::SBox{N,T}, a::Integer) -> Int

Rank of Jac_lin F(a) over F₂.

Uses Proposition 14: Jac_lin F(a) · x = F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0),
so the image is the span of {F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0) : x ∈ F₂ⁿ}.
Rank = dimension of this span.
"""
function jac_lin_rank(F::SBox{N,T}, a::Integer) where {N,T}
    n_size = 1 << N
    Fa = F.lut[a+1]
    F0 = F.lut[1]
    rows = Vector{T}(undef, n_size)
    @inbounds for x in 0:(n_size-1)
        rows[x+1] = F.lut[(x ⊻ a) + 1] ⊻ F.lut[x+1] ⊻ Fa ⊻ F0
    end
    return rank_f2(rows; nbits=N)
end

"""
    rank_table(F::SBox{N,T}) -> Vector{Int}

rank_table[a+1] = rank of Jac_lin F(a) for a ∈ 0:2^N-1 (Definition 19).
Entry at a=0 is 0 by convention (Jac_lin F(0) = 0).
"""
function rank_table(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    rt = zeros(Int, n_size)
    @inbounds for a in 1:(n_size-1)
        rt[a+1] = jac_lin_rank(F, a)
    end
    return rt
end

"""
    rank_distribution(rt::Vector{Int}, N::Int) -> Dict{Int,Int}

Histogram of ranks over all nonzero inputs, from a precomputed rank table
(the ℛ_dist(F) of Definition 19).
"""
function rank_distribution(rt::Vector{Int}, N::Int)
    dist = Dict{Int,Int}()
    for a in 1:((1<<N)-1)
        r = rt[a+1]
        dist[r] = get(dist, r, 0) + 1
    end
    return dist
end

"""
    rank_distribution(F::SBox{N,T}) -> Dict{Int,Int}

Rank distribution of Jac_lin F over all nonzero inputs (allocates rank table).
"""
rank_distribution(F::SBox{N,T}) where {N,T} = rank_distribution(rank_table(F), N)

# -- EA triples -------------------------------------------------------------

"""
    build_ea_triple(F::SBox{N,T}, A0::F2LinearMap, B0::F2LinearMap,
                    C0::F2LinearMap, a_const::T) -> SBox{N,T}

Construct G = A0 ∘ F ∘ B0 + C0 + a_const (EA triple).
"""
function build_ea_triple(
    F::SBox{N,T},
    A0::F2LinearMap{N,T},
    B0::F2LinearMap{N,T},
    C0::F2LinearMap{N,T},
    a_const::T,
) where {N,T}
    n_size = 1 << N
    lut = Vector{T}(undef, n_size)
    @inbounds for x in 0:(n_size-1)
        lut[x+1] = A0(F.lut[B0(x)+1]) ⊻ C0(T(x)) ⊻ a_const
    end
    return SBox{N,T}(lut)
end

# -- deterministic quadratic generator ---------------------------------------

"""
    _xorshift(state::UInt64) -> UInt64

Tiny deterministic xorshift64 step. Used instead of a stdlib RNG so the
"random" quadratic functions in this reproduction are bit-identical across
Julia versions.
"""
function _xorshift(state::UInt64)
    state ⊻= state << 13
    state ⊻= state >> 7
    state ⊻= state << 17
    return state
end

"""
    pseudo_random_quadratic(N::Int; seed=0x9E3779B97F4A7C15) -> SBox

Deterministic pseudo-random homogeneous quadratic F : F₂ᴺ → F₂ᴺ, built from a
random symmetric zero-diagonal derivative matrix via `qam_to_sbox` (the QAM
correspondence of Definition 17 / Proposition 18). Generic such functions are
not APN and have a multi-valued Jac_lin rank distribution, which exercises the
non-degenerate cases of Propositions 22 and 25 and Corollary 24.
"""
function pseudo_random_quadratic(N::Int; seed::UInt64 = 0x9E3779B97F4A7C15)
    M = zeros(Int, N, N)
    st = seed
    for i in 1:N, j in (i+1):N
        st = _xorshift(st)
        v = Int(st & UInt64((1 << N) - 1))
        M[i, j] = v
        M[j, i] = v
    end
    return qam_to_sbox(M)
end

"""
    pseudo_random_multirank_quadratic(N::Int) -> SBox

A deterministic quadratic F₂ᴺ → F₂ᴺ function whose Jac_lin rank distribution
takes at least two distinct values (scans seeds until one is found; the first
seed already works for N = 5, 6).
"""
function pseudo_random_multirank_quadratic(N::Int)
    for k in 0:63
        F = pseudo_random_quadratic(N; seed = 0x9E3779B97F4A7C15 + UInt64(k))
        length(rank_distribution(F)) ≥ 2 && return F
    end
    error("no multi-rank quadratic found for N=$N (unexpected)")
end

# -- packed GF(2) linear algebra (multi-word rows) ---------------------------
#
# Rows are bit-packed into UInt64 words: bits 0..n_unknowns-1 hold the
# coefficients, bit n_unknowns holds the affine right-hand side. A system of
# rows is stored column-contiguously in a Matrix{UInt64} `work` of size
# (nwords, n_rows): word w of row i is work[w, i]. This supports 2N²+1 bits
# for any N ≤ 9 (163 bits → 3 words), lifting the old UInt128 (N ≤ 6) cap.

"""
    nwords_for_bits(nbits::Int) -> Int

Number of UInt64 words needed for `nbits` bits.
"""
nwords_for_bits(nbits::Int) = (nbits + 63) >>> 6

@inline _getbit(work::Matrix{UInt64}, i::Int, b::Int) =
    (work[(b >>> 6) + 1, i] >> (b & 63)) & 1 == 1

@inline function _setbit!(work::Matrix{UInt64}, i::Int, b::Int)
    work[(b >>> 6) + 1, i] |= UInt64(1) << (b & 63)
    return nothing
end

@inline _vgetbit(v::Vector{UInt64}, b::Int) =
    (v[(b >>> 6) + 1] >> (b & 63)) & 1 == 1

@inline function _vsetbit!(v::Vector{UInt64}, b::Int)
    v[(b >>> 6) + 1] |= UInt64(1) << (b & 63)
    return nothing
end

"""
    solve_augmented_gf2!(work::Matrix{UInt64}, n_rows::Int, n_unknowns::Int)
        -> Union{Nothing, NamedTuple}

In-place Gauss–Jordan elimination on the packed augmented GF(2) system held in
the first `n_rows` columns of `work` (layout above). Returns
`(; rank, particular, kernel)` where `rank` is the rank of the coefficient
matrix, `particular::Vector{UInt64}` a particular solution (free variables 0)
and `kernel::Vector{Vector{UInt64}}` a kernel basis — or `nothing` when the
affine system is inconsistent. Destroys `work`.
"""
function solve_augmented_gf2!(work::Matrix{UInt64}, n_rows::Int, n_unknowns::Int)
    W = size(work, 1)
    pivot_col = fill(-1, n_rows)
    is_pivot_col = falses(n_unknowns)
    rank = 0

    @inbounds for c in 0:(n_unknowns-1)
        wi = (c >>> 6) + 1
        bit = UInt64(1) << (c & 63)
        p = 0
        for i in (rank+1):n_rows
            if work[wi, i] & bit != 0
                p = i
                break
            end
        end
        p == 0 && continue
        if p != rank + 1
            for w in 1:W
                work[w, rank+1], work[w, p] = work[w, p], work[w, rank+1]
            end
        end
        for i in 1:n_rows
            i == rank + 1 && continue
            if work[wi, i] & bit != 0
                for w in 1:W
                    work[w, i] ⊻= work[w, rank+1]
                end
            end
        end
        rank += 1
        pivot_col[rank] = c
        is_pivot_col[c+1] = true
    end

    # Inconsistency: a zero-coefficient row (any row > rank) with RHS bit set.
    rhs_wi = (n_unknowns >>> 6) + 1
    rhs_bit = UInt64(1) << (n_unknowns & 63)
    @inbounds for i in (rank+1):n_rows
        work[rhs_wi, i] & rhs_bit != 0 && return nothing
    end

    W_sol = nwords_for_bits(n_unknowns)

    # Particular solution (free vars = 0).
    particular = zeros(UInt64, W_sol)
    @inbounds for i in 1:rank
        if work[rhs_wi, i] & rhs_bit != 0
            _vsetbit!(particular, pivot_col[i])
        end
    end

    # Kernel basis: one vector per free column.
    kernel = Vector{Vector{UInt64}}()
    @inbounds for f in 0:(n_unknowns-1)
        is_pivot_col[f+1] && continue
        v = zeros(UInt64, W_sol)
        _vsetbit!(v, f)
        for i in 1:rank
            _getbit(work, i, f) && _vsetbit!(v, pivot_col[i])
        end
        push!(kernel, v)
    end

    return (; rank, particular, kernel)
end

"""
    extract_f2linear(u::Vector{UInt64}, offset::Int, N::Int, ::Type{T})
        -> F2LinearMap{N,T}

Extract an N×N F₂-linear map from bits [offset, offset+N²) of the packed bit
vector `u`. Bits are stored in row-major order: bit (i*N + j) is entry X[i,j].
The map is returned in column form (F2LinearMap convention).
"""
function extract_f2linear(u::Vector{UInt64}, offset::Int, N::Int, ::Type{T}) where {T<:Unsigned}
    cols = Vector{T}(undef, N)
    @inbounds for j in 0:(N-1)
        col = zero(T)
        for i in 0:(N-1)
            if _vgetbit(u, offset + i*N + j)
                col |= T(1) << i
            end
        end
        cols[j+1] = col
    end
    return F2LinearMap{N,T}(cols)
end

# -- Banff list (Table 6) -----------------------------------------------------

# Table 6 of the paper: the 13 six-bit quadratic APN functions of the Banff
# list; α (written `ksi` for polynomial_terms) is a root of x⁶+x⁴+x³+x+1,
# which is exactly conway_polynomial(6). Function 5 is the Kim mapping κ.
const BANFF_TABLE6 = [
    "X**3",
    "X**3 + ksi**11*X**6 + ksi*X**9",
    "ksi*X**5 + X**9 + ksi**4*X**17 + ksi*X**18 + ksi**4*X**20 + ksi*X**24 + ksi**4*X**34 + ksi*X**40",
    "ksi**7*X**3 + X**5 + ksi**3*X**9 + ksi**4*X**10 + X**17 + ksi**6*X**18",
    "X**3 + X**10 + ksi*X**24",
    "X**3 + ksi**17*X**17 + ksi**17*X**18 + ksi**17*X**20 + ksi**17*X**24",
    "X**3 + ksi**11*X**5 + ksi**13*X**9 + X**17 + ksi**11*X**33 + X**48",
    "ksi**25*X**5 + X**9 + ksi**38*X**12 + ksi**25*X**18 + ksi**25*X**36",
    "ksi**40*X**5 + ksi**10*X**6 + ksi**62*X**20 + ksi**35*X**33 + ksi**15*X**34 + ksi**29*X**48",
    "ksi**34*X**6 + ksi**52*X**9 + ksi**48*X**12 + ksi**6*X**20 + ksi**9*X**33 + ksi**23*X**34 + ksi**25*X**40",
    "X**9 + ksi**4*X**10 + ksi**9*X**12 + ksi**4*X**18 + ksi**9*X**20 + ksi**9*X**40",
    "ksi**52*X**3 + ksi**47*X**5 + ksi*X**6 + ksi**9*X**9 + ksi**44*X**12 + ksi**47*X**33 + ksi**10*X**34 + ksi**33*X**40",
    "ksi*X**6 + X**9 + ksi*X**10 + ksi**4*X**17 + ksi*X**24 + ksi*X**33",
]

"""
    banff_functions() -> Vector{SBox{6,UInt8}}

The 13 functions of the Banff list (Table 6), constructed from their
univariate representations over GF(2⁶) with α a root of x⁶+x⁴+x³+x+1
(= `conway_polynomial(6)`). `banff_functions()[5].lut == kim_apn().lut`.
"""
function banff_functions()
    mod6 = conway_polynomial(6)
    return [
        SBox{6}(terms_to_lut(polynomial_terms(s, 6, mod6), 6, mod6)) for
        s in BANFF_TABLE6
    ]
end

# -- misc ---------------------------------------------------------------------

"""
    counts(values) -> Vector{Pair{Int,Int}}

Sorted `value => multiplicity` pairs, e.g. to turn a `thickness_spectrum`
vector into the `{t: count}` form used in the paper.
"""
function counts(values)
    d = Dict{Int,Int}()
    for v in values
        d[v] = get(d, v, 0) + 1
    end
    return sort(collect(d))
end

print_header(io::IO = stdout) = print_banner(
    io,
    "Canteaut–Couvreur–Perrin (2022):",
    "  Recovering or Testing Extended-Affine Equivalence",
)
