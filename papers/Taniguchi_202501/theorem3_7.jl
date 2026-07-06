# Implements Theorem 3.7: exponential sum criterion
# Paper: Taniguchi et al. (2025), "Changing APN functions on affine subspaces
#        of small codimensions"
# Section: 3.2 — A necessary and sufficient condition for the APN-ness of
#          G(x) = x^3 + Tr(x)L(x)
#
# Pseudocode (Eq. 3.1):
#   G(x) = x^3 + Tr(x)L(x) is APN iff:
#     Σ_{x∈F\{0,1}} (-1)^{Tr(x²·L(x²+x)/(x²+x)³)}
#     - ½·Σ_{x∈F\{0,1}} (-1)^{Tr(L(x²+x)/(x²+x)³)}
#     = 2^{n-1} - 1
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace

include(joinpath(@__DIR__, "helpers.jl"))

"""
Evaluate the exponential sum condition (Eq. 3.1) for G(x) = x^3 + Tr(x)L(x).
Returns (lhs_times_2, rhs_times_2, holds).
"""
function theorem3_7_check(L_coeffs::Vector{Int}, n::Int, mod::Int)
    N = 1 << n
    rhs = (1 << (n-1)) - 1

    sum1 = 0
    sum2 = 0

    for x in 2:N-1
        x2 = gf_mul(x, x, n; modulus=mod)
        x2_plus_x = x2 ⊻ x
        x2_plus_x == 0 && continue

        cube = gf_pow(x2_plus_x, 3, n; modulus=mod)
        cube_inv = gf_inv(cube, n; modulus=mod)
        L_val = linearized_poly_eval(L_coeffs, x2_plus_x, n, mod)
        ratio = gf_mul(L_val, cube_inv, n; modulus=mod)

        tr2 = gf_trace(ratio, n; modulus=mod)
        sum2 += (tr2 == 0) ? 1 : -1

        x2_ratio = gf_mul(x2, ratio, n; modulus=mod)
        tr1 = gf_trace(x2_ratio, n; modulus=mod)
        sum1 += (tr1 == 0) ? 1 : -1
    end

    lhs_times_2 = 2 * sum1 - sum2
    rhs_times_2 = 2 * rhs
    (lhs_times_2=lhs_times_2, rhs_times_2=rhs_times_2, holds=(lhs_times_2 == rhs_times_2))
end

function theorem3_7_report(io::IO = stdout)
    n = 6
    mod = PAPER_MODULUS_6
    print_section("Theorem 3.7: exponential sum criterion (Eq. 3.1)", io)

    entries = table3_1_coefficients(n, mod)

    all_hold = true
    for entry in entries
        r = theorem3_7_check(entry.coeffs, n, mod)
        all_hold &= r.holds
        status = r.holds ? "HOLDS" : "FAILS"
        print_kv(io, "$(entry.name) ($(entry.dillon))", "$status  2·LHS=$(r.lhs_times_2)  2·RHS=$(r.rhs_times_2)")
    end

    print_check(io, "Eq.(3.1) holds for all 13 Table 3.1 entries", all_hold)
    (; all_hold)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_7_report()
end
