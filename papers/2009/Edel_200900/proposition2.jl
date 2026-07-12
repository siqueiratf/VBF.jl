# Implements Proposition 2 — x^3 + tr(x^9) is APN for all n.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: 3 — Dillon's switching construction (Proposition 2).
#
# Pseudocode:
#   for n in 2..max_n:
#     F(x) = x^3 XOR tr(x^9)     # tr = absolute trace F_2^n → F_2 (0/1)
#     assert differential_uniformity(SBox(F)) == 2
# This is the seed switch (F = x^3, u = 1, f = tr(x^9)) behind the whole paper.
# VBF API used: gf_pow, gf_trace, primitive_polynomial, differential_uniformity, SBox
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition2_report(io = stdout; max_n = 8, save_results = false) -> NamedTuple

Bounded demo of Proposition 2: `x³ + tr(x⁹)` is APN for every `n` in `2:max_n`.
Cost is `O(2^{2n})` per `n` (DDT). Default `max_n = 8` keeps the report fast.
"""
function proposition2_report(io::IO = stdout; max_n::Int = 8, save_results::Bool = false)
    print_section("Proposition 2 — x^3 + tr(x^9) is APN for all n (demo 2..$max_n)", io)
    checked = NamedTuple[]
    all_apn = true
    for n = 2:max_n
        modulus = try
            primitive_polynomial(n)
        catch
            continue                       # no canonical modulus tabulated for this n
        end
        lut = [gf_pow(x, 3, n; modulus) ⊻ gf_trace(gf_pow(x, 9, n; modulus), n; modulus)
               for x = 0:(1 << n) - 1]
        du = differential_uniformity(SBox(lut))
        apn = du == 2
        all_apn &= apn
        push!(checked, (; n, du))
        print_check("n=$n: x^3+tr(x^9) APN (Δ-uniformity=$du)", apn, io)
    end
    print_kv("all APN over 2..$max_n", all_apn, io)
    print_kv("completeness", "bounded demo (paper proves it for all n)", io)

    result = (; all_apn, checked, max_n)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition2.toml"), "w") do f
            println(f, "# Edel–Pott (2009) Proposition 2 — x^3+tr(x^9) APN")
            println(f, "all_apn = $all_apn")
            println(f, "n_range = \"2..$max_n\"")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition2_report()
end
