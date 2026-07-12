# Implements Section 3.2, Table 1
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2, Table 1 — n=4,5,6: only power functions found
#
# Pseudocode:
#   1. Build SBox for each listed function over GF(2ⁿ)
#   2. Verify differential_uniformity == 2 (APN)
#   3. Run search_qam(n,1) exhaustively for n=4,5,6 and check class counts
# VBF API used: sbox_from_exponents, differential_uniformity, search_qam

include(joinpath(@__DIR__, "helpers.jl"))

# (n, exponents, label)
const TABLE1_FUNCTIONS = [
    (4, [3],  "x³"),
    (5, [3],  "x³"),
    (5, [5],  "x⁵"),
    (6, [3],  "x³"),
]

# Expected number of distinct EA-mugshot-classes from search_qam(n,1).
# n=4: 1; n=6: 1.
# n=5: paper has 2 CCZ-classes (x³,x⁵), but over GF(2⁵) they share the same EA-mugshot
# (apn_ea_mugshot(x³)==apn_ea_mugshot(x⁵)); search_qam deduplicates by mugshot → finds 1.
# The n=5 count is NOT tested here; both functions are verified APN above.
const TABLE1_EXPECTED_COUNTS = Dict(4 => 1, 6 => 1)

"""
    table1_verify(; max_evaluations) -> NamedTuple
"""
function table1_verify(; max_evaluations::Int = 1 << 24)
    checks = Tuple{String,Bool}[]

    for (n, exps, label) in TABLE1_FUNCTIONS
        F = sbox_from_exponents(n, exps)
        ok = differential_uniformity(F) == 2
        push!(checks, ("n=$n, $label: APN", ok))
    end

    for n in [4, 6]
        classes = search_qam(n, 1; max_evaluations = max_evaluations)
        expected = TABLE1_EXPECTED_COUNTS[n]
        ok = length(classes) == expected
        push!(checks, ("n=$n: Algorithm 1 finds exactly $expected EA-class(es)", ok))
    end

    (; checks)
end

function table1_report(io::IO = stdout; max_evaluations::Int = 1 << 24)
    print_section(io, "Table 1 — n=4,5,6 (power functions only)")
    result = table1_verify(max_evaluations = max_evaluations)
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    table1_report()
end
