# Implements Corollary 4 (n=7: x³+tr(x⁹) CCZ-inequiv to all power/known APN maps).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §3 — Corollary 4  (headline computational claim)
#
# For n=7 the Δ-rank of F=x³+tr(x⁹) is 212, while the Kasami functions x¹³ and
# x²³ have Δ-ranks 338 and 436. Δ-rank is CCZ-invariant, so F is CCZ-inequivalent
# to the Kasami maps; with Theorem 3 (Gold) and the Welch/Niho cases coinciding
# with Kasami at n=7, F is CCZ-inequivalent to every power map on GF(2⁷) — and to
# every known APN mapping, since no known APN polynomial family is defined at n=7.
#
# Pseudocode:
#   1. Δ-rank(x³+tr(x⁹)) == 212  (exact; delta_rank supports n≤7).
#   2. Δ-rank(x¹³) == 338, Δ-rank(x²³) == 436.
#   3. Distinct ranks ⇒ CCZ-inequivalent (Δ-rank CCZ-invariant).
#
# VBF API used: gf_monomial_lut, delta_rank, differential_uniformity, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    corollary4_report(io; save_results) -> NamedTuple

Reproduce the n=7 Δ-rank certificate: 212 (x³+tr(x⁹)) vs 338 (x¹³) vs 436 (x²³).
"""
function corollary4_report(io::IO = stdout; save_results::Bool = false)
    print_section("Corollary 4 — n=7 Δ-rank certificate (CCZ-inequivalence)", io)
    n = 7
    F = apn_x3_tr_x9(n)
    K13 = SBox{n}(gf_monomial_lut(n, 13))     # Kasami x¹³
    K23 = SBox{n}(gf_monomial_lut(n, 23))     # x²³ (second Kasami CCZ-class at n=7)

    duF, du13, du23 = differential_uniformity(F), differential_uniformity(K13), differential_uniformity(K23)
    print_check("all three are APN (du = $duF, $du13, $du23)", duF == 2 && du13 == 2 && du23 == 2, io)

    dF = delta_rank(F)
    d13 = delta_rank(K13)
    d23 = delta_rank(K23)
    print_kv("Δ-rank x³+tr(x⁹)", dF, io)
    print_kv("Δ-rank x¹³ (Kasami)", d13, io)
    print_kv("Δ-rank x²³", d23, io)
    r212 = dF == 212
    r338 = d13 == 338
    r436 = d23 == 436
    print_check("Δ-rank(x³+tr(x⁹)) == 212", r212, io)
    print_check("Δ-rank(x¹³) == 338", r338, io)
    print_check("Δ-rank(x²³) == 436", r436, io)
    distinct = length(unique((dF, d13, d23))) == 3
    print_check("distinct Δ-ranks ⇒ CCZ-inequivalent to these power maps", distinct, io)
    print_kv("conclusion", "with Theorem 3 (Gold) ⇒ CCZ-inequiv to all power maps at n=7", io)
    print_kv("catalog-gap candidate", "n=7 x³+tr(x⁹) — NOT written to catalog (separate agent)", io)

    all_ok = r212 && r338 && r436 && distinct && duF == 2
    result = (; delta_x3tr9 = dF, delta_x13 = d13, delta_x23 = d23, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary4.toml"), "w") do fh
            println(fh, "# Corollary 4 (n=7)")
            println(fh, "delta_x3_tr_x9 = $dF")
            println(fh, "delta_x13 = $d13")
            println(fh, "delta_x23 = $d23")
            println(fh, "all_ok = $all_ok")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary4_report()
end
