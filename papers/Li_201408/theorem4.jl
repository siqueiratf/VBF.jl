# Implements Theorem 4 from Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: §3 — Constructions from the Gold Functions (Theorem 4)
#
# Pseudocode:
#   F(x) = x^{2^i+1} over GF(2^{n+1}), gcd(i, n+1) = 1, u ∈ F*_{2^{n+1}}
#   L_u(x) = ux^{2^i} + u^{2^i}x  (linearization of Gold derivative)
#   H_u = Im(L_u) = {ux^{2^i} + u^{2^i}x | x ∈ GF(2^{n+1})}
#   F_u = L_u ∘ F^{-1} restricted to H_u  (Theorem 2 applied to Gold)
#   Theorem 4 statement:
#     1. F_u is diff-4-uniform perm over F_2^n
#     2. NL(F_u) = 2^{n-1} - 2^{n/2}
#     3. |Λ_{F_u}| = {0, 2^{n/2}, 2^{(n+2)/2}}  (absolute Walsh spectrum)
# VBF API used: gold_apn, SBox, differential_uniformity, is_permutation,
#               absolute_walsh_spectrum

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem4_build(n, i; u=1) -> SBox{n}

Build F_u via the Gold specialization of Theorem 4.
n even, gcd(i, n+1) = 1.
"""
function theorem4_build(n::Int, i::Int; u::Int = 1)
    N = n + 1
    F = gold_apn(N, i)
    fu_lut, _ = build_fu(F.lut, u, N)
    SBox{n}(fu_lut)
end

"""
    theorem4_report(; io=stdout)

§3 Theorem 4: verify Walsh spectrum ⊆ {0, ±2^{n/2}, ±2^{(n+2)/2}} for n=4,6,8.
"""
function theorem4_report(; io::IO = stdout)
    print_section("Theorem 4 — Gold construction, Walsh spectrum", io)

    for (n, i) in [(4, 1), (4, 2), (6, 1), (8, 1), (8, 2), (8, 4)]
        Fu = theorem4_build(n, i; u = 1)
        aws = absolute_walsh_spectrum(Fu)
        half  = 1 << (n ÷ 2)
        half2 = 1 << ((n + 2) ÷ 2)
        allowed = Set([0, half, half2])
        actual_vals = Set(keys(aws.counts))
        ok = issubset(actual_vals, allowed)
        print_check("n=$n i=$i: |Λ|⊆{0,$half,$half2} (got $(sort(collect(actual_vals))))", ok, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem4_report()
end
