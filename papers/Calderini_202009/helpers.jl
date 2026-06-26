# Implements shared helpers for Calderini (2020) paper reproduction.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Cryptography and Communications 12:821-840
#
# Pseudocode:
#   1. C₃(F): code for affine equivalence (Section 4, Theorem 5)
#   2. C₄(F): code for affine equivalence of permutations (Theorem 6)
#   3. ZW(λ): zero-Walsh set for component λ (Section 3, before eq. 4)
#   4. S_F: support set for Procedure 2 (Section 3, eq. 4)
#   5. Utilities: power_sbox, perm_inverse, component_degrees
# VBF API used: lat, ccz_matrix, ea_matrix, conway_polynomial, gf_pow, algebraic_degree

using VBF

"""
    c3_matrix(F) -> BitMatrix

(2n+1) × (2^{n+1}-1) generator matrix of the affine-equivalence code C₃(F).
Columns: (1, x, F(x)) for x∈F₂ⁿ plus (0, 0, z) for z∈F₂ⁿ*.
Two non-permutations with NL≠0 are affine-equivalent iff C₃(F) ≅ C₃(G) (Theorem 5).
"""
function c3_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    M = falses(2N + 1, 2n_size - 1)
    @inbounds for x = 0:(n_size - 1)
        M[1, x + 1] = true
        v = (UInt64(x) << N) | UInt64(F.lut[x + 1])
        for b = 0:(2N - 1)
            M[b + 2, x + 1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for z = 1:(n_size - 1)
        col = n_size + z
        for b = 0:(N - 1)
            M[N + b + 2, col] = ((UInt64(z) >> b) & 1) == 1
        end
    end
    return M
end

"""
    c4_matrix(F) -> BitMatrix

(2n+1) × (3·2^n-2) generator matrix of the permutation affine-equivalence code C₄(F).
Columns: (1,x,F(x))ₓ, (0,0,y)_{y≠0}, (1,z,0)_{z≠0}.
Permutations F and G are affine-equivalent iff C₄(F) ≅ C₄(G+b) for some b (Theorem 6).
"""
function c4_matrix(F::SBox{N,T}) where {N,T}
    is_permutation(F) || throw(ArgumentError("c4_matrix: F must be a permutation"))
    n_size = 1 << N
    M = falses(2N + 1, 3n_size - 2)
    @inbounds for x = 0:(n_size - 1)
        M[1, x + 1] = true
        v = (UInt64(x) << N) | UInt64(F.lut[x + 1])
        for b = 0:(2N - 1)
            M[b + 2, x + 1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size - 1)
        col = n_size + y
        for b = 0:(N - 1)
            M[N + b + 2, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    @inbounds for z = 1:(n_size - 1)
        col = 2n_size - 1 + z
        M[1, col] = true
        for b = 0:(N - 1)
            M[b + 2, col] = ((UInt64(z) >> b) & 1) == 1
        end
    end
    return M
end

"""
    zw_set(F, λ) -> Vector{Int}

ZW(λ) = {a ∈ F₂ⁿ : W_{F_λ}(a) = 0} — zero-Walsh set for the λ-component of F.
Used in Procedure 2 to find admissible linear maps (Section 3).
"""
function zw_set(F::SBox{N,T}, λ::Integer) where {N,T}
    n_size = 1 << N
    L = lat(F)
    return Int[a for a = 0:(n_size - 1) if L[a + 1, Int(λ) + 1] == 0]
end

"""
    sf_set(F) -> Vector{Int}

S_F = {λ ∈ F₂ⁿ : ZW(λ) ≠ ∅} ∪ {0} — support set for Procedure 2 (Section 3, eq. 4).
"""
function sf_set(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    L = lat(F)
    S = Int[0]
    for λ = 1:(n_size - 1)
        if any(L[a + 1, λ + 1] == 0 for a = 1:(n_size - 1))
            push!(S, λ)
        end
    end
    return S
end

"""
    perm_inverse(F) -> SBox

Functional inverse of a permutation SBox.
"""
function perm_inverse(F::SBox{N,T}) where {N,T}
    is_permutation(F) || throw(ArgumentError("perm_inverse: F must be a permutation"))
    n_size = 1 << N
    inv_lut = Vector{T}(undef, n_size)
    for x = 0:(n_size - 1)
        inv_lut[F.lut[x + 1] + 1] = T(x)
    end
    return SBox{N,T}(inv_lut)
end

"""
    power_sbox(n, d) -> SBox

x ↦ xᵈ over GF(2ⁿ) with Conway polynomial modulus.
"""
function power_sbox(n::Int, d::Int)
    mod = conway_polynomial(n)
    SBox{n}([gf_pow(x, d, n; modulus = mod) for x = 0:((1 << n) - 1)])
end

"""
    component_degrees(F) -> Dict{Int,Int}

Algebraic degree distribution of the 2ⁿ-1 non-zero components of F.
Each component is Fb(x) = Tr(b·F(x)) ∈ F₂. Returns `degree => count`.
"""
function component_degrees(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    degs = Dict{Int,Int}()
    for b = 1:(n_size - 1)
        comp_lut = UInt8[count_ones(b & UInt(F.lut[x + 1])) % 2 for x = 0:(n_size - 1)]
        d = algebraic_degree(SBox{N,UInt8}(comp_lut))
        degs[d] = get(degs, d, 0) + 1
    end
    return degs
end

# ── Print utilities ──────────────────────────────────────────────────────────

