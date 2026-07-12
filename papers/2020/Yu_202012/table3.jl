# Implements Section 3.2, Table 3
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2, Table 3 — n=8: 7 CCZ-inequivalent classes (all equiv. to known Edel-Pott reps)
#
# Pseudocode:
#   1. Build SBox for each listed polynomial over GF(2⁸)
#   2. Verify differential_uniformity == 2 for each
#   3. Notable: x³+x⁶+x⁷² and x³+x⁶+x¹⁴⁴ are new short reps for two Edel-Pott classes
# VBF API used: sbox_from_exponents, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

# (exponents, label, is_new_representative)
const TABLE3_FUNCTIONS = [
    ([3],                   "x³",                       false),
    ([9],                   "x⁹",                       false),
    ([3, 6, 72],            "x³+x⁶+x⁷²",               true),  # new short rep for x³+Tr(x⁹)
    ([3, 6, 144],           "x³+x⁶+x¹⁴⁴",              true),  # new short rep for x⁹+Tr(x³)
    ([3, 6, 68, 80, 132, 160],  "x³+x⁶+x⁶⁸+x⁸⁰+x¹³²+x¹⁶⁰", false),
    ([3, 5, 18, 40, 66],    "x³+x⁵+x¹⁸+x⁴⁰+x⁶⁶",      false),
    ([3, 12, 40, 66, 130],  "x³+x¹²+x⁴⁰+x⁶⁶+x¹³⁰",    false),
]

"""
    table3_verify() -> NamedTuple
"""
function table3_verify()
    checks = Tuple{String,Bool}[]
    n = 8
    for (exps, label, _) in TABLE3_FUNCTIONS
        F = sbox_from_exponents(n, exps)
        ok = differential_uniformity(F) == 2
        push!(checks, ("$label: APN", ok))
    end
    new_reps = [label for (_, label, is_new) in TABLE3_FUNCTIONS if is_new]
    (; checks, new_short_representatives = new_reps,
       note = "All 7 are CCZ-equivalent to known Edel-Pott (2009) representatives")
end

function table3_report(io::IO = stdout)
    print_section(io, "Table 3 — n=8 (7 CCZ-classes, 2 new short representatives)")
    result = table3_verify()
    print_kv(io, "note", result.note)
    print_kv(io, "new short reps", join(result.new_short_representatives, ", "))
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    table3_report()
end
