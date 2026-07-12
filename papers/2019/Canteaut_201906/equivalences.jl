# Implements Section 2.2 — Equivalence relations between generalised butterflies
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 2.2 — Equivalence Relations
#
# Pseudocode:
#   Frobenius relation (justifies squaring α, β):
#     ∀ x,y: R_{α²,β²}(x², y²) = (R_{α,β}(x, y))²
#   β ↔ β′ relation (justifies the β₁-only sweep in Prop 5), α ≠ 1:
#     β′ = β⁻¹(1+α)^{2(2^i+1)},  L(x,y) = (αx+y, x+αy),  m = β(1+α)^{-2(2^i+1)}
#     ∀ x,y: R_{α,β}(x, y) = m · R_{α,β′}(L(x, y))
#     (the paper's display absorbs the scalar β into the outer affine map)
#   Mirror of the β pair: β₂ = β₁⁻¹(1+α)^{2(2^i+1)} for all α ≠ 0,1
# VBF API used: gf_mul, gf_pow, gf_inv, primitive_polynomial, beta_pair (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    frobenius_equiv_check(n, i, alpha, beta; modulus) -> Bool

Verify pointwise that R_{α²,β²}(x²,y²) = (R_{α,β}(x,y))² for all x,y,
the identity behind the affine equivalence V_{α,β} ≅ V_{α²,β²}.
(Checking one component over all (x,y) covers both, since the second
component is the first with swapped arguments.)
"""
function frobenius_equiv_check(n::Int, i::Int, alpha::Int, beta::Int;
                               modulus::Int = primitive_polynomial(n))
    e = (1 << i) + 1
    sq(v) = gf_mul(v, v, n; modulus)
    R(a, b, x, y) = gf_pow(x ⊻ gf_mul(a, y, n; modulus), e, n; modulus) ⊻
                    gf_mul(b, gf_pow(y, e, n; modulus), n; modulus)
    a2, b2 = sq(alpha), sq(beta)
    all(0:(1 << n) - 1) do x
        all(0:(1 << n) - 1) do y
            sq(R(alpha, beta, x, y)) == R(a2, b2, sq(x), sq(y))
        end
    end
end

"""
    beta_prime_equiv_check(n, i, alpha, beta; modulus) -> Bool

Verify pointwise the affine equivalence V_{α,β} ≅ V_{α,β′} for α ≠ 1:
R_{α,β}(x,y) = m · R_{α,β′}(L(x,y)) with L(x,y) = (αx+y, x+αy),
β′ = β⁻¹(1+α)^{2(2^i+1)} and scalar m = β(1+α)^{-2(2^i+1)}.
"""
function beta_prime_equiv_check(n::Int, i::Int, alpha::Int, beta::Int;
                                modulus::Int = primitive_polynomial(n))
    e  = (1 << i) + 1
    R(b, x, y) = gf_pow(x ⊻ gf_mul(alpha, y, n; modulus), e, n; modulus) ⊻
                 gf_mul(b, gf_pow(y, e, n; modulus), n; modulus)
    t  = gf_pow(1 ⊻ alpha, 2 * e, n; modulus)                 # (1+α)^{2(2^i+1)}
    bp = gf_mul(gf_inv(beta, n; modulus), t, n; modulus)      # β′
    m  = gf_mul(beta, gf_inv(t, n; modulus), n; modulus)      # β(1+α)^{-2(2^i+1)}
    all(0:(1 << n) - 1) do x
        all(0:(1 << n) - 1) do y
            z1 = gf_mul(alpha, x, n; modulus) ⊻ y
            z2 = x ⊻ gf_mul(alpha, y, n; modulus)
            R(beta, x, y) == gf_mul(m, R(bp, z1, z2), n; modulus)
        end
    end
end

"""
    equivalences_build(n, i; modulus) -> NamedTuple

Sweep the Section 2.2 equivalence identities:
- Frobenius identity over all α ≠ 0, β ≠ 0 (α = 1 included);
- β ↔ β′ identity over all α ≠ 0,1, β ≠ 0;
- mirror relation β₂ = β₁⁻¹(1+α)^{2(2^i+1)} over all α ≠ 0,1.
Returns (; n, i, frob_ok, bprime_ok, mirror_ok, n_frob, n_bprime).
"""
function equivalences_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    len = 1 << n
    e   = (1 << i) + 1
    frob_ok   = true
    bprime_ok = true
    mirror_ok = true
    n_frob    = 0
    n_bprime  = 0
    for alpha in 1:len-1
        for beta in 1:len-1
            n_frob += 1
            frobenius_equiv_check(n, i, alpha, beta; modulus) || (frob_ok = false)
            if alpha != 1
                n_bprime += 1
                beta_prime_equiv_check(n, i, alpha, beta; modulus) || (bprime_ok = false)
            end
        end
        if alpha != 1
            b1, b2 = beta_pair(n, i, alpha; modulus)
            t = gf_pow(1 ⊻ alpha, 2 * e, n; modulus)
            b2 == gf_mul(gf_inv(b1, n; modulus), t, n; modulus) || (mirror_ok = false)
        end
    end
    (; n, i, frob_ok, bprime_ok, mirror_ok, n_frob, n_bprime)
end

function equivalences_report(io::IO = stdout;
                             cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Section 2.2 — Equivalence relations V_{α,β}≅V_{α²,β²}, β↔β′", io)
    for (n, i) in cases
        r = equivalences_build(n, i)
        print_check(io,
            "n=$n i=$i: Frobenius identity (V_{α,β} ≅ V_{α²,β²}, $(r.n_frob) pairs)",
            r.frob_ok)
        print_check(io,
            "n=$n i=$i: β↔β′ identity (V_{α,β} ≅ V_{α,β′}, $(r.n_bprime) pairs)",
            r.bprime_ok)
        print_check(io,
            "n=$n i=$i: mirror relation β₂ = β₁⁻¹(1+α)^{2(2^i+1)}",
            r.mirror_ok)
    end
    print_kv(io, "completeness",
             "exhaustive over F_{2^n}, all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    equivalences_report()
end
