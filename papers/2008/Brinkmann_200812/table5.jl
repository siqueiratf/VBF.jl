# Implements Table 5: the first 14 canonical APN functions in F(F₂⁶,F₂⁶) up to
# CCZ equivalence, including the paper's new class (row 13).
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 7 — Dimension 6
#
# OCR reconstruction rule (Paper Issue 3)
# ---------------------------------------
# Table 5 is split across two `tabular` environments: the first gives the
# 33-value prefix s(0..32) that *all 14 functions share*, the second gives the
# 31-value tail s(33..63) of each function. Concatenating prefix ++ tail_i gives
# a 64-value LUT — the rows only read as truncated because of the split. The
# reconstruction is self-checking: all 14 concatenations are APN and all 14
# Γ-ranks reproduce the paper's Γ-rank row exactly.
#
# Pseudocode:
#   1. table5_prefix()  — the shared 33-value prefix
#   2. table5_luts()    — the 14 reconstructed n=6 LUTs
#   3. table5_gamma_ranks() — the paper's Γ-rank row
# VBF API used: SBox, differential_uniformity, algebraic_degree, gamma_rank

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

"""
    table5_prefix() -> Vector{Int}

The 33 leading values s(0), …, s(32) shared by all 14 functions of Table 5.
"""
table5_prefix() = [
    0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 10, 13,
    0, 8, 16, 25, 5, 15, 17, 26, 32, 44, 54, 59, 45, 35, 63, 48, 0,
]

"""
    table5_tails() -> Vector{Vector{Int}}

The 14 tails s(33), …, s(63) of Table 5, one per CCZ class.
"""
function table5_tails()
    [
        [16, 24, 9, 32, 50, 60, 47, 41, 61, 55, 34, 1, 23, 27, 12, 15,
         23, 7, 30, 42, 48, 38, 61, 6, 26, 8, 21, 43, 53, 33, 62],
        [16, 24, 9, 37, 55, 57, 42, 5, 17, 27, 14, 40, 62, 50, 37, 3,
         27, 11, 18, 35, 57, 47, 52, 38, 58, 40, 53, 14, 16, 4, 27],
        [16, 24, 9, 37, 55, 57, 42, 5, 17, 27, 14, 40, 62, 50, 37, 27,
         3, 19, 10, 59, 33, 55, 44, 62, 34, 48, 45, 22, 8, 28, 3],
        [16, 26, 11, 32, 50, 62, 45, 33, 53, 61, 40, 9, 31, 17, 6, 35,
         59, 41, 48, 6, 28, 8, 19, 34, 62, 46, 51, 15, 17, 7, 24],
        [16, 26, 11, 32, 50, 62, 45, 43, 63, 55, 34, 3, 21, 27, 12, 15,
         23, 5, 28, 42, 48, 36, 63, 4, 24, 8, 21, 41, 55, 33, 62],
        [16, 26, 11, 33, 51, 63, 44, 51, 39, 47, 58, 26, 12, 2, 21, 39,
         63, 45, 52, 3, 25, 13, 22, 52, 40, 56, 37, 24, 6, 16, 15],
        [16, 26, 11, 36, 54, 58, 41, 18, 6, 14, 27, 62, 40, 38, 49, 28,
         4, 22, 15, 61, 39, 51, 40, 46, 50, 34, 63, 7, 25, 15, 16],
        [16, 26, 11, 36, 54, 58, 41, 33, 53, 61, 40, 13, 27, 21, 2, 39,
         63, 45, 52, 6, 28, 8, 19, 38, 58, 42, 55, 15, 17, 7, 24],
        [16, 26, 11, 36, 54, 58, 41, 51, 39, 47, 58, 31, 9, 7, 16, 39,
         63, 45, 52, 6, 28, 8, 19, 52, 40, 56, 37, 29, 3, 21, 10],
        [16, 26, 11, 46, 60, 48, 35, 27, 15, 7, 18, 61, 43, 37, 50, 25,
         1, 19, 10, 50, 40, 60, 39, 34, 62, 46, 51, 1, 31, 9, 22],
        [16, 26, 11, 53, 39, 43, 56, 39, 51, 59, 46, 26, 12, 2, 21, 62,
         38, 52, 45, 14, 20, 0, 27, 57, 37, 53, 40, 1, 31, 9, 22],
        [16, 26, 11, 53, 39, 43, 56, 43, 63, 55, 34, 22, 0, 14, 25, 50,
         42, 56, 33, 2, 24, 12, 23, 57, 37, 53, 40, 1, 31, 9, 22],
        [16, 26, 36, 34, 48, 60, 0, 45, 57, 49, 11, 7, 17, 31, 39, 43,
         28, 14, 23, 12, 57, 45, 54, 38, 21, 5, 24, 9, 56, 46, 49],
        [16, 32, 49, 61, 47, 25, 10, 27, 15, 61, 40, 46, 56, 12, 27, 62,
         38, 14, 23, 6, 28, 50, 41, 5, 25, 51, 46, 53, 43, 7, 24],
    ]
end

"""
    table5_luts() -> Vector{SBox{6}}

The 14 canonical n=6 APN functions of Table 5, reconstructed as
`table5_prefix() ++ tail` (see the file header).
"""
function table5_luts()
    pre = table5_prefix()
    [SBox{6}(vcat(pre, t)) for t in table5_tails()]
end

"""
    table5_gamma_ranks() -> Vector{Int}

The paper's Γ-rank row of Table 5. Row 13 (Γ = 1300) is the class the paper
reports as new.
"""
table5_gamma_ranks() =
    [1172, 1146, 1102, 1168, 1170, 1170, 1170, 1172, 1174, 1166, 1170, 1166, 1300, 1158]

"""
    table5_ccz_column() -> Vector{String}

The paper's `CCZ eq.` row of Table 5: the reference [6] class number, `x^3` for
the power-function class, or `new` for the previously unknown class.
"""
table5_ccz_column() = [
    "11 [6]", "2 [6]", "x^3", "6 [6]", "8 [6]", "10 [6]", "9 [6]",
    "12 [6]", "13 [6]", "5 [6]", "7 [6]", "4 [6]", "new", "3 [6]",
]
