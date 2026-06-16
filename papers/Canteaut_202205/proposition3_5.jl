# Implements Proposition 3.5 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.3 — The Jacobian Matrix of a Quadratic Function
#
# Proposition 3.5: For any quadratic F : F₂ⁿ → F₂ⁿ and any a, x ∈ F₂ⁿ,
#   Δ_a F(x) + Δ_a F(0) = Jac_lin F(x) · a = Jac_lin F(a) · x.
#
# Equivalently: F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0) = Jac_lin F(a) · x
#
# Pseudocode:
#   For each a ≠ 0 and each x ∈ F₂ⁿ:
#     1. Compute lhs = F(x⊕a) ⊕ F(x) ⊕ F(a) ⊕ F(0)
#     2. Compute rhs = jac_lin_apply(jac_lin_cols(F, a), x)
#     3. Verify lhs == rhs
# VBF API used: SBox, gf_monomial_lut

include(joinpath(@__DIR__, "helpers.jl"))

"""
    verify_proposition3_5(F::SBox{N,T}) -> Bool

Check Δ_a F(x) ⊕ Δ_a F(0) == Jac_lin F(a) · x for all (a, x).
"""
function verify_proposition3_5(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    F0 = F.lut[1]
    @inbounds for a in 1:(n_size-1)
        Fa = F.lut[a+1]
        cols = jac_lin_cols(F, a)
        for x in 0:(n_size-1)
            lhs = F.lut[(x ⊻ a) + 1] ⊻ F.lut[x+1] ⊻ Fa ⊻ F0
            rhs = jac_lin_apply(cols, x)
            lhs == rhs || return false
        end
    end
    return true
end

"""
    proposition3_5_report(; io, n_values) -> NamedTuple

Verify Proposition 3.5 on Gold x^3 APN for multiple dimensions.
"""
function proposition3_5_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section("Proposition 3.5: Δ_a F(x) ⊕ Δ_a F(0) = Jac_lin F(a)·x", io)
    results = Dict{Int,Bool}()
    for N in n_values
        F = gold_apn(N)
        ok = verify_proposition3_5(F)
        results[N] = ok
        print_check("Gold x^3 n=$N: all (a,x) verify Prop 3.5", ok, io)
    end
    all_ok = all(values(results))
    print_check("Proposition 3.5 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition3_5_report()
end
