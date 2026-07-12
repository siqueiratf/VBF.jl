# Implements Proposition 1 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Proposition 1 (system E_i characterises APN-ness of C_i)
#
# Pseudocode:
#   For a given n = 2m and i:
#   1. Check system E_i (Eq. 2) for all a ∈ GF(2^n)*, x ∉ GF(2)
#   2. Verify: E_i trivial ↔ C_i(x) is APN
#   Claim: C_i is APN iff for all a≠0, x∉GF(2): NOT (a^3(x^2+x) ∈ β·GF(2^m)
#          AND a^(2^i+1)(x^(2^i)+x) ∈ β·GF(2^m))
# VBF API used: system_Ei_trivial, build_ci_sbox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))
using Printf

"""
    check_proposition1(n; i_vals) -> NamedTuple

For each i in `i_vals`, verifies that system E_i is trivial ↔ C_i is APN.
Returns a table of (i, ei_trivial, is_apn, consistent) entries.
"""
function check_proposition1(n::Int; i_vals = 1:n-1)
    m = n ÷ 2
    results = NamedTuple{(:i, :ei_trivial, :is_apn, :consistent), Tuple{Int,Bool,Bool,Bool}}[]
    for i in i_vals
        ei_ok = system_Ei_trivial(n, i)
        F  = build_ci_sbox(n, i)
        apn = differential_uniformity(F) == 2
        push!(results, (; i, ei_trivial=ei_ok, is_apn=apn, consistent=(ei_ok == apn)))
    end
    results
end

function proposition1_report(io::IO = stdout)
    print_section("Proposition 1: system E_i ↔ APN criterion (n=10)", io)
    println(io, "  For each i=1..9 over GF(2^10): E_i trivial iff C_i(x) is APN.")

    results = check_proposition1(10)
    println(io, "  i  E_i-trivial  APN  consistent")
    for r in results
        println(io, @sprintf("  %-2d  %-11s  %-5s  %s",
            r.i,
            r.ei_trivial ? "yes" : "no",
            r.is_apn ? "yes" : "no",
            r.consistent ? "[ OK ]" : "[FAIL]"))
    end
    all_ok = all(r.consistent for r in results)
    print_check("Proposition 1 holds for all i ∈ 1..9 over GF(2^10)", all_ok, io)
end
