# Implements Section 4, Theorem 17 — characterization of APN two-point swaps.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Main result (Theorem 17, Eq. 29)
#
# Pseudocode:
#   1. Given APN F with F(0)=0, F(1)=1 over F_{2^n}
#   2. Let G = F with F(0) and F(1) swapped
#   3. G is APN  ⟺  6·DD_F(1,0) = S1(F) + S2(F)
#      where S1(F) = Σ_y DD_F(y, F(y)⊕1)
#            S2(F) = Σ_y DD_F(y⊕1, F(y))
# VBF API used: SBox, load_apn_function, ddt, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    theorem17_demo(; io::IO = stdout) -> NamedTuple

Demonstrate Theorem 17 on Gold x^3 for n=5..8.
Gold x^3 satisfies F(0)=0, F(1)=1 automatically.
The condition 6·DD_F(1,0) = S1+S2 would need to hold for the
two-point swap to be APN.  Per the paper, it fails for all n≥5.
"""
function theorem17_demo(; io::IO = stdout)
    print_section("Theorem 17 — characterization (Eq. 29)", io)
    println(io, "  Condition: G is APN  ⟺  6·DD_F(1,0) = S1(F) + S2(F)")
    println(io, "  where G = F with F(0) and F(1) swapped, and F(0)=0, F(1)=1.")
    println(io)
    println(io, "  n   function     S1      S2   6·DD(1,0)  S1+S2  holds?")
    println(io, "  " * "─"^60)

    results = NamedTuple[]
    for (n, name) in [(5,"n5_Gold_x3"), (6,"n6_Gold_x3"), (7,"n7_Gold_x3"), (8,"n8_Gold_x3")]
        s = load_apn_function(name)
        r = theorem17_holds(s)
        lhs = 6 * r.dd10
        @assert !r.holds  "Expected Theorem 17 condition to FAIL for $name (n=$n≥5)"
        println(io, "  $n   $(rpad(name,14)) $(lpad(r.s1,5))  $(lpad(r.s2,5))  " *
                    "$(lpad(lhs,9))  $(lpad(r.s1+r.s2,5))  $(r.holds ? "YES" : "no")")
        push!(results, (; n, name, s1=r.s1, s2=r.s2, dd10=r.dd10, holds=r.holds))
    end

    all_fail = all(!r.holds for r in results)
    println(io)
    print_check("Theorem 17 condition fails for all Gold x^3 n=5..8", all_fail, io)
    print_kv("interpretation",
        "no two-point swap of x^3 is APN for n=5..8 (supports Conjecture 22)", io)

    return (; results, all_fail)
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem17_demo()
end
