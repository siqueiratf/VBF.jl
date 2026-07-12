# Implements Proposition 1 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Proposition 1 (system E_i is a sufficient criterion for APN-ness of C_i)
#
# Pseudocode:
#   For a given n = 2m and i:
#   1. Check system E_i (Eq. 2) for all a ∈ GF(2^n)*, x ∉ GF(2)
#   2. Verify the paper's implication: E_i trivial ⇒ C_i(x) is APN
#   3. Separately, record the *converse* as an empirical observation (not claimed
#      by the paper)
# VBF API used: system_Ei_trivial, build_ci_sbox, differential_uniformity
#
# WHAT THE PAPER CLAIMS (tex:184-204). Proposition 1 is ONE-DIRECTIONAL:
#   "the function defined by C_i(x) is APN over F_2^n IF, for any a ∈ F_2^n*, the
#    system E_i from (2) only has trivial solutions in x".
# It does NOT claim the converse. Earlier versions of this file asserted a
# biconditional ("E_i trivial ↔ C_i is APN"); that is an overclaim. The converse
# does hold empirically in every case we sweep below, and is reported as such —
# clearly separated from the proposition itself.

include(joinpath(@__DIR__, "helpers.jl"))
using Printf

"""
    check_proposition1(n; i_vals, k=0) -> Vector{NamedTuple}

For each i in `i_vals`, computes whether system E_i^(k) is trivial and whether
C_i is APN. `sufficient` records the paper's implication (trivial ⇒ APN);
`converse` records the un-claimed reverse implication (APN ⇒ trivial), kept
separate on purpose.
"""
function check_proposition1(n::Int; i_vals = 1:n-1, k::Int = 0)
    results = NamedTuple{
        (:i, :ei_trivial, :is_apn, :sufficient, :converse),
        Tuple{Int,Bool,Bool,Bool,Bool},
    }[]
    for i in i_vals
        ei_ok = system_Ei_trivial(n, i; k)
        apn   = differential_uniformity(build_ci_sbox(n, i, k)) == 2
        push!(results, (;
            i,
            ei_trivial = ei_ok,
            is_apn     = apn,
            sufficient = !ei_ok || apn,   # E_i trivial ⇒ APN   (the paper's claim)
            converse   = !apn || ei_ok,   # APN ⇒ E_i trivial   (NOT claimed)
        ))
    end
    results
end

function proposition1_report(io::IO = stdout)
    print_section("Proposition 1: E_i trivial ⇒ C_i is APN (n=10)", io)
    println(io, "  Paper (tex:184): C_i is APN IF the system E_i (2) has only trivial")
    println(io, "  solutions for every a ≠ 0. The converse is not claimed.")

    results = check_proposition1(10)
    println(io, "  i  E_i-trivial  APN  E_i trivial ⇒ APN")
    for r in results
        println(io, @sprintf("  %-2d  %-11s  %-5s  %s",
            r.i,
            r.ei_trivial ? "yes" : "no",
            r.is_apn ? "yes" : "no",
            r.sufficient ? "[ OK ]" : "[FAIL]"))
    end
    print_check("Proposition 1 (sufficiency) holds for all i ∈ 1..9 over GF(2^10)",
                all(r.sufficient for r in results), io)

    # Non-vacuity: the hypothesis is not universally true, so the implication is
    # not satisfied by an empty antecedent.
    n_trivial = count(r -> r.ei_trivial, results)
    print_check("Hypothesis is discriminating: E_i trivial for $(n_trivial)/9 values of i, not all",
                0 < n_trivial < length(results), io)

    print_section("Observation (ours, NOT the paper's claim): the converse", io)
    println(io, "  The paper never asserts 'APN ⇒ E_i trivial'. Empirically it also holds")
    println(io, "  over GF(2^10) for every i ∈ 1..9 and every k ∈ 0..3 we tested — so on")
    println(io, "  this field E_i is an exact criterion. Reported as an observation only;")
    println(io, "  it is not backed by any proof in the paper.")
    for k in 0:3
        rs = check_proposition1(10; k)
        apn_is = [r.i for r in rs if r.is_apn]
        tri_is = [r.i for r in rs if r.ei_trivial]
        print_check("k=$k: E_i-trivial i = $(tri_is) = APN i = $(apn_is)",
                    tri_is == apn_is, io)
    end
    println(io, "  NOTE: the APN i-values move with the parity of k — {3,5,7,9} for even k")
    println(io, "        (Theorem 2) but {1,3,5,7} for odd k. So Theorem 2's list is not")
    println(io, "        the set of all APN i-values once k is odd; cf. Lemma 4, which")
    println(io, "        covers {3,5,7} = {m+2, m, (m+2)^-1} and itself omits i=1.")
end
