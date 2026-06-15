# Implements Observation 1 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — A New Family of APN Quadrinomials (Observation 1)
#
# Pseudocode:
#   1. Build C_3(x) = x^3 + β·x^36 + β²·x^96 + x^129 over GF(2^10)  (i=3, k=2)
#   2. Build C_7(x) = x^3 + β·x^129 + β²·x^96 + x^36 over GF(2^10)  (i=7, k=0)
#   3. Verify differential_uniformity = 2 for each
#   4. Report EA-mugshot comparison (different mugshots → not EA-equivalent)
# VBF API used: build_ci_sbox, differential_uniformity, apn_ea_mugshot

include(joinpath(@__DIR__, "helpers.jl"))

"""
    build_c3_apn() -> SBox{10}

C_3(x) = x^3 + β·x^36 + β²·x^96 + x^129 over GF(2^10).
Instance of F13 with i=3, k=2, (a,b,c) = (β, β², 1). [Observation 1, paper eq.(1)]
"""
build_c3_apn() = build_ci_sbox(10, 3, 2)

"""
    build_c7_apn() -> SBox{10}

C_7(x) = x^3 + β·x^129 + β²·x^96 + x^36 over GF(2^10).
Instance of F13 with i=7, k=0, (a,b,c) = (β, β², 1). [Observation 1, paper eq.(1)]
"""
build_c7_apn() = build_ci_sbox(10, 7, 0)

function observation1_report(io::IO = stdout)
    print_section("Observation 1: C_3 and C_7 are APN over GF(2^10)", io)
    println(io, "  C_3(x) = x^3 + β·x^36 + β²·x^96 + x^129  (i=3, k=2)")
    println(io, "  C_7(x) = x^3 + β·x^129 + β²·x^96 + x^36  (i=7, k=0)")
    println(io, "  where β is the primitive element of GF(2^2) = α^341 in GF(2^10)")

    C3 = build_c3_apn()
    C7 = build_c7_apn()

    du3 = differential_uniformity(C3)
    du7 = differential_uniformity(C7)
    print_check("C_3 is APN (differential_uniformity = 2)", du3 == 2, io)
    print_check("C_7 is APN (differential_uniformity = 2)", du7 == 2, io)
    print_kv("C_3 differential_uniformity", du3, io)
    print_kv("C_7 differential_uniformity", du7, io)

    m3 = apn_ea_mugshot(C3)
    m7 = apn_ea_mugshot(C7)
    ea_ineq = m3 != m7
    print_check("C_3 ≠ C_7 (EA-mugshots differ → not EA-equivalent)", ea_ineq, io)

    println(io, "  NOTE: CCZ-inequivalence to all known APN functions requires Γ-rank")
    println(io, "        comparison (Table III). Γ-rank for n=10 needs Magma.")
    println(io, "        Paper: Γ(C_3)=166068, Γ(C_7)=166168 — loaded from Table III.")
end
