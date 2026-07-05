# Implements Proposition 5 — Refined Trace Condition ↔ APN
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 4 — Necessary Condition for a Generalized Butterfly to be APN
#
# Pseudocode:
#   For each α ≠ 0,1 in F_{2^n} with β = β₁(α):
#     apn  ← is_quadratic_apn(butterfly_closed_lut(n, i, α, β₁))
#     rtc  ← refined_trace_cond(n, i, α)
#             = ∀ t ∉ {0,1,D}: Tr(F_D(t)^τ) = 1
#               where F_D(t) = (t + t^{2^i+1}) / (t + D), D = 1/(1+α²)
#     assert apn == rtc
# VBF API used: is_quadratic_apn, butterfly_closed_lut (helpers),
#               beta_pair (helpers), refined_trace_cond (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition5_build(n, i; modulus) -> Vector{NamedTuple}

For each α ≠ 0,1, verify Prop 5: V_{α,β₁} is APN ↔ refined_trace_cond(α).
Returns one entry per α: (alpha, b1, apn, rtc, equiv).
"""
function proposition5_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    results = NamedTuple[]
    for alpha in 1:(1 << n) - 1
        alpha == 1 && continue   # α=1 verified not APN in proposition3.jl (alpha1_build)
        b1, _ = beta_pair(n, i, alpha; modulus)
        F     = butterfly_closed_lut(n, i, alpha, b1; modulus)
        apn   = is_quadratic_apn(F)
        rtc   = refined_trace_cond(n, i, alpha; modulus)
        push!(results, (; alpha, b1, apn, rtc, equiv = apn == rtc))
    end
    results
end

function proposition5_report(io::IO = stdout;
                             cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Proposition 5 — Refined Trace Condition ↔ APN", io)
    for (n, i) in cases
        res    = proposition5_build(n, i)
        all_eq = all(r.equiv for r in res)
        n_apn  = count(r.apn for r in res)
        print_check(io,
            "n=$n i=$i: apn(V_{α,β₁}) ↔ refined_trace_cond(α) ($(n_apn) APN α)",
            all_eq)
    end
    print_kv(io, "completeness",
             "exhaustive over F_{2^n}, all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition5_report()
end
