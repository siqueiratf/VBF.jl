# Implements Lemma 1 — Tr(B_{α,β}^τ) = 0 for all α,β ≠ 0
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 3 — Useful Results
#
# Pseudocode:
#   q = 2^i
#   For each (α,β) ≠ 0 with Q_α(β) ≠ 0:
#     λ = α^{q-1} + α^{1-q}
#     Q = α^{q+1} + α^{1-q} + β
#     B_stmt = (α + α^{2q-1})^{q-1} · (α^{2q+1} + α^{2q-1} + α^q β)
#                                   / (α^{2q²+q} + α^q + α^{q²} β^q)   [Lemma 1 statement]
#     B_mid  = λ^{q-1} · (λ + Q) / Q^q                                 [proof, middle step]
#     B_simp = p^q + p^{q-1},  p = λ/Q                                 [proof, final form]
#     assert B_stmt = B_mid = B_simp
#     assert Tr(B_simp^τ) = 0
#
# The whole point of Lemma 1 is the algebraic collapse of the statement formula
# into p^q + p^{q-1}; evaluating only the collapsed form would assume the very
# chain the lemma asserts.  All three forms are therefore evaluated and compared.
#
# The denominator of the statement formula factors as α^{2^{2i}} · Q_α(β)^{2^i}
# (tex, second line of the proof), so it vanishes exactly when Q_α(β) = 0, i.e.
# β = β₂ — the pairs the lemma excludes and which are skipped here.
# VBF API used: gf_pow, gf_mul, gf_inv, gf_trace, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    lemma1_B(n, i, alpha, beta; modulus) -> (B_stmt, B_mid, B_simp)

The three forms of B_{α,β} along the Lemma 1 proof chain: the formula as
*stated* in the lemma, the middle form λ^{q-1}(λ+Q)/Q^q, and the simplified
form p^q + p^{q-1} with p = λ/Q.  Requires Q_α(β) ≠ 0.
"""
function lemma1_B(n::Int, i::Int, alpha::Int, beta::Int;
                  modulus::Int = primitive_polynomial(n))
    q   = 1 << i
    M   = 2^n - 1
    pw(x, k) = gf_pow(x, mod(k, M), n; modulus)          # exponents live mod 2^n-1
    ml(x, y) = gf_mul(x, y, n; modulus)
    iv(x)    = gf_inv(x, n; modulus)

    lam = pw(alpha, q - 1) ⊻ pw(alpha, 1 - q)            # λ_α
    Q   = pw(alpha, q + 1) ⊻ pw(alpha, 1 - q) ⊻ beta     # Q_α(β)
    Q == 0 && throw(ArgumentError("lemma1_B: Q_α(β) = 0 (β = β₂), B undefined"))

    # Lemma 1 as stated:
    #   (α + α^{2^{i+1}-1})^{2^i-1} × (α^{2^{i+1}+1} + α^{2^{i+1}-1} + α^{2^i} β)
    #                               / (α^{2^{2i+1}+2^i} + α^{2^i} + α^{2^{2i}} β^{2^i})
    pref = pw(alpha ⊻ pw(alpha, 2 * q - 1), q - 1)
    num  = pw(alpha, 2 * q + 1) ⊻ pw(alpha, 2 * q - 1) ⊻ ml(pw(alpha, q), beta)
    den  = pw(alpha, 2 * q * q + q) ⊻ pw(alpha, q) ⊻ ml(pw(alpha, q * q), pw(beta, q))
    B_stmt = ml(pref, ml(num, iv(den)))

    # proof, middle step: λ^{q-1} (λ + Q) / Q^q
    B_mid = ml(pw(lam, q - 1), ml(lam ⊻ Q, iv(pw(Q, q))))

    # proof, final form: p^q + p^{q-1}
    p = ml(lam, iv(Q))
    B_simp = pw(p, q) ⊻ pw(p, q - 1)

    (B_stmt, B_mid, B_simp)
end

"""
    lemma1_build(n, i; modulus) -> NamedTuple

Verify Lemma 1 for all α,β ≠ 0 with Q_α(β) ≠ 0 (Q_α(β) = α^{q+1} + α^{1-q} + β
is zero only when β = β₂, where B is undefined):

- the *statement* formula, the middle form and the simplified form all agree;
- Tr(B_{α,β}^τ) = 0.

Returns (; all_zero, forms_agree, n_pairs, n_counterex, n_form_mismatch).
"""
function lemma1_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    tau = tau_exp(n, i)
    q   = 1 << i
    M   = 2^n - 1
    n_pairs         = 0
    n_counterex     = 0
    n_form_mismatch = 0
    for alpha in 1:(1 << n) - 1, beta in 1:(1 << n) - 1
        Q = gf_pow(alpha, q + 1, n; modulus) ⊻
            gf_pow(alpha, mod(1 - q, M), n; modulus) ⊻ beta
        Q == 0 && continue                  # β = β₂: B undefined
        n_pairs += 1
        B_stmt, B_mid, B_simp = lemma1_B(n, i, alpha, beta; modulus)
        (B_stmt == B_simp && B_mid == B_simp) || (n_form_mismatch += 1)
        tr = gf_trace(gf_pow(B_stmt, tau, n; modulus), n; modulus)
        tr != 0 && (n_counterex += 1)
    end
    (; all_zero     = n_counterex == 0,
       forms_agree  = n_form_mismatch == 0,
       n_pairs, n_counterex, n_form_mismatch)
end

function lemma1_report(io::IO = stdout;
                       cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Lemma 1 — Tr(B_{α,β}^τ) = 0", io)
    for (n, i) in cases
        r = lemma1_build(n, i)
        print_check(io,
            "n=$n i=$i: statement formula = λ^{q-1}(λ+Q)/Q^q = p^q+p^{q-1} ($(r.n_pairs) pairs)",
            r.forms_agree)
        print_check(io,
            "n=$n i=$i: Tr(B^τ)=0 for all (α,β)≠0 with Q_α(β)≠0 ($(r.n_pairs) pairs)",
            r.all_zero)
    end
    print_kv(io, "completeness",
             "exhaustive over F_{2^n}, all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    lemma1_report()
end
