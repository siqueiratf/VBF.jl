# Implements Section 3.2, Table 4
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2, Table 4 — n=9: 8 CCZ-classes, 2 previously unknown (s₁, s₂)
#
# Pseudocode:
#   1. Build SBox for each of the 8 functions over GF(2⁹)
#   2. Verify differential_uniformity == 2 (APN)
#   3. For s₁,s₂: verify EA-mugshots differ from x³,x⁵,x¹⁷ (EA-inequivalence with known)
#   4. Verify s₁ and s₂ have distinct EA-mugshots from each other
# VBF API used: sbox_from_exponents, differential_uniformity, apn_ea_mugshot

include(joinpath(@__DIR__, "helpers.jl"))

# (exponents, label, is_new)
# s₁ = x^136+…+x^12 (9 terms), s₂ = x^288+…+x^34 (8 terms) — new over GF(2⁹)
const TABLE4_FUNCTIONS = [
    ([3],                                               "x³",       false),
    ([5],                                               "x⁵",       false),
    ([17],                                              "x¹⁷",      false),
    ([136,132,96,80,36,34,18,17,12],                    "s₁",       true),
    ([257,144,130,72,65,18,9],                          "f₅",       false),
    ([144,130,72,65,18,9,3],                            "f₆",       false),
    ([264,160,144,132,80,72,66,40,17],                  "f₇",       false),
    ([288,272,264,160,144,130,48,34],                   "s₂",       true),
]

const TABLE4_KNOWN_EXPS = [[3], [5], [17]]  # x³, x⁵, x¹⁷ for mugshot comparison

"""
    table4_verify() -> NamedTuple
"""
function table4_verify()
    n = 9
    checks = Tuple{String,Bool}[]

    # APN check for all 8 functions
    for (exps, label, _) in TABLE4_FUNCTIONS
        F = sbox_from_exponents(n, exps)
        ok = differential_uniformity(F) == 2
        push!(checks, ("$label: APN", ok))
    end

    # EA-mugshot checks for s₁ and s₂
    known_mugshots = Set(apn_ea_mugshot(sbox_from_exponents(n, e)) for e in TABLE4_KNOWN_EXPS)

    for (exps, label, is_new) in TABLE4_FUNCTIONS
        is_new || continue
        F = sbox_from_exponents(n, exps)
        mug = apn_ea_mugshot(F)
        ok_new = !(mug in known_mugshots)
        push!(checks, ("$label: EA-mugshot differs from x³,x⁵,x¹⁷", ok_new))
    end

    # s₁ and s₂ must be EA-inequivalent to each other
    new_fns = [sbox_from_exponents(n, exps) for (exps, _, is_new) in TABLE4_FUNCTIONS if is_new]
    if length(new_fns) == 2
        ok_distinct = apn_ea_mugshot(new_fns[1]) != apn_ea_mugshot(new_fns[2])
        push!(checks, ("s₁ and s₂ have distinct EA-mugshots", ok_distinct))
    end

    (; checks,
       note = "s₁,s₂ are CCZ-inequivalent to all known APN over GF(2⁹) per paper; " *
              "EA-mugshot test verifies EA-inequivalence with x³,x⁵,x¹⁷")
end

function table4_report(io::IO = stdout)
    print_section(io, "Table 4 — n=9 (8 CCZ-classes, 2 new: s₁ and s₂)")
    result = table4_verify()
    print_kv(io, "note", result.note)
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    table4_report()
end
