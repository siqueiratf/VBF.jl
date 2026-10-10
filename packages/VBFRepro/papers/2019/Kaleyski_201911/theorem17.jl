# Implements Section 4, Theorem 17 — characterization of APN two-point swaps.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Main result (Theorem 17, Eq. 29)
#
# Pseudocode:
#   1. Given APN F with F(0)=0, F(1)=1 over F_{2^n}
#   2. Let G = F with F(0) and F(1) swapped
#   3. G is APN  ⟺  6·Δ_F(1,0) = S1(F) + S2(F)
#      where S1(F) = Σ_y Δ_F(y, F(y)⊕1)
#            S2(F) = Σ_y Δ_F(y⊕1, F(y))
#   4. Both directions are exercised: n=4 is the POSITIVE case (condition holds and
#      G is APN); n=5..8 are negative (condition fails and G is not APN). Each row
#      is cross-checked against ground truth differential_uniformity(G) == 2, so a
#      hardcoded `holds = false` cannot pass (README R5).
# VBF API used: SBox, ddt, differential_uniformity
# Catalog API used: load_apn_function

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    theorem17_demo(; io::IO = stdout) -> NamedTuple

Demonstrate Theorem 17 on Gold x^3 for n=4..8. Gold x^3 satisfies F(0)=0, F(1)=1
automatically, so it is already normalised.

The biconditional is checked against ground truth for every row: build
`G = swap(F, 0, 1)` and compare `differential_uniformity(G) == 2` with Eq. 29.

n=4 is the discriminating positive case — S1=S2=6, 6·Δ(1,0)=12, the condition
HOLDS and G is APN (cf. Observation 27). For n ≥ 5 the condition fails and G is
not APN, as Conjecture 22 predicts.
"""
function theorem17_demo(; io::IO = stdout)
    print_section("Theorem 17 — characterization (Eq. 29)", io)
    println(io, "  Condition: G is APN  ⟺  6·Δ_F(1,0) = S1(F) + S2(F)")
    println(io, "  where G = F with F(0) and F(1) swapped, and F(0)=0, F(1)=1.")
    println(io)
    println(io, "  n   function        S1      S2   6·Δ(1,0)  S1+S2  Eq.29  G APN?")
    println(io, "  " * "─"^68)

    results = NamedTuple[]
    for (n, name) in [(4, "n4_Gold_x3"), (5, "n5_Gold_x3"), (6, "n6_Gold_x3"),
                      (7, "n7_Gold_x3"), (8, "n8_Gold_x3")]
        s = load_apn_function(name)
        @assert Int(s.lut[1]) == 0 && Int(s.lut[2]) == 1 "$name is not normalised"
        r = theorem17_holds(s)
        lhs = 6 * r.dd10
        g_apn = swap_is_apn(s, 0, 1)          # ground truth, independent of Eq. 29
        @assert r.holds == g_apn "Theorem 17 biconditional violated for $name"
        @assert r.holds == (n == 4) "Unexpected Eq. 29 verdict for $name (n=$n)"
        println(io, "  $n   $(rpad(name,14)) $(lpad(r.s1,5))  $(lpad(r.s2,5))  " *
                    "$(lpad(lhs,9))  $(lpad(r.s1+r.s2,5))  " *
                    "$(rpad(r.holds ? "YES" : "no",5))  $(g_apn ? "YES" : "no")")
        push!(results, (; n, name, s1 = r.s1, s2 = r.s2, dd10 = r.dd10,
                        holds = r.holds, g_apn))
    end

    biconditional_ok = all(r.holds == r.g_apn for r in results)
    all_fail = all(!r.holds for r in results if r.n >= 5)
    positive_case = any(r.holds && r.g_apn for r in results)
    println(io)
    print_check("Theorem 17 biconditional matches differential_uniformity(G) in all rows",
                biconditional_ok, io)
    print_check("Positive case exercised (n=4: Eq. 29 holds and G is APN)", positive_case, io)
    print_check("Theorem 17 condition fails for all Gold x^3 n=5..8", all_fail, io)
    print_kv("interpretation",
        "no two-point swap of x^3 is APN for n=5..8 (supports Conjecture 22); " *
        "for n=4 it is (Observation 27)", io)

    return (; results, all_fail, biconditional_ok, positive_case)
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem17_demo()
end
