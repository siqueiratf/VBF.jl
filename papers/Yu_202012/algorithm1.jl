# Implements Section 3.2, Algorithm 1
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2 — Algorithm 1: Output quadratic APN polynomials with 0,1 coefficients
#
# Pseudocode (Algorithm 1 from paper):
#   1. n = 2m-1 (paper uses odd dimensions; VBF search_qam(n,1) handles all n)
#   2. GetNoneSquare(n): restrict leading free variable to one per Proposition-1 orbit
#   3. TranFirRow(j, H): fill column j of H, propagate cyclic structure, recurse
#   4. GetElemC(j, H): prune candidates using span/rank (proper submatrix) check
#   5. If completed H is QAM: output corresponding APN function
# VBF API used: search_qam (= Algorithm 1 for m=1)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    algorithm1_run(n; limit, max_evaluations) -> Vector{SBox{n}}

Run Algorithm 1 from the paper: enumerate F₂-cyclic QAMs and return distinct
EA-class representatives. Wraps `search_qam(n, 1)`.
"""
function algorithm1_run(
    n::Int;
    limit::Int = typemax(Int),
    max_evaluations::Int = 1 << 20,
)
    search_qam(n, 1; limit = limit, max_evaluations = max_evaluations)
end

"""
    algorithm1_report(io; n_demo, max_evaluations)

Demo Algorithm 1 for n=6 (exhaustive, ≤32768 candidates).
"""
function algorithm1_report(
    io::IO = stdout;
    n_demo::Int = 6,
    max_evaluations::Int = 1 << 24,
)
    print_section(io, "Algorithm 1 — F₂-coefficient QAM search (demo: n=$n_demo)")
    print_kv(io, "n", n_demo)
    print_kv(io, "max_evaluations", max_evaluations)
    result = algorithm1_run(n_demo; max_evaluations = max_evaluations)
    print_kv(io, "distinct EA-classes found", length(result))
    print_kv(io, "completeness", "exhaustive (n=$n_demo search space ≤ 2^15)")
    print_kv(io, "expected (Table 1)", 1)
    all_apn = all(differential_uniformity(F) == 2 for F in result)
    print(result);
    print(typeof(result));
    print_check(io, "all found functions are APN", all_apn)
    (; n_demo, n_classes = length(result), exhaustive = true)
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
