# Implements Conjecture 21 — power APN functions share S1, S2 with x^3.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Conjecture 21 (Eq. 34)
#
# Pseudocode:
#   For each power APN function F(x) = x^k over F_{2^n}, 1 ≤ n ≤ n_max:
#   1. Load SBox from catalog (or generate via gf_monomial_lut)
#   2. Compute S1(F) via DDT  [F(0)=0, F(1)=1 holds for all power functions]
#   3. Compute expected value from formula (34) for the same n
#   4. Check: S1(F) == S1(x^3) = formula34(n)
# VBF API used: SBox, gf_monomial_lut, primitive_polynomial, ddt
# Catalog API used: load_apn_function, apn_catalog_names

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

# formula34 comes from helpers.jl (shared with table2.jl).


"""
    conjecture21_report(; io::IO = stdout) -> NamedTuple

Verify Conjecture 21: for every power APN function in the catalog,
S1(F) equals formula34(n) (the x^3 value for the same dimension).
Power functions satisfy F(0)=0, F(1)=1 automatically.
"""
function conjecture21_report(; io::IO = stdout)
    print_section("Conjecture 21 — power APN functions share S1 with x^3", io)
    println(io, "  Conjecture 21: for any power APN F over F_{2^n},")
    println(io, "  S1(F) = S2(F) = formula34(n)  [same as x^3].")
    println(io)

    # Conjecture 21 concerns *power* APN functions only. Catalog power entries are
    # exactly those declaring a `monomial_exponent`; non-power APN (trinomials,
    # bivariate, ...) are out of scope and must be excluded.
    names = filter(n -> haskey(apn_catalog_metadata(n), "monomial_exponent"),
                   apn_catalog_names())
    rows = NamedTuple[]
    all_match = true

    println(io, "  $(rpad("name",22))  n  $(lpad("S1",8))  $(lpad("expected",8))  match")
    println(io, "  " * "─"^60)

    for name in sort(names)
        s = load_apn_function(name)
        N = inputbits(s)
        expected = formula34(N)
        s1 = compute_s1(s)
        match = (s1 == expected)
        all_match &= match
        println(io, "  $(rpad(name,22))  $N  $(lpad(s1,8))  $(lpad(expected,8))  $(match ? "✓" : "✗")")
        push!(rows, (; name, n=N, s1, expected, match))
    end

    println(io)
    print_check("Conjecture 21 holds for all catalog power APN functions", all_match, io)
    print_kv("functions tested", length(rows), io)
    ns = unique(r.n for r in rows)
    print_kv("dimensions covered", "n ∈ $(sort(ns))", io)
    print_kv("completeness", "bounded demo — catalog power APN only, not all power APN", io)

    return (; rows, all_match)
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    conjecture21_report()
end
