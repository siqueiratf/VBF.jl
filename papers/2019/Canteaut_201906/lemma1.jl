# Implements Lemma 1 — Tr(B_{α,β}^τ) = 0 for all α,β ≠ 0
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 3 — Useful Results
#
# Pseudocode:
#   For each (α,β) ≠ 0 with Q_α(β) ≠ 0:
#     λ = α^{q-1} + α^{1-q}         (q = 2^i)
#     Q = α^{q+1} + α^{1-q} + β
#     p = λ / Q
#     B = p^q + p^{q-1}
#     assert Tr(B^τ) = 0
# VBF API used: gf_pow, gf_mul, gf_inv, gf_trace, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    lemma1_build(n, i; modulus) -> NamedTuple

Verify Lemma 1: Tr(B_{α,β}^τ) = 0 for all α,β ≠ 0 with Q_α(β) ≠ 0.
Q_α(β) = α^{q+1} + α^{1-q} + β; zero only when β = β₂ (excluded).
Returns (all_zero, n_pairs, n_counterex).
"""
function lemma1_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    q     = 1 << i
    tau   = tau_exp(n, i)
    qm1   = q - 1                       # 2^i - 1
    one_m_q = (2^n - 1 - qm1) % (2^n - 1)  # 1 - 2^i mod 2^n-1
    qp1   = q + 1                       # 2^i + 1
    n_pairs     = 0
    n_counterex = 0
    for alpha in 1:(1 << n) - 1
        lam    = gf_pow(alpha, qm1, n; modulus) ⊻ gf_pow(alpha, one_m_q, n; modulus)
        aqp1   = gf_pow(alpha, qp1, n; modulus)
        a1mq   = gf_pow(alpha, one_m_q, n; modulus)
        for beta in 1:(1 << n) - 1
            Q = aqp1 ⊻ a1mq ⊻ beta
            Q == 0 && continue          # β = β₂: B undefined
            n_pairs += 1
            p  = gf_mul(lam, gf_inv(Q, n; modulus), n; modulus)
            B  = gf_pow(p, q, n; modulus) ⊻ gf_pow(p, qm1, n; modulus)
            tr = gf_trace(gf_pow(B, tau, n; modulus), n; modulus)
            tr != 0 && (n_counterex += 1)
        end
    end
    (; all_zero = n_counterex == 0, n_pairs, n_counterex)
end

function lemma1_report(io::IO = stdout;
                       cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Lemma 1 — Tr(B_{α,β}^τ) = 0", io)
    for (n, i) in cases
        r = lemma1_build(n, i)
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
