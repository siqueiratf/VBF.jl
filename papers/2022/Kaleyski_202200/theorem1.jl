# Implements Theorem 1: sufficient conditions for 0-APN-ness of x^{e(l,k)}
# Paper: Kaleyski, Nesheim, Stănică (2022), "A doubly-infinite family of 0-APN monomials"
# Section: 2 — A doubly infinite family of 0-APN monomials
#
# Pseudocode:
#   1. For each (l,k) pair and n in range, check Theorem 1 conditions
#   2. Verify that whenever conditions hold, x^{e(l,k)} is indeed 0-APN
#   3. Demonstrate paper bug: printed e(k,l-1) vs correct e(l-1,k)
#   4. Compare Theorem 1 vs Remark 1 dimension sets
# VBF API used: print_section, print_check, print_kv, status_str

include(joinpath(@__DIR__, "helpers.jl"))

function theorem1_report(io::IO = stdout; max_n::Int = 100)
    print_section(io, "Theorem 1 — Sufficient conditions for 0-APN")

    # ── Paper bug demonstration ──────────────────────────────────────────
    print_kv(io, "paper bug", "Theorem 1 prints e(k,l-1); proof uses e(l-1,k)")
    n, l, k = 2, 3, 1
    e = e_exponent(l, k)
    printed_ok = theorem1_printed(l, k, n)
    correct_ok = theorem1_holds(l, k, n)
    actual = is_zero_apn_poly(e, n)
    print_kv(io, "counterexample", "n=$n, l=$l, k=$k, e=$e")
    print_kv(io, "  printed condition", string(printed_ok))
    print_kv(io, "  correct condition", string(correct_ok))
    print_kv(io, "  actual 0-APN", string(actual))
    print_check(io, "printed condition gives false positive (n=2,l=3,k=1)",
        printed_ok && !actual)
    print_check(io, "correct condition does not apply here",
        !correct_ok)

    # ── Verify Theorem 1 (corrected): no false positives ────────────────
    test_pairs = [(2, 1), (2, 2), (2, 3), (3, 1), (3, 2), (4, 1), (5, 1), (7, 1)]
    all_sound = true
    for (l, k) in test_pairs
        e = e_exponent(l, k)
        for n in 1:max_n
            if theorem1_holds(l, k, n)
                if !is_zero_apn_poly(e, n)
                    print_check(io, "Theorem 1 sound for (l=$l,k=$k,n=$n)", false)
                    all_sound = false
                end
            end
        end
    end
    print_check(io, "Theorem 1 (corrected) sound for all tested (l,k), n≤$max_n",
        all_sound)

    # ── Remark 1: alternative condition is subsumed ─────────────────────
    print_section(io, "Remark 1 — Alternative condition comparison")
    all_subsumed = true
    for (l, k) in test_pairs
        for n in 1:max_n
            if remark1_holds(l, k, n) && !theorem1_holds(l, k, n)
                all_subsumed = false
            end
        end
    end
    print_check(io, "Remark 1 dimensions ⊆ Theorem 1 dimensions for all tested pairs",
        all_subsumed)

    for (l, k) in [(5, 1), (7, 1)]
        e = e_exponent(l, k)
        thm1_count = count(n -> theorem1_holds(l, k, n), 1:max_n)
        rem1_count = count(n -> remark1_holds(l, k, n), 1:max_n)
        print_kv(io, "(l=$l,k=$k)", "Thm1=$thm1_count, Rem1=$rem1_count dims in 1:$max_n")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem1_report()
end
