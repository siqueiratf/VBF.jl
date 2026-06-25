# Implements Section 3.2 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.2 — The Jacobian Matrices of EA-equivalent Functions
#
# Section 3.2: If G = A ∘ F ∘ B + C with A, B affine permutations and C
#   affine, and A₀, B₀ their linear parts, then for all x ∈ F₂ⁿ:
#   Jac_lin G(x) = A₀ · Jac_lin F(B₀ x) · B₀.
#
# This is the key chain rule that does not involve C — it permits searching
# for (A₀, B₀) without knowing C.
#
# Pseudocode:
#   1. Choose random invertible A₀, B₀ ∈ F₂^{n×n}
#   2. Construct G = A₀ ∘ F ∘ B₀ (linear case, C₀=0, a=0 for simplicity)
#   3. For each x: verify Jac_lin G(x) = A₀ · Jac_lin F(B₀ x) · B₀
#      i.e., for each column j:
#        jac_lin_cols(G, x)[j+1] = A₀(jac_lin_apply(jac_lin_cols(F, B₀(x)), B₀(eⱼ)))
# VBF API used: SBox, F2LinearMap, identity_linear_map, compose, inv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    verify_section3_2(F::SBox{N,T}, A0::F2LinearMap, B0::F2LinearMap) -> Bool

Verify Jac_lin G(x) = A₀ · Jac_lin F(B₀ x) · B₀ for G = A₀ ∘ F ∘ B₀.
Checks all x ∈ F₂ⁿ.
"""
function verify_section3_2(
    F::SBox{N,T},
    A0::F2LinearMap{N,T},
    B0::F2LinearMap{N,T},
) where {N,T}
    n_size = 1 << N
    # G = A0(F(B0(x)))  (C=0, a=0)
    G = SBox{N,T}(T[A0(F.lut[B0(x)+1]) for x in 0:(n_size-1)])

    @inbounds for x in 0:(n_size-1)
        cols_G = jac_lin_cols(G, x)        # cols of Jac_lin G(x)
        B0x = B0(x)
        cols_F = jac_lin_cols(F, B0x)     # cols of Jac_lin F(B₀x)
        # Check column j: cols_G[j+1] == A0(cols_F · B₀(eⱼ))
        for j in 0:(N-1)
            ej = T(1) << j
            # B₀ eⱼ = B0.cols[j+1]
            B0ej = B0.cols[j+1]
            # Jac_lin F(B₀x) · B₀eⱼ
            jac_F_B0x_times_B0ej = jac_lin_apply(cols_F, B0ej)
            expected = A0(jac_F_B0x_times_B0ej)
            cols_G[j+1] == expected || return false
        end
    end
    return true
end

"""
    section3_2_report(; io, n_values) -> NamedTuple

Verify Section 3.2 on Gold x^3 with explicit EA triples for n=5, 6.
Uses two different invertible (A₀, B₀) pairs per dimension.
"""
function section3_2_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section(
        "Section 3.2: Jac_lin G(x) = A₀·Jac_lin F(B₀x)·B₀ for EA-equiv F,G",
        io,
    )

    results = Dict{Int,Bool}()
    for N in n_values
        T = N ≤ 8 ? UInt8 : UInt16
        F = gold_apn(N)

        # Build a non-trivial invertible A₀: swap bits 0 and 1 via XOR
        # A₀(x) = x ⊕ ((x & 1) << 1) ⊕ ((x >> 1) & 1)  -- this is 01-transposition
        # Simpler: use the matrix with cols [2,1,4,8,...] (swap e0 and e1 images)
        A0_cols = Vector{T}(undef, N)
        A0_cols[1] = T(2); A0_cols[2] = T(1)
        for j in 2:(N-1); A0_cols[j+1] = T(1) << j; end
        A0 = F2LinearMap{N,T}(A0_cols)

        # B₀: shift basis cyclically: eⱼ ↦ e_{j+1 mod N}
        B0_cols = Vector{T}(undef, N)
        for j in 0:(N-1); B0_cols[j+1] = T(1) << ((j+1) % N); end
        B0 = F2LinearMap{N,T}(B0_cols)

        ok = verify_section3_2(F, A0, B0)
        results[N] = ok
        print_check("Gold x^3 n=$N: Section 3.2 holds for (A₀, B₀)", ok, io)
    end
    all_ok = all(values(results))
    print_check("Section 3.2 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section3_2_report()
end
