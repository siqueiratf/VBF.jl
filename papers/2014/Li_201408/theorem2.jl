# Implements Theorem 2 and Theorem 3 from Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: §2 — A General Construction (Theorems 2 and 3)
#
# Pseudocode (Theorem 2):
#   Given: F quadratic APN perm over GF(2^{n+1}) with F(0)=0; u ∈ F*_{2^{n+1}}
#   1. L_u(x) = F(x) ⊕ F(x⊕u) ⊕ F(u)  [linear, ker = {0,u}, n-dim image H_u]
#   2. G(y) = L_u(F^{-1}(y)) for y ∈ GF(2^{n+1})
#   3. F_u = restriction of G to H_u  [diff-4-uniform perm over F_2^n]
# Theorem 3: NL(F_u) = 2^{n-1} - 2^{n/2}  (best known nonlinearity for even n)
# VBF API used: gold_apn, SBox, differential_uniformity, is_permutation, linearity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem2_build(n, i; u=1) -> SBox{n}

Build F_u from Theorem 2 using Gold(n+1, i) as source APN permutation.
n must be even, gcd(i, n+1) = 1.
"""
function theorem2_build(n::Int, i::Int; u::Int = 1)
    N = n + 1
    F = gold_apn(N, i)
    fu_lut, _ = build_fu(F.lut, u, N)
    SBox{n}(fu_lut)
end

"""
    theorem2_report(; io=stdout)

§2: Verify Theorem 2 (diff-4-uniform perm) and Theorem 3 (NL = 2^{n-1} - 2^{n/2})
for Gold-sourced constructions over n = 4, 6, 8.
"""
function theorem2_report(; io::IO = stdout)
    print_section("Theorem 2 + 3 — General construction, Gold source", io)

    for (n, i) in [(4, 1), (6, 1), (8, 1)]
        N = n + 1
        Fu = theorem2_build(n, i; u = 1)
        perm = is_permutation(Fu)
        du   = differential_uniformity(Fu)
        nl_expected = (1 << (n-1)) - (1 << (n÷2))
        nl_actual   = (1 << (n-1)) - linearity(Fu) ÷ 2

        print_kv("n=$n, i=$i: is_perm", perm, io)
        print_check("n=$n diff_unif = 4 (got $du)", du == 4, io)
        print_check("n=$n NL = $nl_expected (got $nl_actual)", nl_actual == nl_expected, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem2_report()
end
