# Implements Theorem 7 + Corollary 8 — the Δ-rank crookedness bound.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: 2 — Equivalence of APN mappings (Theorem 7, Corollary 8).
#
# Pseudocode:
#   1. Theorem 7: if an APN F is CCZ-crooked then Δ-rank(F) ≤ 2^(n+1).
#      Contrapositive test: Δ-rank > 2^(n+1) ⇒ F is not crooked.
#   2. Demonstrate on the n=6 catalogue: all quadratic reps satisfy Δ ≤ 128;
#      2.11 has Δ=152 > 128, so it is not crooked (hence non-quadratic).
#   3. Corollary 8 (opt-in, n=7 heavy): Kasami x^13 and x^57 on GF(2^7) have
#      Δ-rank 338 and 436 (> 2^8=256) ⇒ not crooked.
# VBF API used: delta_rank, gf_monomial_lut, differential_uniformity, SBox,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem7_report(io = stdout; full_search = false, save_results = false) -> NamedTuple

Reproduce the Δ-rank crookedness bound. Default path is the fast `n = 6`
catalogue. `full_search = true` also computes the `n = 7` Kasami Δ-ranks of
Corollary 8 (each is a 2¹⁴ × 2¹⁴ F₂ rank — minutes).
"""
function theorem7_report(io::IO = stdout; full_search::Bool = false,
        save_results::Bool = false)
    print_section("Theorem 7 — Δ-rank ≤ 2^(n+1) is necessary for crooked", io)

    bound6 = 1 << (EP_N + 1)          # 128
    rows = edelpott_table5()
    all_quad_ok = true
    for r in rows
        d = delta_rank(r.sbox)
        crooked_possible = d <= bound6
        if r.name == "2.11"
            print_check("F2.11: Δ-rank $d > $bound6 ⇒ NOT crooked ⇒ not CCZ-quadratic",
                d > bound6, io)
        else
            all_quad_ok &= crooked_possible
        end
    end
    print_check("all quadratic reps satisfy Δ-rank ≤ $bound6 (consistent with Theorem 7)",
        all_quad_ok, io)
    print_kv("2.11 Δ-rank", "152 > 128 (the non-crooked / non-quadratic witness)", io)

    # Corollary 8 — Kasami x^13, x^57 on GF(2^7).
    cor8 = NamedTuple[]
    if full_search
        print_section("Corollary 8 — Kasami x^13, x^57 on GF(2^7) (opt-in, heavy)", io)
        bound7 = 1 << 8               # 256
        for (name, d_exp, published) in (("x^13", 13, 338), ("x^57", 57, 436))
            F = SBox(gf_monomial_lut(7, d_exp))
            du = differential_uniformity(F)
            dr = delta_rank(F)
            push!(cor8, (; name, delta = dr, published))
            print_check("Kasami $name: APN=$(du==2), Δ-rank=$dr (paper $published), " *
                "$dr > $bound7 ⇒ not crooked", du == 2 && dr == published && dr > bound7, io)
        end
    else
        print_kv("Corollary 8 (n=7 Kasami Δ-ranks 338, 436)",
            "not executed — pass full_search=true (2^14×2^14 F₂ rank each)", io)
    end

    result = (; bound6, all_quad_ok, cor8)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem7.toml"), "w") do f
            println(f, "# Edel–Pott (2009) Theorem 7 — Δ-rank crookedness bound")
            println(f, "n6_bound = $bound6")
            println(f, "all_quadratic_within_bound = $all_quad_ok")
            for c in cor8
                println(f, "[\"kasami_$(c.name)\"]\ndelta = $(c.delta)")
            end
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem7_report()
end
