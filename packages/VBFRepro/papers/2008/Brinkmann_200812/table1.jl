# Implements Table 1: canonical APN permutations in F(F₂⁵,F₂⁵) up to affine equivalence.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 4 — Affine Equivalence (Table 1, feeding Theorem 3)
#
# OCR reconstruction rule (Paper Issue 1)
# ---------------------------------------
# The tex header of Table 1 merges the first two columns into a single cell
# `01`, so the header carries 31 labels for 32 positions and every data row is
# short by exactly one value. The missing entry is s(1) = 1, re-inserted right
# after the leading 0: each row's 31 printed values are a permutation of
# {0,…,31} ∖ {1}, so 1 is the unique missing value, and position 1 is the only
# slot the merged header can account for. The reconstruction is self-checking:
# all five rows then become permutations of 0..31, all five are APN, and their
# algebraic degrees come out 4, 3, 3, 2, 2 — exactly the paper's degree column.
#
# Pseudocode:
#   1. table1_luts()          — the 5 reconstructed LUTs
#   2. table1_report(io)      — assert APN, permutation, degree, and the `Aff.` column
# VBF API used: SBox, differential_uniformity, algebraic_degree, is_permutation,
#               are_affine_equivalent, gf_monomial_lut, primitive_polynomial

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

"""
    table1_luts() -> Vector{SBox{5}}

The 5 canonical APN permutations of Table 1 (n=5), up to affine equivalence,
with the OCR-merged `s(1) = 1` re-inserted (see the file header).
"""
function table1_luts()
    rows = [
        [0, 1, 2, 4, 3, 6, 8, 16, 5, 10, 15, 27, 19, 29, 31, 20,
         7, 18, 25, 21, 12, 14, 24, 28, 26, 11, 23, 13, 30, 9, 17, 22],
        [0, 1, 2, 4, 3, 8, 13, 16, 5, 11, 21, 31, 23, 15, 19, 30,
         6, 28, 29, 9, 24, 27, 14, 18, 10, 17, 12, 26, 7, 25, 20, 22],
        [0, 1, 2, 4, 3, 8, 13, 16, 5, 17, 28, 27, 30, 14, 24, 10,
         6, 19, 11, 20, 31, 29, 12, 21, 18, 26, 15, 25, 7, 22, 23, 9],
        [0, 1, 2, 4, 3, 8, 16, 28, 5, 10, 25, 17, 18, 23, 31, 29,
         6, 20, 13, 24, 19, 11, 9, 22, 27, 7, 14, 21, 26, 12, 30, 15],
        [0, 1, 2, 4, 3, 8, 16, 28, 5, 10, 26, 18, 17, 20, 31, 29,
         6, 21, 24, 12, 22, 15, 25, 7, 14, 19, 13, 23, 9, 30, 27, 11],
    ]
    [SBox{5}(r) for r in rows]
end

"""
    table1_degrees() -> Vector{Int}

The paper's algebraic-degree column of Table 1.
"""
table1_degrees() = [4, 3, 3, 2, 2]

"""
    table1_affine_exponents() -> Vector{Int}

The paper's `Aff.` column of Table 1: the power function each row is affine
equivalent to.
"""
table1_affine_exponents() = [15, 11, 7, 3, 5]

"""
    table1_report(io)

Table 1 — the 5 canonical APN permutations for n=5. Asserts, for each row:
APN, permutation, the paper's algebraic degree, and affine equivalence to the
paper's `Aff.` power function.
"""
function table1_report(io::IO = stdout)
    print_section(io, "Table 1 — canonical APN permutations in F(F₂⁵,F₂⁵)")
    println(io, "  OCR reconstruction: the merged `01` header cell hides s(1)=1;")
    println(io, "  re-inserting it at position 1 makes every row a permutation of 0..31.")

    mod5 = primitive_polynomial(5)
    luts = table1_luts()
    degs = table1_degrees()
    exps = table1_affine_exponents()

    for (i, F) in enumerate(luts)
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        perm = is_permutation(F)
        P = SBox{5}(gf_monomial_lut(5, exps[i]; modulus = mod5))
        aff = are_affine_equivalent(F, P)
        print_check(io, "no. $i: APN (du=$du), permutation, deg=$deg (paper $(degs[i]))",
                    du == 2 && perm && deg == degs[i])
        print_check(io, "no. $i: affine equivalent to x^$(exps[i]) (paper `Aff.` column)", aff)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    table1_report()
end
