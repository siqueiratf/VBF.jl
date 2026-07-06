# Implements Theorem 3 (x³+tr(x⁹) is CCZ-inequivalent to any Gold function, n≥7).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §3 — Theorem 3
#
# Pseudocode:
#   1. Build F = x³+tr(x⁹) and every Gold rep x^{2^k+1} with gcd(k,7)=1 at n=7.
#   2. Assert are_ccz_equivalent(F, Gold) == false (quadratic APN ⇒ decided by the
#      ortho-derivative EA test, exact).
#   The n≥7 general statement is the paper's algebraic proof (not-executed).
#
# VBF API used: gold_apn, are_ccz_equivalent, are_ea_equivalent,
#               differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem3_report(io; n, save_results) -> NamedTuple

Verify `x³+tr(x⁹)` is CCZ-inequivalent to every Gold function at `n` (default 7).
"""
function theorem3_report(io::IO = stdout; n::Integer = 7, save_results::Bool = false)
    print_section("Theorem 3 — x³+tr(x⁹) CCZ-inequivalent to Gold (n=$n)", io)
    F = apn_x3_tr_x9(n)
    print_check("F=x³+tr(x⁹) is APN", differential_uniformity(F) == 2, io)
    ks = [k for k = 1:((n - 1) ÷ 2) if gcd(k, n) == 1]
    all_inequiv = true
    for k in ks
        G = gold_apn(n, k)
        ccz = are_ccz_equivalent(F, G)
        all_inequiv &= !ccz
        print_check("CCZ-inequivalent to Gold x^(2^$k+1)", !ccz, io)
    end
    print_kv("n≥7 (general)", "paper's algebraic proof — not reproduced as computation", io)

    result = (; n, gold_exps = ks, all_inequiv)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem3.toml"), "w") do fh
            println(fh, "# Theorem 3\nn = $n\nall_inequiv_to_gold = $all_inequiv")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_report()
end
