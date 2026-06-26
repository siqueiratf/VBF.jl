# Shared helpers for the Canteaut–Couvreur–Perrin (2022) reproduction.
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: General — Jacobian tools, rank table, report utilities
#
# Pseudocode (Jac_lin):
#   jac_lin_cols(F, a):
#     col j = F(a ⊕ eⱼ) ⊕ F(a) ⊕ F(eⱼ) ⊕ F(0)   [Def. 3.3, Eq. 3]
#   rank_table(F):
#     for each a ≠ 0: rank of the linear map x ↦ Jac_lin F(a) · x
#   Jac_lin F(a) · x = F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0)  [Prop. 14]
# VBF API used: SBox, F2LinearMap, rank_f2, gf_monomial_lut

using VBF

# ── Jacobian utilities ─────────────────────────────────────────────────────────

"""
    jac_lin_cols(F::SBox{N,T}, a::Integer) -> Vector{T}

Columns of Jac_lin F(a): n vectors in F₂ⁿ where
  col[j+1] = F(a ⊕ eⱼ) ⊕ F(a) ⊕ F(eⱼ) ⊕ F(0).

Jac_lin F(a) is the linear part of the Jacobian of the quadratic function F
evaluated at a (Definition 3.3). Each column is an element of F₂ⁿ = T.
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

rank_table[a+1] = rank of Jac_lin F(a) for a ∈ 0:2^N-1.
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

Histogram of ranks over all nonzero inputs, from a precomputed rank table.
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

# ── EA triple construction ──────────────────────────────────────────────────────

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

"""
    gold_apn(N::Int) -> SBox

Gold function x^3 over F₂ᴺ.
"""
function gold_apn(N::Int)
    lut = gf_monomial_lut(N, 3)
    T = N ≤ 8 ? UInt8 : UInt16
    return SBox{N,T}(T.(lut))
end

# ── GF(2) augmented linear system (Algorithm 1 kernel) ────────────────────────

"""
    solve_augmented_gf2(rows::Vector{UInt128}, n_unknowns::Int)
        -> Union{Tuple{UInt128, Vector{UInt128}}, Nothing}

Solve the GF(2) linear system whose rows are packed in `rows`, where
bits 0..n_unknowns-1 are coefficients and bit n_unknowns is the RHS.

Returns (particular_solution, kernel_basis), or `nothing` if inconsistent.
Operates in-place on a copy of rows.
"""
function solve_augmented_gf2(rows::Vector{UInt128}, n_unknowns::Int)
    work = copy(rows)
    n_rows = length(work)
    pivot_for_row = fill(-1, n_rows)
    is_pivot_col = falses(n_unknowns)
    rhs_bit = UInt128(1) << n_unknowns
    rank = 0

    @inbounds for c in 0:(n_unknowns-1)
        bit = UInt128(1) << c
        p = 0
        for i in (rank+1):n_rows
            if (work[i] & bit) != 0
                p = i; break
            end
        end
        p == 0 && continue
        work[rank+1], work[p] = work[p], work[rank+1]
        pivot = work[rank+1]
        for i in 1:n_rows
            i == rank + 1 && continue
            if (work[i] & bit) != 0
                work[i] ⊻= pivot
            end
        end
        pivot_for_row[rank+1] = c
        is_pivot_col[c+1] = true
        rank += 1
    end

    # Inconsistency check
    coeff_mask = (UInt128(1) << n_unknowns) - UInt128(1)
    @inbounds for i in 1:n_rows
        if (work[i] & coeff_mask) == 0 && (work[i] & rhs_bit) != 0
            return nothing
        end
    end

    # Particular solution (free vars = 0)
    particular = UInt128(0)
    @inbounds for i in 1:rank
        if (work[i] & rhs_bit) != 0
            particular |= UInt128(1) << pivot_for_row[i]
        end
    end

    # Kernel basis: one vector per free column
    ker = UInt128[]
    @inbounds for f in 0:(n_unknowns-1)
        is_pivot_col[f+1] && continue
        v = UInt128(1) << f
        for i in 1:rank
            if ((work[i] >> f) & 1) == 1
                v |= UInt128(1) << pivot_for_row[i]
            end
        end
        push!(ker, v)
    end

    return (particular, ker)
end

"""
    extract_f2linear(u::UInt128, offset::Int, N::Int, ::Type{T}) -> F2LinearMap{N,T}

Extract an N×N F₂-linear map from bits [offset, offset+N²) of u.
Bits are stored in row-major order: bit (i*N + j) is entry X[i,j].
The map is returned in column form (F2LinearMap convention).
"""
function extract_f2linear(u::UInt128, offset::Int, N::Int, ::Type{T}) where {T<:Unsigned}
    cols = Vector{T}(undef, N)
    @inbounds for j in 0:(N-1)
        col = zero(T)
        for i in 0:(N-1)
            if ((u >> (offset + i*N + j)) & 1) == 1
                col |= T(1) << i
            end
        end
        cols[j+1] = col
    end
    return F2LinearMap{N,T}(cols)
end

# ── Report utilities ───────────────────────────────────────────────────────────

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Canteaut–Couvreur–Perrin (2022):")
    println(io, "  Recovering or Testing Extended-Affine Equivalence")
    println(io, "=" ^ 72)
end

