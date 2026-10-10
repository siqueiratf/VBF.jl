# Implements Section 3.2, Proposition 1
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2 — Conditions on QAMs
#
# Pseudocode:
#   1. Take a QAM H corresponding to a F₂-coefficient function F₁
#   2. Build H' by squaring every entry: H'[i,j] = H[i,j]² in GF(2ⁿ)
#   3. Verify H' is also a QAM (Proposition 1)
#   4. Verify the functions F₁, F₂ (corresponding to H, H') are EA-equivalent
#      via apn_ea_mugshot comparison
# VBF API used: quadratic_apn_matrix, qam_to_sbox, is_qam, gf_pow, primitive_polynomial,
#   apn_ea_mugshot, sbox_from_exponents

include(joinpath(@__DIR__, "helpers.jl"))

"""
    frobenius_squared_qam(M, n) -> Matrix{Int}

Build H' from H: H'[i,j] = H[i,j]² in GF(2ⁿ) for all i,j.
Proposition 1: if H is a QAM, so is H'.
"""
function frobenius_squared_qam(M::Matrix{Int}, n::Int)
    mod = primitive_polynomial(n)
    [gf_pow(M[i, j], 2, n; modulus = mod) for i in 1:n, j in 1:n]
end

"""
    proposition1_examples() -> NamedTuple

Verify Proposition 1 on examples from the paper tables.
"""
function proposition1_examples()
    checks = Tuple{String,Bool}[]

    for (label, n, exps) in [
        ("x³, n=6", 6, [3]),
        ("x³+x⁹+x¹⁸+x⁶⁶, n=7", 7, [3, 9, 18, 66]),
        ("x³+x⁶+x⁷², n=8", 8, [3, 6, 72]),
        ("x³, n=9", 9, [3]),
    ]
        F1 = sbox_from_exponents(n, exps)
        M1 = quadratic_apn_matrix(F1)
        M2 = frobenius_squared_qam(M1, n)
        F2 = qam_to_sbox(M2)

        # H' must be a QAM
        ok_qam = is_qam(M2)
        push!(checks, ("$label: H' is QAM", ok_qam))

        # F₁ and F₂ must be EA-equivalent (same mugshot)
        ok_ea = apn_ea_mugshot(F1) == apn_ea_mugshot(F2)
        push!(checks, ("$label: F₁ and F₂ EA-equivalent", ok_ea))
    end

    (; checks)
end

function proposition1_report(io::IO = stdout)
    print_section(io, "Proposition 1 — Frobenius-squared QAM gives EA-equivalent function")
    result = proposition1_examples()
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition1_report()
end
