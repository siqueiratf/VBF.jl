# Implements Table 3: canonical APN functions in F(F₂⁵,F₂⁵) up to EA equivalence.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 4/5 — EA equivalence (Table 3, feeding Theorems 5 and 6)
#
# OCR reconstruction rule (Paper Issue 2)
# ---------------------------------------
# The tex header is doubly broken — columns 0 and 1 are merged into `01`, and
# `11` is split into a `1` cell plus an empty cell — and every data row carries
# a stray empty cell right after position 10. The *numeric* cells are complete
# and in order, though: dropping the empty cell from each row leaves exactly 32
# values. No value has to be invented. The reconstruction is self-checking: all
# 7 rows are APN with degrees 2, 2, 3, 3, 4, 3, 3 — the paper's degree column —
# and the `EA` and `CCZ` columns reproduce as well.
#
# Pseudocode:
#   1. table3_luts()     — the 7 reconstructed LUTs
#   2. table3_report(io) — assert APN, degree, the `EA` column and the `CCZ` column
# VBF API used: SBox, differential_uniformity, algebraic_degree, gamma_rank,
#               are_ea_equivalent, are_ccz_equivalent, gf_monomial_lut,
#               primitive_polynomial

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

"""
    table3_luts() -> Vector{SBox{5}}

The 7 canonical APN functions of Table 3 (n=5), up to EA equivalence, with the
stray OCR cell removed (see the file header). All 7 vanish on the affine
standard basis {0,1,2,4,8,16}, as every EA-canonical representative must.
"""
function table3_luts()
    rows = [
        [0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 28, 27,
         0, 8, 16, 25, 5, 15, 17, 26, 22, 26, 14, 3, 3, 13, 31, 16],
        [0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 28, 27,
         0, 8, 16, 25, 5, 15, 17, 26, 27, 23, 3, 14, 14, 0, 18, 29],
        [0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 29, 26,
         0, 8, 16, 25, 5, 15, 19, 24, 7, 11, 27, 22, 26, 20, 1, 14],
        [0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 29, 26,
         0, 8, 16, 25, 5, 15, 19, 24, 10, 6, 22, 27, 23, 25, 12, 3],
        [0, 0, 0, 1, 0, 2, 4, 8, 0, 3, 6, 12, 7, 16, 25, 23,
         0, 7, 3, 22, 28, 19, 9, 0, 19, 8, 15, 28, 21, 9, 29, 2],
        [0, 0, 0, 1, 0, 2, 4, 8, 0, 3, 6, 16, 8, 21, 26, 29,
         0, 5, 12, 27, 20, 6, 31, 16, 7, 31, 8, 22, 9, 26, 17, 11],
        [0, 0, 0, 1, 0, 2, 4, 8, 0, 3, 6, 16, 8, 21, 26, 29,
         0, 6, 15, 24, 18, 3, 17, 30, 2, 29, 14, 20, 25, 13, 9, 23],
    ]
    [SBox{5}(r) for r in rows]
end

"""
    table3_degrees() -> Vector{Int}

The paper's algebraic-degree column of Table 3.
"""
table3_degrees() = [2, 2, 3, 3, 4, 3, 3]

"""
    table3_ea_exponents() -> Vector{Union{Int,Nothing}}

The paper's `EA` column: the power function each row is EA equivalent to, or
`nothing` for the two rows the paper marks `[5]` (the Budaghyan–Carlet–Pott
family, eq. (6) — EA inequivalent to every power function).
"""
table3_ea_exponents() = Union{Int,Nothing}[5, 3, nothing, nothing, 15, 11, 7]

"""
    table3_ccz_column() -> Vector{Int}

The paper's `CCZ` column, normalised to the row index of the CCZ-canonical
representative: rows 1, 2 and 5 are marked `can.` (they are the three CCZ
classes of Theorem 6), rows 3 and 7 are marked `1`, rows 4 and 6 are marked `2`.
"""
table3_ccz_column() = [1, 2, 1, 2, 5, 2, 1]

"""
    table3_report(io)

Table 3 — the 7 EA-canonical APN functions for n=5. Asserts, per row: APN, the
paper's algebraic degree, the `EA` column (EA equivalence to a power function),
and the `CCZ` column (which of the three CCZ classes the row falls in).
"""
function table3_report(io::IO = stdout)
    print_section(io, "Table 3 — EA-canonical APN functions in F(F₂⁵,F₂⁵)")
    println(io, "  OCR reconstruction: the stray empty cell after position 10 is dropped;")
    println(io, "  the 32 numeric cells per row are complete and in order.")

    mod5 = primitive_polynomial(5)
    luts = table3_luts()
    degs = table3_degrees()
    eas = table3_ea_exponents()
    cczs = table3_ccz_column()
    basis = [0, 1, 2, 4, 8, 16]

    for (i, F) in enumerate(luts)
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        print_check(io, "no. $i: APN (du=$du), deg=$deg (paper $(degs[i])), Γ-rank=$(gamma_rank(F))",
                    du == 2 && deg == degs[i])
        print_check(io, "no. $i: vanishes on the affine standard basis (EA-canonical)",
                    all(F.lut[b+1] == 0 for b in basis))
    end

    print_section(io, "Table 3 — `EA` column")
    for (i, F) in enumerate(luts)
        d = eas[i]
        if d === nothing
            println(io, "  no. $i: paper says `[5]` (BCP family eq. (6)) — see theorem5.jl")
        else
            P = SBox{5}(gf_monomial_lut(5, d; modulus = mod5))
            print_check(io, "no. $i: EA equivalent to x^$d",
                        are_ea_equivalent(F, P; on_inconclusive = :missing) === true)
        end
    end

    print_section(io, "Table 3 — `CCZ` column (3 classes: rows 1, 2, 5)")
    reps = [luts[1], luts[2], luts[5]]
    rep_rows = [1, 2, 5]
    for (i, F) in enumerate(luts)
        j = findfirst(R -> are_ccz_equivalent(F, R; on_inconclusive = :missing) === true, reps)
        got = j === nothing ? 0 : rep_rows[j]
        print_check(io, "no. $i: CCZ class of row $got (paper $(cczs[i]))", got == cczs[i])
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    table3_report()
end
