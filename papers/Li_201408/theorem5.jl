# Implements Theorem 5 from Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: §3 — Constructions from the Gold Functions (Theorem 5)
#
# Pseudocode:
#   F_u'(x) = restriction of L_u(F^{-1}(x)) + x to H_u  [= F_u(x) + x over H_u]
#   EA-equivalent to F_u (Theorem 4 construction), so diff-4-uniform with same NL.
#   Additional properties (vs Theorem 4):
#     d°(F_u') = (n+2)/2                (same as F_u, Theorem 5.3)
#     d°(F_u'^{-1}) = (n+2)/2           (improved: Prop 2 gives F_u^{-1} only ≤3)
#   The paper gives d°(F_u'^{-1}) = 5 for n=8 (= (8+2)/2 = 5).
# VBF API used: gold_apn, SBox, differential_uniformity, is_permutation,
#               algebraic_degree, linearity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem5_build(n, i; u=1) -> SBox{n}

Build F_u' from Theorem 5 using Gold(n+1, i) as source.
"""
function theorem5_build(n::Int, i::Int; u::Int = 1)
    N = n + 1
    F = gold_apn(N, i)
    fu_prime_lut, _ = build_fu_prime(F.lut, u, N)
    SBox{n}(fu_prime_lut)
end

"""
    theorem5_report(; io=stdout)

§3 Theorem 5: verify diff-4-uniform, NL, d°(F_u') = (n+2)/2,
d°(F_u'^{-1}) = (n+2)/2 for n = 4, 6, 8.
"""
function theorem5_report(; io::IO = stdout)
    print_section("Theorem 5 — Modified construction F_u', degree of inverse", io)

    for (n, i) in [(4, 1), (6, 1), (8, 1)]
        N = n + 1
        F = gold_apn(N, i)
        fu_prime_lut, _ = build_fu_prime(F.lut, 1, N)
        Fu_prime = SBox{n}(fu_prime_lut)
        Fu_prime_inv = sbox_inverse(Fu_prime)

        perm = is_permutation(Fu_prime)
        du   = differential_uniformity(Fu_prime)
        nl_expected = (1 << (n-1)) - (1 << (n÷2))
        nl_actual   = (1 << (n-1)) - linearity(Fu_prime) ÷ 2
        deg_fwd = algebraic_degree(Fu_prime)
        deg_inv = algebraic_degree(Fu_prime_inv)
        deg_expected = (n + 2) ÷ 2

        print_check("n=$n i=$i: perm", perm, io)
        print_check("n=$n i=$i: diff_unif = 4 (got $du)", du == 4, io)
        print_check("n=$n i=$i: NL = $nl_expected (got $nl_actual)", nl_actual == nl_expected, io)
        print_check("n=$n i=$i: d°(F_u') = $deg_expected (got $deg_fwd)", deg_fwd == deg_expected, io)
        print_check("n=$n i=$i: d°(F_u'^{-1}) = $deg_expected (got $deg_inv)", deg_inv == deg_expected, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem5_report()
end
