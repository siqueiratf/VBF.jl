# Implements Table 2 — formula (34) applied to F(x)=x^3 for n=1..20.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Example derivation of formula (34); Table 2
#
# Pseudocode:
#   For F(x) = x^3 over F_{2^n}:
#   1. By parity of n and n/2, apply formula (34):
#      S1 = 2(2^{n-1} - 1)            if n odd
#      S1 = 2(2^{n-1} + 2^{n/2} - 1) if n even, n/2 odd
#      S1 = 2(2^{n-1} - 2^{n/2} - 1) if n even, n/2 even
#   2. For n ≤ n_max_ddt: also compute S1 via DDT and assert match
#   3. Table 2 note: S1 = S2 for x^3 (since x^3 is power function with x^3 ∘ (x+1) = (x+1)^3)
# VBF API used: SBox, gf_monomial_lut, primitive_polynomial, ddt (via helpers)

include(joinpath(@__DIR__, "helpers.jl"))


"""
    formula34(n::Int) -> Int

Formula (34) from Kaleyski (2019): value of S1(x^3) = Σ_y DD_{x^3}(y, y^3⊕1)
as a function of n parity.
"""
function formula34(n::Int)::Int
    if isodd(n)
        return 2 * (2^(n-1) - 1)
    elseif isodd(n ÷ 2)   # n even, n/2 odd
        return 2 * (2^(n-1) + 2^(n÷2) - 1)
    else                   # n even, n/2 even
        return 2 * (2^(n-1) - 2^(n÷2) - 1)
    end
end


"""
    table2_report(; n_max_ddt::Int = 10, n_max_formula::Int = 20, io::IO = stdout) -> NamedTuple

Reproduce Table 2: S1 values for F(x)=x^3, n=1..n_max_formula.
DDT-verifies formula (34) for n=1..n_max_ddt.
"""
function table2_report(; n_max_ddt::Int = 10, n_max_formula::Int = 20, io::IO = stdout)
    print_section("Table 2 — Formula (34): S1(x^3) for n=1..$(n_max_formula)", io)
    println(io, "  DDT-verified for n=1..$(n_max_ddt); formula only for larger n.")
    println(io)
    println(io, "  n   formula_S1     via_DDT   match")
    println(io, "  " * "─"^44)

    rows = NamedTuple[]
    all_match = true

    for n in 1:n_max_formula
        s1_formula = formula34(n)

        if n <= n_max_ddt && n >= 2  # n=1 is trivial (x^3 = x for n=1), skip DDT
            poly = primitive_polynomial(n)
            lut = gf_monomial_lut(n, 3; modulus = poly)
            s = SBox(lut)
            # power functions: F(0)=0, F(1)=1 automatically
            s1_ddt = compute_s1(s)
            match = (s1_formula == s1_ddt)
            all_match &= match
            println(io, "  $(lpad(n,2))  $(lpad(s1_formula,12))  $(lpad(s1_ddt,9))   $(match ? "✓" : "✗")")
            push!(rows, (; n, s1_formula, s1_ddt, match))
        else
            println(io, "  $(lpad(n,2))  $(lpad(s1_formula,12))  $(rpad("—",9))   (formula)")
            push!(rows, (; n, s1_formula, s1_ddt = missing, match = missing))
        end
    end

    println(io)
    print_check("Formula (34) matches DDT for n=2..$(n_max_ddt)", all_match, io)
    print_kv("n=1 note", "trivial (x^3 = x mod x^2+x+1 not APN; formula gives $(formula34(1)))", io)
    print_kv("completeness", "formula: exhaustive (closed form); DDT: exhaustive n≤$(n_max_ddt)", io)

    return (; rows, all_match, n_max_ddt, n_max_formula)
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table2_report()
end
