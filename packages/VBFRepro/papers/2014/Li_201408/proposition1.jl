# Implements Proposition 1 from Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: §3 — Constructions from the Gold Functions (Proposition 1)
#
# Pseudocode:
#   F_u from Theorem 4 (Gold source, n even, gcd(i,n+1)=1)
#   Claim: d°(F_u) = (n+2)/2
#   Proof uses Lemma 2 (algebraic degree via Möbius criterion) and Lemma 3
#   (no exponent collision d + 2^{k1} = 2^i·d + 2^{k2} mod 2^{n+1}-1).
#   Verified here computationally via algebraic_degree(Fu).
# VBF API used: gold_apn, SBox, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition1_report(; io=stdout)

§3 Proposition 1: verify d°(F_u) = (n+2)/2 for Gold-based construction.
"""
function proposition1_report(; io::IO = stdout)
    print_section("Proposition 1 — alg degree of F_u = (n+2)/2", io)

    for (n, i) in [(4, 1), (4, 2), (6, 1), (6, 2), (8, 1), (8, 2), (8, 4)]
        N = n + 1
        F = gold_apn(N, i)
        fu_lut, _ = build_fu(F.lut, 1, N)
        Fu = SBox{n}(fu_lut)
        expected = (n + 2) ÷ 2
        got = algebraic_degree(Fu)
        print_check("n=$n i=$i: d°(F_u) = $expected (got $got)", got == expected, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition1_report()
end
