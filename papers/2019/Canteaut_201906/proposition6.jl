# Implements Proposition 6 + Theorem 1 — Refined trace condition ⟹ n ≤ 3
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 5 — The Necessary Condition Needs a Small Branch Size
#
# Pseudocode:
#   Prop 6 (counting argument): if refined_trace_cond holds then n ≤ 3.
#   Numerical verification for n = 5 (odd, > 3):
#     For each α ≠ 0,1 in F_{2^5}:
#       assert NOT refined_trace_cond(5, i, α)
#     For each (α,β) with α≠0,1 and β ∈ {β₁,β₂}:
#       assert V_{α,β} is NOT APN
#   For n = 3: confirm APN butterflies exist (6 pairs).
#
# Theorem 1 follows: APN generalised butterfly ⟹ n = 3 (i.e. operates on 6 bits).
# VBF API used: is_quadratic_apn, differential_uniformity,
#               butterfly_closed_lut (helpers), beta_pair (helpers), refined_trace_cond (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition6_build(n, i; modulus) -> NamedTuple

For branch size n, verify no APN butterfly exists when n > 3.
Checks both: refined_trace_cond is never satisfied, and V_{α,β₁/β₂} is never APN.
Returns (; n, i, rtc_count, apn_pairs).
"""
function proposition6_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    rtc_count = 0
    apn_pairs = Tuple{Int,Int}[]
    for alpha in 1:(1 << n) - 1
        alpha == 1 && continue   # α=1 verified not APN in proposition3.jl (alpha1_build)
        refined_trace_cond(n, i, alpha; modulus) && (rtc_count += 1)
        b1, b2 = beta_pair(n, i, alpha; modulus)
        for beta in (b1, b2)
            F = butterfly_closed_lut(n, i, alpha, beta; modulus)
            is_quadratic_apn(F) && push!(apn_pairs, (alpha, beta))
        end
    end
    (; n, i, rtc_count, apn_pairs)
end

"""
    theorem1_build(i; moduli) -> NamedTuple

Verify Theorem 1: APN closed butterfly ⟹ n = 3.
Tests n ∈ {3, 5} (both odd); n=7 omitted (2^{14} LUT too large for fast test).
"""
function theorem1_build(i::Int = 1;
                        n_values  = [3, 5],
                        moduli = Dict(n => primitive_polynomial(n) for n in n_values))
    results = NamedTuple[]
    for n in n_values
        r = proposition6_build(n, i; modulus = moduli[n])
        push!(results, r)
    end
    results
end

function proposition6_report(io::IO = stdout;
                             i_n3 = (1, 2), i_n5 = (1, 2, 3, 4))
    print_section("Proposition 6 + Theorem 1 — APN butterfly ⟹ n = 3", io)
    for i in i_n3
        res3 = proposition6_build(3, i)
        print_check(io,
            "n=3 i=$i: APN butterflies exist ($(length(res3.apn_pairs)) pairs)",
            !isempty(res3.apn_pairs))
    end
    for i in i_n5
        res5 = proposition6_build(5, i)
        print_check(io,
            "n=5 i=$i: no APN butterfly, rtc never true (Prop 6 + Thm 1)",
            isempty(res5.apn_pairs) && res5.rtc_count == 0)
    end
    print_kv(io, "completeness",
             "exhaustive β∈{β₁,β₂} sweep, all i with gcd(i,n)=1 (n=3: i∈$(collect(i_n3)); n=5: i∈$(collect(i_n5)))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition6_report()
end
