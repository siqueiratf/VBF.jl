# Implements Proposition 16 (Section 3.2) from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.2 — The Jacobian Matrices of EA-equivalent Functions
#
# Proposition 16 (Eq. (4)): If G = A ∘ F ∘ B + C with A, B affine permutations
#   and C affine, and A₀, B₀ their linear parts, then for all x ∈ F₂ⁿ:
#   Jac_lin G(x) = A₀ · Jac_lin F(B(x)) · B₀.
#
# This is the chain rule that does not involve C — it permits searching
# for (A₀, B₀) without knowing C.
#
# Pseudocode:
#   1. Choose invertible A₀, B₀ ∈ F₂^{n×n}
#   2. Construct G = A₀ ∘ F ∘ B₀ (linear case: B = B₀, C₀ = 0, a = 0)
#   3. For each x: verify Jac_lin G(x) = A₀ · Jac_lin F(B₀ x) · B₀
#      i.e., for each column j:
#        jac_lin_cols(G, x)[j+1] = A₀(jac_lin_apply(jac_lin_cols(F, B₀(x)), B₀(eⱼ)))
# VBF API used: SBox, F2LinearMap, identity_linear_map, gold_apn

include(joinpath(@__DIR__, "helpers.jl"))

"""
    verify_proposition16(F::SBox{N,T}, A0::F2LinearMap, B0::F2LinearMap) -> Bool

Verify Jac_lin G(x) = A₀ · Jac_lin F(B₀ x) · B₀ for G = A₀ ∘ F ∘ B₀
(Proposition 16 / Eq. (4)). Checks all x ∈ F₂ⁿ.
"""
function verify_proposition16(
    F::SBox{N,T},
    A0::F2LinearMap{N,T},
    B0::F2LinearMap{N,T},
) where {N,T}
    n_size = 1 << N
    # G = A0(F(B0(x)))  (C=0, a=0)
    G = SBox{N,T}(T[A0(F.lut[B0(x)+1]) for x in 0:(n_size-1)])

    @inbounds for x in 0:(n_size-1)
        cols_G = jac_lin_cols(G, x)        # cols of Jac_lin G(x)
        cols_F = jac_lin_cols(F, B0(x))    # cols of Jac_lin F(B₀x)
        # Check column j: cols_G[j+1] == A0(Jac_lin F(B₀x) · B₀eⱼ)
        for j in 0:(N-1)
            B0ej = B0.cols[j+1]
            expected = A0(jac_lin_apply(cols_F, B0ej))
            cols_G[j+1] == expected || return false
        end
    end
    return true
end

# Backwards-compatible alias (old file name / function name)
verify_section3_2(F, A0, B0) = verify_proposition16(F, A0, B0)

"""
    _demo_maps(N, ::Type{T}) -> (A0, B0)

Fixed non-trivial invertible pair used across the reproduction:
A₀ swaps images of e₀/e₁, B₀ shifts the basis cyclically.
"""
function _demo_maps(N::Int, ::Type{T}) where {T}
    A0_cols = Vector{T}(undef, N)
    A0_cols[1] = T(2); A0_cols[2] = T(1)
    for j in 2:(N-1); A0_cols[j+1] = T(1) << j; end
    A0 = F2LinearMap{N,T}(A0_cols)

    B0_cols = T[T(1) << ((j+1) % N) for j in 0:(N-1)]
    B0 = F2LinearMap{N,T}(B0_cols)
    return (A0, B0)
end

"""
    section3_2_report(; io, n_values) -> NamedTuple

Verify Proposition 16 on Gold x^3 for n=5, 6 and on a non-APN multirank
quadratic for n=6, with explicit invertible (A₀, B₀) pairs.
"""
function section3_2_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section(
        "Proposition 16 (Sec. 3.2): Jac_lin G(x) = A₀·Jac_lin F(B₀x)·B₀",
        io,
    )

    results = Bool[]
    for N in n_values
        F = gold_apn(N)
        T = storage_type(F)
        A0, B0 = _demo_maps(N, T)
        ok = verify_proposition16(F, A0, B0)
        push!(results, ok)
        print_check("Gold x^3 n=$N: Proposition 16 holds for (A₀, B₀)", ok, io)
    end

    # Non-APN multirank quadratic
    Q = pseudo_random_multirank_quadratic(6)
    TQ = storage_type(Q)
    A0, B0 = _demo_maps(6, TQ)
    okq = verify_proposition16(Q, A0, B0)
    push!(results, okq)
    print_check("multirank quadratic n=6: Proposition 16 holds", okq, io)

    all_ok = all(results)
    print_check("Proposition 16 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section3_2_report()
end
