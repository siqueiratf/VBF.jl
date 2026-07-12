# Implements Section 3.1, Theorem 2
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.1 — Correspondence between quadratic functions with coefficients in F₂ and QAMs
#
# Theorem 2 states: H = Mα^t C_F Mα (normal-basis form) satisfies H[u+1,v+1]=H[u,v]² iff
# the polynomial coefficients c_{i,t} ∈ F₂. The VBF API encodes this via qam_from_cyclic(n,1,·):
# the matrix it builds satisfies the cyclic property by construction (using Frobenius shifts),
# and search_qam(n,1) recovers exactly the F₂-coefficient APN functions.
#
# Pseudocode:
#   1. Show qam_from_cyclic(n,1,v) output always has F₂-cyclic structure
#   2. Show F₂-coefficient functions are in the image of search_qam(n,1) (same EA-class)
#   3. Verify the recovered cyclic QAMs produce valid APN functions
# VBF API used: qam_from_cyclic, qam_cyclic_orbits, is_qam, qam_to_sbox,
#   search_qam, apn_ea_mugshot, sbox_from_exponents, has_f2_cyclic_structure

include(joinpath(@__DIR__, "helpers.jl"))

"""
    cyclic_qam_has_structure(n, m, values) -> Bool

Verify that the matrix built by qam_from_cyclic(n, m, values) satisfies the
F₂-cyclic property: M[(i+m)%n+1, (j+m)%n+1] == M[i+1,j+1]^(2^m) in GF(2ⁿ).
This holds by construction (qam_from_cyclic applies Frobenius shifts).
"""
function cyclic_qam_has_structure(n::Int, m::Int, values::Vector{Int})
    M = qam_from_cyclic(n, m, values)
    has_f2_cyclic_structure(M, n)
end

"""
    theorem2_examples() -> NamedTuple

Verify Theorem 2 on concrete examples.
"""
function theorem2_examples()
    checks = Tuple{String,Bool}[]

    # 1. qam_from_cyclic(n,1,·) always produces an F₂-cyclic matrix
    # val=1 works for any subfield: gf_pow(1, 2, n) = 1 in GF(2ⁿ).
    # n=6,m=1: 3 orbits; n=7,m=1: 3 orbits
    for (n, vals) in [(6, [1, 1, 1]), (7, [1, 1, 1])]
        M = qam_from_cyclic(n, 1, vals)
        ok = has_f2_cyclic_structure(M, n)
        push!(checks, ("n=$n: qam_from_cyclic output has F₂-cyclic structure", ok))
    end

    # 2. search_qam(n,1) recovers x³ (a known F₂-coefficient APN function)
    for n in [6, 7]
        gold = sbox_from_exponents(n, [3])
        gold_mug = apn_ea_mugshot(gold)
        classes = search_qam(n, 1; max_evaluations = 1 << 24)
        found = any(apn_ea_mugshot(F) == gold_mug for F in classes)
        push!(checks, ("n=$n: search_qam(n,1) finds EA-class of x³", found))
    end

    # 3. Every matrix produced by qam_from_cyclic(n,1) that is a QAM yields an APN function
    n = 6
    classes = search_qam(n, 1; max_evaluations = 1 << 24)
    all_apn = all(differential_uniformity(F) == 2 for F in classes)
    push!(checks, ("n=$n: all cyclic QAM functions are APN", all_apn))

    (; checks)
end

function theorem2_report(io::IO = stdout)
    print_section(io, "Theorem 2 — F₂-cyclic structure of QAMs")
    result = theorem2_examples()
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem2_report()
end
