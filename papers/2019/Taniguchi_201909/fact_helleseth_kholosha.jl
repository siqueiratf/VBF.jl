# Implements Fact (Helleseth-Kholosha)
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 2 — Known examples and their Γ-ranks in F_{2^8}
#
# Pseudocode:
#   1. Count b∈GF(2ⁿ)* such that x^{2^m+1}+x+b has no root in GF(2ⁿ), gcd(m,n)=1
#   2. Formula (Theorem 1 of Helleseth-Kholosha 2008):
#      count = (2ⁿ+1)/3  if n odd
#      count = (2ⁿ-1)/3  if n even
# VBF API used: gf_pow, gf_mul, primitive_polynomial

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

"""
    count_rootless_b(n, m) -> Int

Count b∈GF(2ⁿ)* such that P(x)=x^{2^m+1}+x+b has no root in GF(2ⁿ).
"""
function count_rootless_b(n::Int, m::Int)
    gcd(m, n) == 1 || error("need gcd(m,n)=1")
    mod = primitive_polynomial(n)
    e = (1 << m) + 1
    count = 0
    for b = 1:(1<<n)-1
        has_root = false
        for x = 0:(1<<n)-1
            gf_pow(x, e, n; modulus=mod) ⊻ x ⊻ b == 0 && (has_root = true; break)
        end
        has_root || (count += 1)
    end
    count
end

"""
    helleseth_kholosha_formula(n) -> Int

Expected count from the Helleseth-Kholosha formula:
(2ⁿ+1)/3 for n odd, (2ⁿ-1)/3 for n even.
"""
helleseth_kholosha_formula(n::Int) = isodd(n) ? ((1<<n) + 1) ÷ 3 : ((1<<n) - 1) ÷ 3

function fact_helleseth_kholosha_verify(ns::Vector{Int} = [5, 6, 7])
    results = map(ns) do n
        m = 1  # gcd(1,n)=1 for all n≥2
        observed = count_rootless_b(n, m)
        expected = helleseth_kholosha_formula(n)
        (; n, m, observed, expected, ok=observed == expected)
    end
    results
end

function fact_helleseth_kholosha_report(io::IO = stdout)
    print_section(io, "Fact (Helleseth-Kholosha) — rootless-b count formula")

    results = fact_helleseth_kholosha_verify([5, 6, 7])
    for r in results
        parity = isodd(r.n) ? "odd" : "even"
        desc = "n=$(r.n) ($parity): count=$(r.observed) == formula=$(r.expected)"
        print_check(io, desc, r.ok)
    end
    print_kv(io, "formula", "(2ⁿ+1)/3 if n odd, (2ⁿ-1)/3 if n even")
    println(io, "  completeness: exhaustive over b∈GF(2ⁿ)* for n∈{5,6,7}")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    fact_helleseth_kholosha_report()
end
