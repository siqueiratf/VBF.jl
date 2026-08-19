# Implements Section 5 — Table 1 and the closing CCZ remarks.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 5 — Closing remarks, Table 1 (known highly nonlinear diff-4 permutations)
#
# Pseudocode:
#   1. Build one smallest instance of each Table 1 row and compute
#      perm / du / linearity / nonlinearity / signed Walsh value set
#   2. Section 5's separation argument: the Walsh spectrum of the inverse
#      function is NOT a subset of {0, ±2^{n/2}, ±2^{(n+2)/2}} while that of F
#      is — hence F is CCZ-inequivalent to the inverse function
#   3. Record that at n=6 F is linear-equivalent to Gold x^5 (17 = 5·2^4 mod 63),
#      so the n=6 instance cannot support the paper's novelty claim
# VBF API used: gf_monomial_lut, SBox, is_permutation, differential_uniformity,
#               lat, linearity, nonlinearity, algebraic_degree,
#               are_linear_equivalent
#
# Runtime measured on this machine with @elapsed (Julia 1.12.6, AMD Ryzen 5
# 5600G): the three n=6 rows are instant, the n=12 Bracken–Leander row costs
# 2.1 s (full LAT), and the n=6 linear-equivalence certificate 1.3 s.
#
# Core `gold_apn` / `kasami_apn` / `inverse_apn` are deliberately NOT used: they
# guard the APN (odd-n) regime — `gold_apn(6,2)` and `kasami_apn(6,2)` throw on
# `gcd(k,n) = 1`, `inverse_apn(6)` throws on even n — whereas Table 1 is about
# the differentially-4, even-n regime.  The monomials are therefore built with
# core `gf_monomial_lut`, which is the underlying core API in all three cases.

include(joinpath(@__DIR__, "helpers.jl"))

# (label, n, exponent, paper conditions, reference)
const TABLE1_MONOMIALS = [
    ("Gold  x^5  (i=2)", 6, 5, "n=2k, k odd, gcd(n,i)=2", "[13]"),
    ("Kasami x^13 (i=2)", 6, 13, "n=2k, k odd, gcd(n,i)=2", "[14]"),
    ("Inverse x^62", 6, 62, "n even", "[1,16]"),
    ("Bracken–Leander x^73 (k=3)", 12, 73, "n=4k, k odd", "[7,12]"),
]

"""
    table1_row(label, n, d) -> NamedTuple

Compute one Table 1 row for the monomial `x^d` over `GF(2ⁿ)`.
"""
function table1_row(label::AbstractString, n::Int, d::Int)
    F = SBox{n}(gf_monomial_lut(n, d))
    vals = walsh_value_set(F)
    (
        label = label,
        n = n,
        perm = is_permutation(F),
        du = differential_uniformity(F),
        deg = algebraic_degree(F),
        lin = maximum(abs, vals),
        nl = nonlinearity(F),
        walsh = vals,
    )
end

"""
    table1_row_F(k, s) -> NamedTuple

The Table 1 row contributed by this paper: `F` of Theorem 1.1 at `(k, s)`.
"""
function table1_row_F(k::Int, s::Int)
    n = 3k
    F = bracken_binomial_sbox(k, s)
    vals = walsh_value_set(F)
    (
        label = "This article  αx^{2^s+1}+α^{2^k}x^{2^{-k}+2^{k+s}} (k=$k,s=$s)",
        n = n,
        perm = is_permutation(F),
        du = differential_uniformity(F),
        deg = algebraic_degree(F),
        lin = maximum(abs, vals),
        nl = nonlinearity(F),
        walsh = vals,
    )
end

# Core `table_to_markdown` renders an integer matrix (DDT/LAT); Table 1 mixes
# strings and integers, so the markdown is assembled here.
function table1_markdown(rows)
    header = "| Function | n | perm | du | deg | linearity | nonlinearity | Walsh values |"
    sep = "|---|---|---|---|---|---|---|---|"
    body = [
        string(
            "| ", r.label, " | ", r.n, " | ", r.perm ? "yes" : "no", " | ", r.du,
            " | ", r.deg, " | ", r.lin, " | ", r.nl, " | ",
            walsh_set_string(r.walsh), " |",
        ) for r in rows
    ]
    join(vcat(header, sep, body), "\n")
end

function section5_report(io::IO = stdout)
    print_section("Section 5 — Table 1 and the closing CCZ remarks", io)
    println(io, "  Table 1 lists the known highly nonlinear differentially 4 uniform")
    println(io, "  permutations on fields of even degree. Every row is recomputed at its")
    println(io, "  smallest instance; the last row is this paper's contribution.")
    println(io)

    rows = [table1_row(l, n, d) for (l, n, d, _, _) in TABLE1_MONOMIALS]
    push!(rows, table1_row_F(2, 4))

    all_pass = true
    for r in rows
        ok = r.perm && r.du == 4
        all_pass &= ok
        print_check("$(rpad(r.label, 58)) n=$(r.n): perm=$(r.perm), du=$(r.du), " *
                    "NL=$(r.nl), Walsh $(walsh_set_string(r.walsh))", ok, io)
    end
    println(io)
    println(io, table1_markdown(rows))
    println(io)

    # --- Section 5's separation from the inverse function ------------------
    n = 6
    allowed = Set([0, 8, -8, 16, -16])          # {0, ±2^{n/2}, ±2^{(n+2)/2}}
    inv_vals = walsh_value_set(SBox{n}(gf_monomial_lut(n, (1 << n) - 2)))
    F_vals = walsh_value_set(bracken_binomial_sbox(2, 4))
    inv_outside = !issubset(Set(inv_vals), allowed)
    F_inside = issubset(Set(F_vals), allowed)
    print_check("Walsh-set(inverse, n=6) = $(walsh_set_string(inv_vals)) ⊄ {0, ±8, ±16}",
                inv_outside, io)
    print_check("Walsh-set(F, n=6) = $(walsh_set_string(F_vals)) ⊆ {0, ±8, ±16}",
                F_inside, io)
    print_check("⇒ F is CCZ-inequivalent to the inverse function (Section 5 argument)",
                inv_outside && F_inside, io)
    all_pass &= inv_outside && F_inside

    # --- Paper Issue 2: the n=6 instance cannot carry the novelty claim -----
    println(io)
    exp_ok = mod(5 * (1 << 4), 63) == 17
    gold5 = SBox{6}(gf_monomial_lut(6, 5))
    F6 = bracken_binomial_sbox(2, 4)
    c = 2 ⊻ gf_pow(2, 1 << 2, 6)               # α + α^{2^k}
    lut_ok = F6.lut == [gf_mul(c, gf_pow(gf_pow(x, 16, 6), 5, 6), 6) for x = 0:63]
    le_ok = are_linear_equivalent(F6, gold5)
    print_check("n=6 degeneracy: 17 = 5·2^4 mod 63, so F = $(c)·(x^{2^4})^5", exp_ok && lut_ok, io)
    print_check("core are_linear_equivalent(F(2,4), Gold x^5) = true", le_ok, io)
    all_pass &= exp_ok && lut_ok && le_ok
    print_kv("scope",
             "the n=6 instance of Theorem 1.1 is linear-equivalent to Table 1's " *
             "FIRST row, so it cannot support the novelty claim; the paper never " *
             "states this caveat (Paper Issue 2). The first genuine binomial with " *
             "t=2 is n=30 — see theorem1_1.jl", io)

    println(io)
    print_check("All Section 5 / Table 1 checks pass", all_pass, io)
    print_kv("completeness",
             "all 4 prior Table 1 rows plus this paper's row, each exhaustive at " *
             "its smallest instance; the CCZ-inequivalence to Gold/Kasami is " *
             "quoted from ref [8] (t=1) and TRANSCRIBED for t=2 — the paper only " *
             "writes \"we expect the case of t=2 to be no different\"", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section5_report()
end
