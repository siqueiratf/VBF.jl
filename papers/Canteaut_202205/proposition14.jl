# Implements Proposition 14 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.3 — The Jacobian Matrix of a Quadratic Function
#
# Proposition 14: For any quadratic F : F₂ⁿ → F₂ⁿ and any a, x ∈ F₂ⁿ,
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
    verify_proposition14(F::SBox{N,T}) -> Bool

Check Δ_a F(x) ⊕ Δ_a F(0) == Jac_lin F(a) · x for all (a, x).
"""
function verify_proposition14(F::SBox{N,T}) where {N,T}
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
    proposition14_report(; io, n_values) -> NamedTuple

Verify Proposition 14 on Gold x^3 APN for multiple dimensions.
"""
function proposition14_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section("Proposition 14: Δ_a F(x) ⊕ Δ_a F(0) = Jac_lin F(a)·x", io)
    results = Dict{Int,Bool}()
    for N in n_values
        F = gold_apn(N)
        ok = verify_proposition14(F)
        results[N] = ok
        print_check("Gold x^3 n=$N: all (a,x) verify Prop 14", ok, io)
    end
    all_ok = all(values(results))
    print_check("Proposition 14 overall", all_ok, io)
    return (; results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition14_report()
end
