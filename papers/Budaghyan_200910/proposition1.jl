# Implements Proposition 1 (and Remark 1) — the n-even APN construction.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: II.A — The case n even.
#
# Proposition 1: n even, L linear. If x + L(x³) is a permutation of GF(2ⁿ) then
#   F(x³) = x³ + L(x⁹) is APN on GF(2ⁿ).
#
# Pseudocode:
#   for each known permutation class L (trace, class2, class3):
#       assert  x + L(x³)  is a permutation           (hypothesis)
#       build   x³ + L(x⁹)                            (Prop-1 output)
#       assert  differential_uniformity == 2 (APN) and algebraic_degree == 2
# VBF API used: is_permutation, differential_uniformity, algebraic_degree, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition1_cases(; full_search) -> Vector{Tuple{Symbol,Int}}

The (class, n) hypotheses to verify: the trace class for even n, and the two
6∣n classes at n=6. `full_search` adds n=12 (slow).
"""
function proposition1_cases(; full_search::Bool = false)
    cases = Tuple{Symbol,Int}[(:trace, 6), (:trace, 8), (:class2, 6), (:class3, 6)]
    full_search && append!(cases, [(:class2, 12), (:class3, 12), (:trace, 10)])
    cases
end

"""
    proposition1_report(io; full_search, save_results) -> NamedTuple

Verify Proposition 1: permutation hypothesis ⟹ APN conclusion.
"""
function proposition1_report(
    io::IO = stdout;
    full_search::Bool = false,
    save_results::Bool = false,
)
    print_section("Proposition 1 — n even: x+L(x³) perm ⟹ x³+L(x⁹) APN", io)
    all_ok = true
    rows = Tuple{Symbol,Int,Bool,Bool,Int,Int}[]
    for (cls, n) in proposition1_cases(; full_search)
        Llut = L_class_lut(cls, n)
        perm = perm_from_L(Llut, n)
        is_perm = is_permutation(as_sbox(perm, n))
        apn = apn_from_L(Llut, n)
        Fs = as_sbox(apn, n)
        du = differential_uniformity(Fs)
        deg = algebraic_degree(Fs)
        ok = is_perm && du == 2 && deg == 2
        all_ok &= ok
        print_check(
            "L=$cls, n=$n: x+L(x³) perm=$is_perm ⟹ x³+L(x⁹) APN (δ=$du, deg=$deg)",
            ok,
            io,
        )
        push!(rows, (cls, n, is_perm, du == 2, du, deg))
    end
    print_kv("completeness", "exhaustive over listed classes", io)
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition1.toml"), "w") do f
            println(f, "# Proposition 1")
            println(f, "all_ok = $all_ok")
            for (cls, n, p, a, du, deg) in rows
                println(f, "[[case]]\nclass=\"$cls\"\nn=$n\nperm=$p\napn=$a\ndelta=$du\ndegree=$deg")
            end
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition1_report()
end
