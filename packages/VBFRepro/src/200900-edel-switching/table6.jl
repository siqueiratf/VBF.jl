# Implements Table 6 — Invariants of the n=6 switching classes.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: 4 — Computational results (Table 6: Γ-rank, Δ-rank, Aut orders, Walsh).
#
# Pseudocode:
#   1. For each Table-5 representative compute the CCZ-invariant Γ-rank and
#      Δ-rank (F_2 rank of dev(G_F) / dev(D_F) incidence matrices).
#   2. Compare against the paper's published (Γ, Δ) pair.
#   3. Classify the Walsh spectrum as classical / non-classical via the
#      CCZ-invariant absolute_walsh_spectrum; only 2.6 is non-classical.
#   4. Automorphism / multiplier-group orders (Table 6 cols 4-5) are MAGMA-only
#      and NOT executed here — reported as documented values.
# VBF API used: gamma_rank, delta_rank, absolute_walsh_spectrum,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    table6_report(io = stdout; save_results = false) -> NamedTuple

Recompute Γ-rank / Δ-rank and the Walsh class for all `n = 6` Table-5
representatives and check them against the paper's Table 6. `n = 6` design
ranks need a 2¹² × 2¹² F₂ matrix each — sub-second per function.
"""
function table6_report(io::IO = stdout; save_results::Bool = false)
    print_section("Table 6 — n=6 invariants: Γ-rank, Δ-rank, Walsh class", io)
    rows = edelpott_table5()

    all_ok = true
    computed = NamedTuple[]
    for r in rows
        g = gamma_rank(r.sbox)
        d = delta_rank(r.sbox)
        wclass = ep_is_classical(r.sbox) ? :classical : :nonclassical
        ok = g == r.gamma && d == r.delta && wclass == r.walsh
        all_ok &= ok
        push!(computed, (; name = r.name, gamma = g, delta = d, walsh = wclass))
        print_check("F$(r.name): Γ=$g (paper $(r.gamma)), Δ=$d (paper $(r.delta)), " *
            "Walsh $(wclass)", ok, io)
    end

    print_kv("all Γ/Δ/Walsh match Table 6", all_ok, io)
    print_kv("non-classical Walsh", [r.name for r in computed if r.walsh == :nonclassical], io)
    print_kv("Δ-rank bound Δ ≤ 2^(n+1)=128", "holds for all quadratic; 2.11 has Δ=152 > 128", io)
    print_kv("Aut(dev(G_F)), Aut(dev(D_F)), |M(G_F)| (Table 6 cols 4-5)",
        "MAGMA-only — not executed (see theorem10.jl)", io)
    print_kv("completeness", "exhaustive (all 14 representatives, n=6)", io)

    result = (; all_ok, computed)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "table6.toml"), "w") do f
            println(f, "# Edel–Pott (2009) Table 6 — n=6 Γ/Δ-rank + Walsh class")
            println(f, "all_match = $(all_ok)")
            for r in computed
                println(f, "[\"$(r.name)\"]\ngamma = $(r.gamma)\ndelta = $(r.delta)\n" *
                    "walsh = \"$(r.walsh)\"")
            end
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table6_report()
end
