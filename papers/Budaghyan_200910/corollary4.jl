# Implements Corollary 4 — (6),(7),(8) for general n; the n=9 new families.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: II.B — The case n odd.
#
# Corollary 4: (6) is APN over GF(2ⁿ) for any n; if 3 | n, (7),(8) are APN too.
#   For n odd, all a give functions EA-equivalent to a=1.
#   For n=9: (6),(7),(8) are pairwise CCZ-INEQUIVALENT, and (7),(8) are
#   CCZ-inequivalent to every previously known APN family (two NEW families).
#
# Pseudocode:
#   verify APN+quadratic for (6)[odd n], (7),(8)[3|n];
#   at n=9: signatures of (6),(7),(8) pairwise distinct, and distinct from the
#   quadratic Gold family {x³,x⁵,x¹⁷}. Non-quadratic family CCZ tests gated.
# VBF API used: differential_uniformity, algebraic_degree, ortho_derivative,
#               gold_apn, known_apn_monomials, are_ccz_equivalent

include(joinpath(@__DIR__, "helpers.jl"))

"""
    corollary4_report(io; full_search, save_results) -> NamedTuple

Verify (6),(7),(8) APN for odd/3∣n, and the n=9 CCZ-inequivalence claims.
"""
function corollary4_report(
    io::IO = stdout;
    full_search::Bool = false,
    save_results::Bool = false,
)
    print_section("Corollary 4 — (6) APN any n; (7),(8) APN for 3|n", io)
    all_ok = true
    rows = Tuple{Int,Symbol,Int,Int}[]
    for n in (5, 7, 9)                                   # (6): a=1 (odd n ⇒ a absorbed)
        F = as_sbox(apn_eq6(n, 1), n)
        du = differential_uniformity(F); deg = algebraic_degree(F)
        ok = du == 2 && deg == 2; all_ok &= ok
        print_check("eq(6) n=$n: APN (δ=$du, deg=$deg)", ok, io)
        push!(rows, (n, :eq6, du, deg))
    end
    for n in (3, 9), (name, f) in ((:eq7, apn_eq7), (:eq8, apn_eq8))   # (7),(8): 3|n
        F = as_sbox(f(n, 1), n)
        du = differential_uniformity(F); deg = algebraic_degree(F)
        ok = du == 2 && deg == 2; all_ok &= ok
        print_check("$name n=$n: APN (δ=$du, deg=$deg)", ok, io)
        push!(rows, (n, name, du, deg))
    end

    # ── n=9: pairwise CCZ-inequivalence + inequivalence to Gold family ─────────
    print_section("Corollary 4 — n=9: (6),(7),(8) pairwise CCZ-inequivalent; (7),(8) new", io)
    n = 9
    sigs = Dict(
        :eq6 => od_signature(apn_eq6(n, 1), n),
        :eq7 => od_signature(apn_eq7(n, 1), n),
        :eq8 => od_signature(apn_eq8(n, 1), n),
    )
    names = (:eq6, :eq7, :eq8)
    pairwise = true
    for i = 1:3, j = (i+1):3
        d = sigs[names[i]] !== nothing && sigs[names[i]] != sigs[names[j]]
        pairwise &= d
        print_check("$(names[i]) vs $(names[j]): ortho-deriv signatures differ", d, io)
    end
    all_ok &= pairwise

    # Quadratic known family at n=9: the Gold power functions x^(2^k+1), gcd(k,9)=1.
    gold_sigs = [od_signature(gold_apn(9, k)) for k in (1, 2, 4)]
    vs_gold = true
    for nm in (:eq7, :eq8)
        d = all(gs -> gs !== nothing && sigs[nm] != gs, gold_sigs)
        vs_gold &= d
        print_check("$nm CCZ-inequivalent to Gold family {x³,x⁵,x¹⁷}", d, io)
    end
    all_ok &= vs_gold
    print_kv("method", "ortho-derivative spectrum (rigorous one-way for quadratic APN)", io)
    print_kv(
        "non-quadratic families",
        "Kasami/Welch/Niho/inverse comparison gated by full_search (linear-code CCZ)",
        io,
    )

    # Optional heavy check: full CCZ test vs every known family monomial.
    vs_known_full = missing
    if full_search
        print_section("Corollary 4 — n=9: full CCZ test vs all known monomial families", io)
        vs_known_full = true
        for nm in (:eq7, :eq8)
            Fnm = as_sbox(nm === :eq7 ? apn_eq7(9, 1) : apn_eq8(9, 1), 9)
            for (fam, G) in known_apn_monomials(9)
                eq = are_ccz_equivalent(Fnm, G)
                vs_known_full &= !eq
                print_check("$nm CCZ-inequivalent to $fam", !eq, io)
            end
        end
        all_ok &= vs_known_full
    end

    result = (; all_ok, rows, pairwise, vs_gold, vs_known_full)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary4.toml"), "w") do f
            println(f, "# Corollary 4")
            println(f, "all_ok = $all_ok")
            println(f, "pairwise_ccz_distinct = $pairwise")
            println(f, "vs_gold = $vs_gold")
            println(f, "# CATALOG-GAP CANDIDATES: n=9 eqs (7),(8) — new quadratic APN families")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary4_report()
end
