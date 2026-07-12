# Implements Section 3.2, Table 2
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2, Table 2 — n=7: 15 CCZ-inequivalent classes (3 monomials + 12 polynomials)
#
# Pseudocode:
#   1. Build SBox for each listed polynomial over GF(2⁷)
#   2. Verify differential_uniformity == 2 for each
# VBF API used: sbox_from_exponents, differential_uniformity
#
# NOTE: The TeX source contains a duplicate entry — x³+x⁹+x¹⁸+x⁶⁶ appears at
# positions 4 and 10. We verify the 14 distinct functions here and note this issue.

include(joinpath(@__DIR__, "helpers.jl"))

# (exponents, label)  — n=7 throughout
# Duplicate at original position 10 omitted; 14 distinct functions listed.
const TABLE2_FUNCTIONS = [
    ([3],                       "x³"),
    ([9],                       "x⁹"),
    ([5],                       "x⁵"),
    ([3, 9, 18, 66],            "x³+x⁹+x¹⁸+x⁶⁶"),
    ([5, 18, 34],               "x⁵+x¹⁸+x³⁴"),
    ([3, 6, 20],                "x³+x⁶+x²⁰"),
    ([3, 17, 20, 34, 66],       "x³+x¹⁷+x²⁰+x³⁴+x⁶⁶"),
    ([3, 17, 33, 34],           "x³+x¹⁷+x³³+x³⁴"),
    ([3, 5, 10, 33, 34],        "x³+x⁵+x¹⁰+x³³+x³⁴"),
    # position 10 in TeX = duplicate of position 4; omitted
    ([3, 12, 17, 33],           "x³+x¹²+x¹⁷+x³³"),
    ([3, 20, 34, 66],           "x³+x²⁰+x³⁴+x⁶⁶"),
    ([3, 12, 40, 72],           "x³+x¹²+x⁴⁰+x⁷²"),
    ([3, 6, 34, 40, 72],        "x³+x⁶+x³⁴+x⁴⁰+x⁷²"),
    ([3, 5, 6, 12, 33, 34],     "x³+x⁵+x⁶+x¹²+x³³+x³⁴"),
]

"""
    table2_verify() -> NamedTuple

Verify all 14 distinct n=7 functions from the paper are APN.
Reports the TeX duplicate issue.
"""
function table2_verify()
    checks = Tuple{String,Bool}[]
    n = 7
    for (exps, label) in TABLE2_FUNCTIONS
        F = sbox_from_exponents(n, exps)
        ok = differential_uniformity(F) == 2
        push!(checks, ("$label: APN", ok))
    end
    (; checks, n_verified = length(TABLE2_FUNCTIONS),
       TeX_duplicate_note = "TeX position 10 = duplicate of position 4 (x³+x⁹+x¹⁸+x⁶⁶); 14 distinct functions verified")
end

function table2_report(io::IO = stdout)
    print_section(io, "Table 2 — n=7 (15 CCZ-classes; 14 verified from TeX)")
    result = table2_verify()
    print_kv(io, "TeX note", result.TeX_duplicate_note)
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "verified", "$(result.n_verified)/15 distinct functions from TeX")
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    table2_report()
end
