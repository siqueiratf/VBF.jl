# Implements Lemma 4 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Lemma 4 (tex:433): the odd-k system
#
# Lemma 4: let k be odd. Then the system (17)
#
#   a^3(x^2+x) ∈ β·GF(2^m)   and   (a^(2^i+1)(x^(2^i)+x))^(2^k) ∈ β·GF(2^m)
#
# has only trivial solutions for i ∈ {m+2, m, (m+2)^{-1} mod n}.
#
# Note the contrast with Theorem 2 (even k): the list is {m+2, m, (m+2)^{-1}},
# NOT {m-2, m, (m-2)^{-1}, n-1}. In particular i = n-1 is ABSENT — the paper says
# so explicitly at tex:446 ("When k is odd, the case of i = n−1 does allow
# non-trivial solutions"). See corollary1.jl: Corollary 1 item 8 nonetheless
# lists (i = n−1, k odd) as APN, which is a paper erratum.
#
# Pseudocode:
#   1. Compute the three Lemma 4 i-values for n = 2m
#   2. For each odd k, verify system E_i^(k) has only trivial solutions
#   3. Verify the resulting C_i is APN
#   4. Verify i = n-1 does NOT satisfy the lemma (non-trivial solutions exist)
# VBF API used: system_Ei_trivial, build_ci_sbox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    lemma4_i_values(n) -> Vector{Pair{Symbol,Int}}

The three i-values of Lemma 4 (odd k) for n = 2m, m odd, 3 ∤ m:
i ∈ {m+2, m, (m+2)^{-1} mod n}.
"""
function lemma4_i_values(n::Int)
    m = n ÷ 2
    (m % 2 == 0 || m % 3 == 0) && error("Lemma 4 requires m=$m odd and 3 ∤ m")
    [
        :case1 => mod(m + 2, n),         # i = m+2
        :case2 => m,                     # i = m
        :case3 => invmod(m + 2, n),      # i = (m+2)^{-1} mod n
    ]
end

function lemma4_report(io::IO = stdout; n::Int = 10, ks = (1, 3))
    m = n ÷ 2
    print_section("Lemma 4: odd k — trivial E_i solutions for i ∈ {m+2, m, (m+2)^-1} (n=$n)", io)

    pairs = lemma4_i_values(n)
    for k in ks
        isodd(k) || error("Lemma 4 is about odd k, got k=$k")
        for (label, i) in pairs
            ei_ok = system_Ei_trivial(n, i; k)
            apn   = differential_uniformity(build_ci_sbox(n, i, k)) == 2
            print_check("k=$k $(label): i=$i → E_i^(k) trivial=$(ei_ok), C_i APN=$(apn)",
                        ei_ok && apn, io)
        end
    end

    # Tightness / non-vacuity: i = n-1 is in Theorem 2's even-k list but is
    # explicitly excluded here (tex:446), and it really does fail for odd k.
    print_section("Lemma 4 excludes i = n−1 (tex:446) — and that exclusion is real", io)
    for k in ks
        i = n - 1
        ei_ok = system_Ei_trivial(n, i; k)
        du    = differential_uniformity(build_ci_sbox(n, i, k))
        print_check("k=$k: i=n-1=$i has NON-trivial E_i^(k) solutions (and du=$du ≠ 2)",
                    !ei_ok && du != 2, io)
    end
end
