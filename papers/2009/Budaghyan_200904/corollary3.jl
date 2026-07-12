# Implements Corollary 3 (x³+tr(x⁹) is EA-inequivalent to any power fn, n≥7).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §3 — Corollary 3
#
# F is quadratic APN. By Theorem 3 it is EA-inequivalent to any quadratic power
# function (Gold — the only quadratic APN power maps). Algebraic degree is
# EA-invariant, so F (degree 2) is EA-inequivalent to every non-quadratic power
# mapping as well.
#
# Pseudocode:
#   1. deg(F)==2.
#   2. Gold power maps: are_ea_equivalent(F, Gold) == false (Theorem 3, exact).
#   3. Non-quadratic power maps: algebraic_degree ≠ 2 ⇒ EA-inequivalent
#      (degree is EA-invariant).
#
# VBF API used: gold_apn, gf_monomial_lut, algebraic_degree,
#               are_ea_equivalent, differential_uniformity, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    corollary3_report(io; n, save_results) -> NamedTuple

EA-inequivalence of `x³+tr(x⁹)` to every power function at `n` (default 7):
Gold via Theorem 3 (EA-test), all other power maps via the degree invariant.
"""
function corollary3_report(io::IO = stdout; n::Integer = 7, save_results::Bool = false)
    print_section("Corollary 3 — x³+tr(x⁹) EA-inequivalent to any power fn (n=$n)", io)
    F = apn_x3_tr_x9(n)
    degF = algebraic_degree(F)
    print_check("F is quadratic (deg=$degF)", degF == 2, io)

    # Quadratic power maps = Gold: EA-inequivalence is exactly Theorem 3.
    gold_ea = false
    for k = 1:((n - 1) ÷ 2)
        gcd(k, n) == 1 || continue
        gold_ea |= are_ea_equivalent(F, gold_apn(n, k))
    end
    print_check("EA-inequivalent to all Gold power maps (Theorem 3)", !gold_ea, io)

    # Non-quadratic APN power maps at n=7: degree ≠ 2 ⇒ EA-inequivalent.
    higher = [(:kasami13, 13), (:kasami23, 23)]
    deg_ok = true
    for (name, d) in higher
        P = SBox{n}(gf_monomial_lut(n, d))
        dg = algebraic_degree(P)
        deg_ok &= dg != 2
        print_check("EA-inequivalent to x^$d ($(name), deg=$dg ≠ 2, degree EA-invariant)", dg != 2, io)
    end

    all_ok = degF == 2 && !gold_ea && deg_ok
    result = (; n, degF, gold_ea, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary3.toml"), "w") do fh
            println(fh, "# Corollary 3\nn = $n\ndegF = $degF\nEA_to_gold = $gold_ea\nall_ok = $all_ok")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary3_report()
end
