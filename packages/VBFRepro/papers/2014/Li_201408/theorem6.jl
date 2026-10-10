# Implements Theorem 6 and Remark 2 from Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: §3 — Constructions from the Gold Functions (Theorem 6 + Remark 2)
#
# Pseudocode:
#   Source (Lemma 4/Budaghyan 2007): m odd, 3|m, gcd(i,m)=1, s = i mod 3
#     F(x) = x^{2^i+1} + Tr_{m/3}(x + x^{2^{2s}})  over GF(2^m)   [AB perm]
#   Theorem 6 construction:
#     G(x) = F(x) + F(x)^{2^i}
#     H = Tr^{(0)} = {x ∈ GF(2^m) | Tr_m(x) = 0}   [dim n = m-1 subspace]
#     F'(x) = restriction of G to H                   [diff-4-uniform perm over F_2^n]
#   Properties:
#     NL(F') = 2^{n-1} - 2^{n/2},  |Λ_{F'}| = {0, 2^{n/2}, 2^{(n+2)/2}}
#     d°(F') = (n+2)/2
#     d°(F'^{-1}) ≤ 7  (proven); = 5 for m=9,15 (Remark 2, Magma)
# VBF API used: SBox, gf_pow, differential_uniformity, is_permutation,
#               linearity, algebraic_degree, absolute_walsh_spectrum

include(joinpath(@__DIR__, "helpers.jl"))

"""
    budaghyan_lut(m, i; modulus) -> Vector{Int}

LUT for F(x) = x^{2^i+1} + Tr_{m/3}(x + x^{2^{2s}}) over GF(2^m),
where s = i mod 3. Requires m odd, 3|m, gcd(i,m)=1.
This is the Budaghyan 2007 AB function (Lemma 4 of Li-Wang 2014).
"""
function budaghyan_lut(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    m % 3 == 0 || throw(ArgumentError("budaghyan_lut: m=$m must be divisible by 3"))
    gcd(i, m) == 1 || throw(ArgumentError("budaghyan_lut: gcd(i,m) must be 1, got gcd($i,$m)"))
    s = i % 3
    k = m ÷ 3
    exp_gold = invmod((1 << i) + 1, (1 << m) - 1)   # (2^i+1)^{-1} mod (2^m-1)
    exp_frob = 1 << (2s)
    q = 1 << m
    lut = Vector{Int}(undef, q)
    for x in 0:q-1
        gold_x = gf_pow(x, exp_gold, m; modulus = modulus)
        x_frob = gf_pow(x, exp_frob, m; modulus = modulus)
        tr_val = gf_relative_trace(x ⊻ x_frob, m, k; modulus = modulus)
        lut[x+1] = gold_x ⊻ tr_val
    end
    lut
end

"""
    theorem6_build(m, i; modulus) -> SBox{m-1}

Build F' from Theorem 6: F'(x) = (F(x) + F(x)^{2^i}) restricted to Tr^{(0)},
where F is the Budaghyan function over GF(2^m). Returns an (m-1)-bit SBox.
"""
function theorem6_build(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    n = m - 1
    F_lut = budaghyan_lut(m, i; modulus = modulus)
    frob_exp = 1 << i
    G_lut = [F_lut[x+1] ⊻ gf_pow(F_lut[x+1], frob_exp, m; modulus = modulus)
             for x in 0:(1<<m)-1]
    H = tr0_subspace(m; modulus = modulus)
    fp_lut = make_nbit_lut(G_lut, H)
    SBox{n}(fp_lut)
end

"""
    theorem6_report(; io=stdout)

§3 Theorem 6 + Remark 2: verify construction for m=9 (n=8), i=1.
Checks: AB source, diff-4-uniform perm, NL, Walsh spectrum, d°(F'), d°(F'^{-1}).
"""
function theorem6_report(; io::IO = stdout)
    print_section("Theorem 6 + Remark 2 — Budaghyan source, m=9 (n=8)", io)

    m = 9
    n = m - 1
    i = 1

    # Verify source F is AB permutation
    F_lut = budaghyan_lut(m, i)
    F_src = SBox{m}(F_lut)
    perm_src = is_permutation(F_src)
    du_src   = differential_uniformity(F_src)
    lin_src  = linearity(F_src)
    ab_expected_lin = 1 << ((m + 1) ÷ 2)  # 2^5 = 32 for m=9
    print_check("source F: permutation", perm_src, io)
    print_check("source F: APN (diff_unif = 2, got $du_src)", du_src == 2, io)
    print_check("source F: AB (linearity = $ab_expected_lin, got $lin_src)",
        lin_src == ab_expected_lin, io)

    # Theorem 6 construction
    F_prime = theorem6_build(m, i)
    perm = is_permutation(F_prime)
    du   = differential_uniformity(F_prime)
    nl_expected = (1 << (n-1)) - (1 << (n÷2))
    nl_actual   = (1 << (n-1)) - linearity(F_prime) ÷ 2
    aws = absolute_walsh_spectrum(F_prime)
    half  = 1 << (n ÷ 2)
    half2 = 1 << ((n + 2) ÷ 2)
    walsh_ok = issubset(Set(keys(aws.counts)), Set([0, half, half2]))

    print_check("F' (n=$n, m=$m): permutation", perm, io)
    print_check("F' (n=$n): diff_unif = 4 (got $du)", du == 4, io)
    print_check("F' (n=$n): NL = $nl_expected (got $nl_actual)", nl_actual == nl_expected, io)
    print_check("F' (n=$n): |Λ|⊆{0,$half,$half2}", walsh_ok, io)

    # Algebraic degree (Theorem 6.3)
    deg_fwd = algebraic_degree(F_prime)
    deg_expected = (n + 2) ÷ 2
    print_check("F' (n=$n): d°(F') = $deg_expected (got $deg_fwd)", deg_fwd == deg_expected, io)

    # Remark 2: d°(F'^{-1}) = 5 for m=9 (Magma verified; ≤7 proven)
    F_prime_inv = compositional_inverse(F_prime)
    deg_inv = algebraic_degree(F_prime_inv)
    print_check("Remark 2: d°(F'^{-1}) = 5 for m=9 (got $deg_inv)", deg_inv == 5, io)
    print_check("Theorem 6.3: d°(F'^{-1}) ≤ 7 (got $deg_inv)", deg_inv <= 7, io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_report()
end
