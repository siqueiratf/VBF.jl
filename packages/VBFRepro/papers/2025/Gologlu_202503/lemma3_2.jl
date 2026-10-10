# Implements Lemma 3.2 — the gcd identities underpinning family F₄.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: 3.1 — Family F₄
#
#   Lemma 3.2. Let gcd(k, m) = 1 and r = qQ (q = 2^k, Q = 2^{m/2}, m ≡ 2 mod 4).
#   Then
#     (i)  gcd(q+1, 2^m−1) = gcd(r−1, 2^m−1) = gcd(q²−1, 2^m−1) = 3
#     (ii) gcd(q−1, 2^m−1) = gcd(r+1, 2^m−1) = gcd(q+1, Q−1) = 1
#
# Pseudocode:
#   1. For every m ≡ 2 (mod 4) in range and every k with gcd(k,m)=1:
#        compute the six gcds and compare with (3,3,3,1,1,1).
#   2. Negative control: drop the hypothesis gcd(k,m)=1 and show the identities
#      genuinely fail — otherwise the lemma would carry no information.
#   3. Also record gcd(k + m/2, m) = 2, used in the proof and again in Thm 5.1.
#
# All gcds are integer gcds of exponents against 2^m − 1; the field never enters.
#
# VBF API used: print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""
    lemma3_2_gcds(m, k) -> NamedTuple

The six gcds of Lemma 3.2 for `q = 2^k`, `r = 2^{k+m/2}` on `M = F_{2^m}`.
Exponents are taken as integers; `2^m − 1` is the group order of `M^×`.
"""
function lemma3_2_gcds(m::Integer, k::Integer)
    v = (1 << m) - 1
    q = 1 << k
    Q = 1 << (m ÷ 2)
    r = q * Q
    (;
        gcd_qp1 = gcd(q + 1, v),
        gcd_rm1 = gcd(r - 1, v),
        gcd_q2m1 = gcd(q * q - 1, v),
        gcd_qm1 = gcd(q - 1, v),
        gcd_rp1 = gcd(r + 1, v),
        gcd_qp1_Qm1 = gcd(q + 1, Q - 1),
        gcd_kQ_m = gcd(k + m ÷ 2, m),
    )
end

"""Does `(m, k)` satisfy all of Lemma 3.2's claimed values?"""
function lemma3_2_holds(m::Integer, k::Integer)
    g = lemma3_2_gcds(m, k)
    g.gcd_qp1 == 3 &&
        g.gcd_rm1 == 3 &&
        g.gcd_q2m1 == 3 &&
        g.gcd_qm1 == 1 &&
        g.gcd_rp1 == 1 &&
        g.gcd_qp1_Qm1 == 1
end

"""
    lemma3_2_report(io = stdout; max_m = 22) -> NamedTuple

Check Lemma 3.2 over every `m ≡ 2 (mod 4)` with `2 < m ≤ max_m` and every
admissible `k`, plus the inadmissible `k` (`gcd(k,m) ≠ 1`) as negative control.
"""
function lemma3_2_report(io::IO = stdout; max_m::Int = 22)
    print_section("Lemma 3.2 — gcd identities for q = 2^k, r = qQ", io)
    ms = [m for m = 6:4:max_m]                       # m ≡ 2 (mod 4), m > 2
    good = 0
    bad = String[]
    coprime_kQm_ok = true
    for m in ms, k = 1:(m-1)
        gcd(k, m) == 1 || continue
        if lemma3_2_holds(m, k)
            good += 1
        else
            push!(bad, "m=$m k=$k → $(lemma3_2_gcds(m,k))")
        end
        # the proof's auxiliary fact gcd(k + m/2, m) = 2
        lemma3_2_gcds(m, k).gcd_kQ_m == 2 || (coprime_kQm_ok = false)
    end

    # ── negative control: without gcd(k,m)=1 the identities are false ────────
    counterexamples = Tuple{Int,Int}[]
    for m in ms, k = 1:(m-1)
        gcd(k, m) == 1 && continue
        lemma3_2_holds(m, k) || push!(counterexamples, (m, k))
    end
    n_bad_k = sum(length([k for k = 1:(m-1) if gcd(k, m) != 1]) for m in ms)

    print_kv("m values (m ≡ 2 mod 4, 2 < m ≤ $max_m)", join(ms, ", "), io)
    print_kv("admissible (m,k) pairs checked", good + length(bad), io)
    print_check("all six gcd identities hold for every admissible (m,k)", isempty(bad), io)
    print_check("auxiliary fact gcd(k + m/2, m) = 2 (proof of Lemma 3.2)", coprime_kQm_ok, io)
    print_check(
        "negative control: every k with gcd(k,m) ≠ 1 breaks the identities " *
        "($(length(counterexamples))/$n_bad_k)",
        length(counterexamples) == n_bad_k && n_bad_k > 0,
        io,
    )
    for b in bad
        println(io, "    [FAIL] ", b)
    end
    print_kv("completeness", "exhaustive over m ≤ $max_m", io)
    (;
        m_values = ms,
        admissible_checked = good + length(bad),
        failures = bad,
        negative_controls = n_bad_k,
        all_ok = isempty(bad) && coprime_kQm_ok && length(counterexamples) == n_bad_k && n_bad_k > 0,
    )
end
