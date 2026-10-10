# Implements Proposition 14 (and Corollary 15) from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.3 — The Jacobian Matrix of a Quadratic Function
#
# Proposition 14: For any quadratic F : F₂ⁿ → F₂ᵐ and any a, x ∈ F₂ⁿ,
#   Δ_a F(x) + Δ_a F(0) = Jac_lin F(x) · a = Jac_lin F(a) · x.
#
# Equivalently: F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0) = Jac_lin F(a) · x
#
# Corollary 15: Jac_lin F(a) · a = 0 for all a.
#
# Pseudocode:
#   For each a ≠ 0 and each x ∈ F₂ⁿ:
#     1. Compute lhs = F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0)
#     2. Compute rhs = jac_lin_apply(jac_lin_cols(F, a), x)
#     3. Verify lhs == rhs   (and the symmetric form Jac_lin F(x) · a)
# VBF API used: SBox, gold_apn, qam_to_sbox (via helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    verify_proposition14(F::SBox{N,T}) -> Bool

Check Δ_a F(x) ⊕ Δ_a F(0) == Jac_lin F(a)·x == Jac_lin F(x)·a for all (a, x).
"""
function verify_proposition14(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    F0 = F.lut[1]
    all_cols = [jac_lin_cols(F, a) for a in 0:(n_size-1)]
    @inbounds for a in 1:(n_size-1)
        Fa = F.lut[a+1]
        cols_a = all_cols[a+1]
        for x in 0:(n_size-1)
            lhs = F.lut[(x ⊻ a) + 1] ⊻ F.lut[x+1] ⊻ Fa ⊻ F0
            lhs == jac_lin_apply(cols_a, x) || return false
            lhs == jac_lin_apply(all_cols[x+1], a) || return false
        end
    end
    return true
end

"""
    verify_corollary15(F::SBox{N,T}) -> Bool

Check Jac_lin F(a) · a == 0 for all a (Corollary 15).
"""
function verify_corollary15(F::SBox{N,T}) where {N,T}
    for a in 0:((1 << N) - 1)
        jac_lin_apply(jac_lin_cols(F, a), a) == 0 || return false
    end
    return true
end

"""
    proposition14_report(; io, n_values) -> NamedTuple

Verify Proposition 14 and Corollary 15 on Gold x^3 (APN, single-rank Jac_lin)
and on a deterministic non-APN quadratic with a multi-valued rank distribution.
"""
function proposition14_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section("Proposition 14: Δ_a F(x) ⊕ Δ_a F(0) = Jac_lin F(a)·x", io)
    results = Bool[]
    for N in n_values
        F = gold_apn(N)
        ok = verify_proposition14(F)
        push!(results, ok)
        print_check("Gold x^3 n=$N: all (a,x) verify Prop 14", ok, io)

        ok15 = verify_corollary15(F)
        push!(results, ok15)
        print_check("Gold x^3 n=$N: Jac_lin F(a)·a = 0 (Cor 15)", ok15, io)
    end

    # Non-APN quadratic with multi-valued rank distribution
    Q = pseudo_random_multirank_quadratic(6)
    print_kv("multirank quadratic n=6 rank distribution", counts_dict(Q), io)
    okq = verify_proposition14(Q) && verify_corollary15(Q)
    push!(results, okq)
    print_check("multirank quadratic n=6: Prop 14 + Cor 15", okq, io)

    all_ok = all(results)
    print_check("Proposition 14 overall", all_ok, io)
    return (; results, all_ok)
end

counts_dict(F::SBox) = sort(collect(rank_distribution(F)))

if abspath(PROGRAM_FILE) == @__FILE__
    proposition14_report()
end
