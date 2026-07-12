# Implements Corollary 1 (x³ + tr(x⁹) is APN over GF(2ⁿ) for all n).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §2 — Corollary 1 (flagship result)
#
# Pseudocode:
#   1. For n = 3..n_max build F(x) = x³ + tr(x⁹) (Theorem 1 with F=x³, f=tr(x⁹)).
#   2. Verify differential_uniformity(F) == 2 (APN) and algebraic_degree(F) == 2.
#   The "for all n" quantifier is the paper's algebraic proof (not-executed);
#   here each n in the range is an exact check.
#
# VBF API used: differential_uniformity, algebraic_degree, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))

"""
    corollary1_report(io; n_max, save_results) -> NamedTuple

Verify `x³ + tr(x⁹)` is APN (differential_uniformity 2) with algebraic degree 2
for every `n` in `3:n_max` (exact per `n`).
"""
function corollary1_report(io::IO = stdout; n_max::Integer = 8, save_results::Bool = false)
    print_section("Corollary 1 — x³ + tr(x⁹) is APN for every n", io)
    rows = NamedTuple[]
    all_apn = true
    all_deg2 = true
    for n = 3:n_max
        F = apn_x3_tr_x9(n)
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        apn = du == 2
        deg2 = deg == 2
        all_apn &= apn
        all_deg2 &= deg2
        push!(rows, (; n, du, deg, perm = is_permutation(F)))
        print_check("n=$n: APN (du=$du) & degree 2 (deg=$deg)", apn && deg2, io)
    end
    print_kv("range", "n = 3:$n_max (each exact)", io)
    print_kv("for-all-n", "paper's algebraic proof — not reproduced as finite computation", io)

    result = (; n_max, all_apn, all_deg2, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary1.toml"), "w") do fh
            println(fh, "# Corollary 1 — x^3 + tr(x^9)")
            println(fh, "all_apn = $all_apn")
            println(fh, "all_deg2 = $all_deg2")
            for r in rows
                println(fh, "[[row]]\nn = $(r.n)\ndu = $(r.du)\ndeg = $(r.deg)")
            end
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary1_report()
end
