# Implements Lemma B.1 and Lemma B.2 — counting and the transitive G-action.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: Appendix B — The Carlet family C
#
#   Lemma B.1 ([BBK+17, Lemma 4]). For q = 2^k with gcd(k,m) = 1, the number of
#   f = (p₁,p₂,p₃,p₄)_q with p₁ ≠ 0 such that f(x,1) has no root in M is exactly
#       (2^m + 1)·2^m·(2^m − 1)² / 3.
#
#   Lemma B.2. G = M^× × GL(2,M) acts transitively on that set, and the
#   stabilizer of any member has size 3(2^m − 1).
#
# Pseudocode:
#   1. Enumerate every (p₁,p₂,p₃,p₄) with p₁ ≠ 0 and f(x,1) root-free; compare
#      the count with Lemma B.1's formula.
#   2. BFS the G-orbit of one member from a generating set of G; transitivity
#      means the orbit is the whole set.
#   3. Orbit–stabilizer: |Stab| = |G|/|orbit| with |G| = (2^m−1)³(2^m+1)2^m;
#      compare with 3(2^m − 1).
#   4. NEGATIVE CONTROL: the action preserves root-freeness, so a polynomial
#      WITH a root must lie outside the orbit — check that a rooted polynomial
#      is not reached, and that its own orbit is disjoint. Without this the
#      "transitive" test could be passed by an action that moved everything
#      everywhere.
#
# VBF API used: gf_mul/gf_pow (via helpers), print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""
    lemmaB_2_report(io = stdout; m_values = (3, 4), full_search = false) -> NamedTuple

`m = 5` costs ~10⁶ root-freeness tests and is opt-in via `full_search = true`.
"""
function lemmaB_2_report(io::IO = stdout; m_values = (3, 4), full_search::Bool = false)
    print_section("Lemma B.1 / B.2 — root-free biprojectives and the transitive G-action", io)
    ms = full_search ? tuple(m_values..., 5) : m_values
    rows = NamedTuple[]
    count_ok = true
    trans_ok = true
    stab_ok = true
    disjoint_ok = true

    for m in ms
        fld = BiField(m)
        for k = 1:(m-1)
            gcd(k, m) == 1 || continue
            rf = rootfree_biprojectives(fld, k)
            predicted = lemma_b1_count(m)
            length(rf) == predicted || (count_ok = false)

            p0 = BiProj(k, first(rf))
            orb = g_orbit(fld, p0)
            length(orb) == length(rf) || (trans_ok = false)
            Set(rf) == orb || (trans_ok = false)

            stab = g_stabilizer_size(fld, p0)
            stab == 3 * (order(fld) - 1) || (stab_ok = false)

            # ── negative control: a polynomial WITH a root is not in the orbit ──
            rooted = nothing
            for p1 = 1:(order(fld)-1), p2 = 0:(order(fld)-1)
                cand = BiProj(k, (p1, p2, 0, 0))       # f(x,1) = p₁x^{q+1}+p₂x^q has root 0
                if !projective_rootfree(fld, cand)
                    rooted = cand
                    break
                end
            end
            if rooted !== nothing
                rooted.c in orb && (disjoint_ok = false)
                isempty(intersect(g_orbit(fld, rooted), orb)) || (disjoint_ok = false)
            end

            push!(
                rows,
                (;
                    m,
                    k,
                    rootfree = length(rf),
                    predicted,
                    orbit = length(orb),
                    stabilizer = stab,
                    stab_predicted = 3 * (order(fld) - 1),
                ),
            )
            print_kv(
                "m=$m k=$k",
                "root-free=$(length(rf)) (predicted $predicted), orbit=$(length(orb)), " *
                "|Stab|=$stab (predicted $(3 * (order(fld) - 1)))",
                io,
            )
        end
    end

    print_check("Lemma B.1: root-free count = (2^m+1)·2^m·(2^m−1)²/3", count_ok, io)
    print_check("Lemma B.2: G acts transitively (orbit = whole root-free set)", trans_ok, io)
    print_check("Lemma B.2: |Stab_G(f)| = 3(2^m − 1)", stab_ok, io)
    print_check(
        "negative control: a polynomial with a root lies outside the orbit " *
        "(the action preserves root-freeness, so transitivity is not vacuous)",
        disjoint_ok,
        io,
    )
    print_kv("completeness", full_search ? "exhaustive for m ∈ $ms" : "exhaustive for m ∈ $ms (m=5 needs full_search=true)", io)

    (;
        rows = rows,
        count_ok = count_ok,
        transitive_ok = trans_ok,
        stabilizer_ok = stab_ok,
        disjoint_ok = disjoint_ok,
        all_ok = count_ok && trans_ok && stab_ok && disjoint_ok,
    )
end
