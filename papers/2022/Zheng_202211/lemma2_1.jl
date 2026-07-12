# Implements Lemma 2.1: APN characterization via subfield-valued trace components.
# Paper: Zheng, Kan, Li, Peng, Tang (2022), "Constructing new APN functions through
#        relative trace functions", arXiv:2101.11535v1 [cs.IT]
# Section: 2 — Preliminaries / Lemma 2.1
#
# Pseudocode:
#   For f_s(x) = a·Tr_m^n(bx³) + a^q·Tr_m^n(cx^{2^s+1}) with f_s(0) = 0:
#   Define bilinear form B_s(x,u) = f_s(x+u) + f_s(x) + f_s(u)
#   Then B_s(x,u) = a·P(x,u) + a^q·Q(x,u) where:
#     P(x,u) = Tr_m^n(b·(x²u + xu²)) ∈ F_{2^m}
#     Q(x,u) = Tr_m^n(c·(x^{2^s}u + xu^{2^s})) ∈ F_{2^m}
#   Since a+a^q = Tr(a) ≠ 0 (a ∉ F_{2^m}): B_s(x,u)=0 ⟺ P=0 AND Q=0
#   f_s is APN ⟺ ∀u≠0: B_s(x,u)=0 has no solutions x ∉ {0,u}
# VBF API used: gf_mul, gf_pow, primitive_polynomial, differential_uniformity, SBox

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

"""
    bilinear_components(x, u, m, s, b, c; modulus) -> (P, Q)

Compute the F_{2^m}-valued components (P, Q) of the bilinear form B_s(x,u):
  P = Tr_m^n(b·(x²u + xu²))   = b(x²u+xu²) ⊻ b^q(x^{2q}u^q + x^qu^{2q})
  Q = Tr_m^n(c·(x^{2^s}u + xu^{2^s})) = c(x^{2^s}u+xu^{2^s}) ⊻ c^q((x^q)^{2^s}u^q + x^q(u^q)^{2^s})

Both values lie in F_{2^m} (image of Tr_m^n).  B_s(x,u) = a·P + a^q·Q is zero
iff P = Q = 0, because a ∉ F_{2^m} implies a+a^q = Tr(a) ≠ 0.
"""
function bilinear_components(x::Int, u::Int, m::Int, s::Int, b::Int, c::Int;
                              modulus::Int = primitive_polynomial(2m))
    n  = 2m
    q  = 1 << m
    x2 = gf_mul(x, x, n; modulus)
    u2 = gf_mul(u, u, n; modulus)
    ip = gf_mul(b, gf_mul(x2, u, n; modulus) ⊻ gf_mul(x, u2, n; modulus), n; modulus)
    P  = ip ⊻ gf_pow(ip, q, n; modulus)
    xs = gf_pow(x, 1 << s, n; modulus)
    us = gf_pow(u, 1 << s, n; modulus)
    iq = gf_mul(c, gf_mul(xs, u, n; modulus) ⊻ gf_mul(x, us, n; modulus), n; modulus)
    Q  = iq ⊻ gf_pow(iq, q, n; modulus)
    P, Q
end

"""
    lemma2_1_is_apn(m, s, b, c; modulus, limit) -> (is_apn::Bool, exhaustive::Bool)

Check the Lemma 2.1 APN criterion: for each u∈F_{2^n}* (up to `limit` values),
verify that B_s(x,u)=0 has no solutions x ∉ {0,u}.

Uses precomputed field tables (sq, pow_s, Frobenius, multiply-by-constant) to
avoid redundant gf_pow calls in the inner loop.

Returns (is_apn, exhaustive): `exhaustive=false` when fewer than 2^n-1 u values
were tested (budget-limited run).
"""
function lemma2_1_is_apn(m::Int, s::Int, b::Int, c::Int;
                          modulus::Int = primitive_polynomial(2m),
                          limit::Int   = typemax(Int))
    n  = 2m
    N  = 1 << n
    q  = 1 << m

    sq_lut    = [gf_mul(x, x, n; modulus) for x in 0:N-1]
    pow_s_lut = [gf_pow(x, 1 << s, n; modulus) for x in 0:N-1]
    frob_lut  = [gf_pow(x, q, n; modulus) for x in 0:N-1]

    bq     = frob_lut[b+1]
    cq     = frob_lut[c+1]
    mul_b  = [gf_mul(b,  v, n; modulus) for v in 0:N-1]
    mul_bq = [gf_mul(bq, v, n; modulus) for v in 0:N-1]
    mul_c  = [gf_mul(c,  v, n; modulus) for v in 0:N-1]
    mul_cq = [gf_mul(cq, v, n; modulus) for v in 0:N-1]

    n_checked = 0
    @inbounds for u in 1:min(N - 1, limit)
        uq  = frob_lut[u+1]
        u2  = sq_lut[u+1]
        u2q = sq_lut[uq+1]
        us  = pow_s_lut[u+1]
        usq = pow_s_lut[uq+1]

        for x in 1:N-1
            x == u && continue
            xq  = frob_lut[x+1]
            x2  = sq_lut[x+1]
            x2q = sq_lut[xq+1]
            xs  = pow_s_lut[x+1]
            xsq = pow_s_lut[xq+1]

            # P = b*(x²u + xu²) + bq*(x^{2q}uq + xq*u^{2q})
            t1 = gf_mul(x2, u, n; modulus) ⊻ gf_mul(x, u2, n; modulus)
            t2 = gf_mul(x2q, uq, n; modulus) ⊻ gf_mul(xq, u2q, n; modulus)
            P  = mul_b[t1+1] ⊻ mul_bq[t2+1]

            # Q = c*(x^{2^s}u + xu^{2^s}) + cq*((xq)^{2^s}uq + xq*(uq)^{2^s})
            t3 = gf_mul(xs, u, n; modulus) ⊻ gf_mul(x, us, n; modulus)
            t4 = gf_mul(xsq, uq, n; modulus) ⊻ gf_mul(xq, usq, n; modulus)
            Q  = mul_c[t3+1] ⊻ mul_cq[t4+1]

            if P == 0 && Q == 0
                return false, false
            end
        end
        n_checked += 1
    end
    return true, n_checked >= N - 1
end

"""
    lemma2_1_report(io::IO = stdout; m, a, b, limit) -> NamedTuple

Verify Lemma 2.1 APN characterization for F15 at n=2m and cross-check
with `differential_uniformity`. Prints a structured report.
"""
function lemma2_1_report(io::IO = stdout;
                          m::Int    = 5,
                          a::Int    = 2,
                          b::Int    = 2,
                          limit::Int = typemax(Int))
    n       = 2m
    modulus = primitive_polynomial(n)
    c       = gf_pow(b, 3, n; modulus)
    s       = 3

    print_section("Lemma 2.1 — APN via subfield trace components (n=$(n))", io)
    print_kv("n", n, io)
    print_kv("m", m, io)
    print_kv("s", s, io)
    print_kv("b", b, io)
    print_kv("c (= b³)", c, io)
    limit < (1 << n) - 1 && print_kv("limit (u values)", limit, io)

    lemma_apn, exhaustive = lemma2_1_is_apn(m, s, b, c; modulus, limit)
    scope = exhaustive ? "exhaustive" : "budget-limited ($(limit) u values)"
    print_check("B_s(x,u)=0 only at x∈{0,u} — APN criterion [$(scope)]", lemma_apn, io)

    F      = f15_sbox(m; a, b, modulus)
    du     = differential_uniformity(F)
    du_apn = du == 2
    print_check("differential_uniformity == 2", du_apn, io)
    print_kv("differential_uniformity", du, io)

    agree = lemma_apn == du_apn
    print_check("lemma2_1 agrees with differential_uniformity", agree, io)

    (; lemma_apn, exhaustive, du, du_apn, agree)
end
