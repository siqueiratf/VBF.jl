# Implements Appendix A — Complexities of the LE and AE algorithms (Table 2).
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: Appendix A (Table 2)
#
# Pseudocode:
#   Table 2 is pure arithmetic: each cell is the base-2 logarithm of a closed
#   form, rounded to the nearest integer.  Appendix A: "we use n^2 for the
#   complexity of the Gaussian elimination since n <= 32".
#     LE            : n^2 * 2^n
#     AE            : n^2 * 2^(2n)
#     AE (n-m = d)  : 2^n * n^2 * (2^d !)^(n / 2^d)     [eq. (9) with n^2 for n^3]
#   1. Evaluate each closed form exactly (BigInt / BigFloat logs).
#   2. Round log2 to the nearest integer and compare with the printed exponent.
# VBF API used: (none — arithmetic only)

include(joinpath(@__DIR__, "helpers.jl"))

const TABLE2_DIMS = [4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 32]

# Printed exponents, row by row, in the order of TABLE2_DIMS.
const TABLE2_LE = [8, 10, 11, 13, 14, 15, 17, 19, 24, 33, 42]
const TABLE2_AE = [12, 15, 17, 20, 22, 24, 27, 31, 40, 57, 74]
const TABLE2_AE_D1 = [10, 12, 14, 16, 18, 20, 22, 25, 32, 45, 58]
const TABLE2_AE_D2 = [13, 15, 18, 21, 23, 26, 28, 33, 42, 61, 79]
const TABLE2_AE_D3 = [16, 19, 23, 26, 29, 33, 36, 42, 55, 79, 103]

# log2 of the closed forms, in exact rational-exponent arithmetic where it
# matters (the (2^d!)^{n/2^d} factor has a fractional exponent).
le_log2(n::Int) = 2 * log2(big(n)) + n
ae_log2(n::Int) = 2 * log2(big(n)) + 2n
ae_nonbijective_log2(n::Int, d::Int) =
    n + 2 * log2(big(n)) + (big(n) / big(2)^d) * log2(factorial(big(2)^d))

table2_exponent(x) = round(Int, Float64(x))

"""
    table2_rows() -> Vector{Tuple{String, Function, Vector{Int}}}

The five body rows of Table 2: label, `n ↦ log2(cost)`, printed exponents.
"""
function table2_rows()
    [
        ("LE            : n²·2ⁿ", le_log2, TABLE2_LE),
        ("AE            : n²·2²ⁿ", ae_log2, TABLE2_AE),
        ("AE (n−m = 1)  : 2ⁿ·n²·(2!)^{n/2}", n -> ae_nonbijective_log2(n, 1), TABLE2_AE_D1),
        ("AE (n−m = 2)  : 2ⁿ·n²·(2²!)^{n/4}", n -> ae_nonbijective_log2(n, 2), TABLE2_AE_D2),
        ("AE (n−m = 3)  : 2ⁿ·n²·(2³!)^{n/8}", n -> ae_nonbijective_log2(n, 3), TABLE2_AE_D3),
    ]
end

function table2_report(io::IO = stdout)
    print_section(io, "Appendix A — Complexities of the LE and AE algorithms (Table 2)")
    print_kv(io, "dimensions n", join(TABLE2_DIMS, ", "))

    all_ok = true
    for (label, f, printed) in table2_rows()
        got = [table2_exponent(f(n)) for n in TABLE2_DIMS]
        ok = got == printed
        print_check(io, "$label → 2^[$(join(got, ", "))]", ok)
        ok || print_kv(io, "  paper", "2^[$(join(printed, ", "))]")
        all_ok &= ok
    end

    print_kv(
        io,
        "reading note",
        "the source's AE (n−m=3) row merges its label into the first body cell " *
        "and trails an empty one; the 11 values still align with the 11 dimensions",
    )
    print_kv(io, "completeness", "exhaustive (5 rows × 11 columns = 55 cells)")

    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    ok = table2_report()
    exit(ok ? 0 : 1)
end
