# Implements Proposition 2 from Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: §3 — Constructions from the Gold Functions (Proposition 2)
#
# Pseudocode:
#   F_u from Theorem 4 (Gold source, n even, gcd(i,n+1)=1)
#   Claim: d°(F_u^{-1}) ≤ 3
#   The explicit inverse formula (proof of Prop 2, using L(x) = Σ x^{2^{(2j+1)i}}):
#     F_1^{-1}(x) = L(x)^{2^i+1}·Tr(L(x)^{2^i+1}+1) + (L(x)+1)^{2^i+1}·Tr(L(x)^{2^i+1})
#   is degree ≤ 3. Verified here computationally via algebraic_degree(inverse).
# VBF API used: gold_apn, SBox, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition2_report(; io=stdout)

§3 Proposition 2: verify d°(F_u^{-1}) ≤ 3 for Gold-based construction.
"""
function proposition2_report(; io::IO = stdout)
    print_section("Proposition 2 — alg degree of F_u^{-1} ≤ 3", io)

    for (n, i) in [(4, 1), (4, 2), (6, 1), (6, 2), (8, 1), (8, 2), (8, 4)]
        N = n + 1
        F = gold_apn(N, i)
        fu_lut, _ = build_fu(F.lut, 1, N)
        Fu = SBox{n}(fu_lut)
        Fu_inv = compositional_inverse(Fu)
        got = algebraic_degree(Fu_inv)
        ok = got <= 3
        print_check("n=$n i=$i: d°(F_u^{-1}) ≤ 3 (got $got)", ok, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition2_report()
end
