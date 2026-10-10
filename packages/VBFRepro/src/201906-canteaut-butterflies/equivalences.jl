# Implements Section 2.2 — Equivalence relations between generalised butterflies
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 2.2 — Equivalence Relations
#
# Pseudocode:
#   Exponent relation (bullet 1) — e = (2^i+1)·2^t is affine-equivalent to e = 2^i+1:
#     ∀ x,y: R^{(t)}_{α,β}(x, y) = R_{α^{2^t},β}(x^{2^t}, y^{2^t})     [input Frobenius]
#            R^{(t)}_{α,β}(x, y) = (R_{α,β^{2^{-t}}}(x, y))^{2^t}      [output Frobenius]
#     hence V^{(t)}_{α,β} = V_{α^{2^t},β} ∘ Φ_t with Φ_t(x,y) = (x^{2^t}, y^{2^t}) linear
#   Frobenius relation (justifies squaring α, β):
#     ∀ x,y: R_{α²,β²}(x², y²) = (R_{α,β}(x, y))²
#   β ↔ β′ relation (justifies the β₁-only sweep in Prop 5), α ≠ 1:
#     β′ = β⁻¹(1+α)^{2(2^i+1)},  L(x,y) = (αx+y, x+αy),  m = β(1+α)^{-2(2^i+1)}
#     ∀ x,y: R_{α,β}(x, y) = m · R_{α,β′}(L(x, y))
#     (the paper's display absorbs the scalar β into the outer affine map)
#   Mirror of the β pair: β₂ = β₁⁻¹(1+α)^{2(2^i+1)} for all α ≠ 0,1
# VBF API used: gf_mul, gf_pow, gf_inv, primitive_polynomial, differential_uniformity,
#               beta_pair / butterfly_closed_lut (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    butterfly_exponent_lut(n, i, t, alpha, beta; modulus) -> SBox{2n}

The closed butterfly built with the twisted exponent e = (2^i+1)·2^t, i.e.
R^{(t)}(x,y) = (x + αy)^{(2^i+1)2^t} + β y^{(2^i+1)2^t}.
"""
function butterfly_exponent_lut(n::Int, i::Int, t::Int, alpha::Int, beta::Int;
                                modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    et  = mod(((1 << i) + 1) * (1 << t), 2^n - 1)
    len = 1 << n
    R(x, y) = gf_pow(x ⊻ gf_mul(alpha, y, n; modulus), et, n; modulus) ⊻
              gf_mul(beta, gf_pow(y, et, n; modulus), n; modulus)
    lut = Vector{Int}(undef, 1 << (2 * n))
    for x in 0:len-1, y in 0:len-1
        lut[(x | (y << n)) + 1] = R(x, y) | (R(y, x) << n)
    end
    SBox{2 * n}(lut)
end

"""
    exponent_equiv_check(n, i, t, alpha, beta; modulus) -> (input_ok, output_ok)

Section 2.2, first bullet: the closed butterfly with exponent (2^i+1)·2^t is
affine-equivalent to one with exponent 2^i+1.  Two exact pointwise identities
witness it (both are checked over all (x,y)):

- input Frobenius:  R^{(t)}_{α,β}(x,y) = R_{α^{2^t},β}(x^{2^t}, y^{2^t})
- output Frobenius: R^{(t)}_{α,β}(x,y) = (R_{α,β^{2^{-t}}}(x,y))^{2^t}

Either way the twisting map is linear and acts coordinate-wise, so the closed
butterflies are affine-equivalent.

Caveat (paper imprecision, see P2 in README): the tex says the partner has "the
same α, β".  It does not — the partner is (α^{2^t}, β) or, equivalently after
applying bullet 2 t times, (α, β^{2^{-t}}).  The literal reading is false: at
n=3, i=1, t=1 there are (α,β) with DU(V^{(t)}_{α,β}) ≠ DU(V_{α,β}), and DU is an
affine invariant.  The paper's *conclusion* ("all results also hold for exponent
(2^i+1)·2^t") is nonetheless correct, because its statements are quantified over
all α, β and the family is closed under the twist.
"""
function exponent_equiv_check(n::Int, i::Int, t::Int, alpha::Int, beta::Int;
                              modulus::Int = primitive_polynomial(n))
    M   = 2^n - 1
    e   = (1 << i) + 1
    et  = mod(e * (1 << t), M)
    frob(v)  = gf_pow(v, 1 << t, n; modulus)                       # v ↦ v^{2^t}
    ifrob(v) = gf_pow(v, 1 << ((n - t) % n), n; modulus)           # v ↦ v^{2^{-t}}
    Rt(x, y) = gf_pow(x ⊻ gf_mul(alpha, y, n; modulus), et, n; modulus) ⊻
               gf_mul(beta, gf_pow(y, et, n; modulus), n; modulus)
    R(a, b, x, y) = gf_pow(x ⊻ gf_mul(a, y, n; modulus), e, n; modulus) ⊻
                    gf_mul(b, gf_pow(y, e, n; modulus), n; modulus)
    a_tw = frob(alpha)                                             # α^{2^t}
    b_tw = ifrob(beta)                                             # β^{2^{-t}}
    input_ok  = true
    output_ok = true
    for x in 0:(1 << n) - 1, y in 0:(1 << n) - 1
        Rt(x, y) == R(a_tw, beta, frob(x), frob(y)) || (input_ok = false)
        Rt(x, y) == frob(R(alpha, b_tw, x, y))      || (output_ok = false)
    end
    (input_ok, output_ok)
end

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
- exponent identity (bullet 1) for every twist t ∈ {0,…,n-1}, all α,β ≠ 0;
- Frobenius identity over all α ≠ 0, β ≠ 0 (α = 1 included);
- β ↔ β′ identity over all α ≠ 0,1, β ≠ 0;
- mirror relation β₂ = β₁⁻¹(1+α)^{2(2^i+1)} over all α ≠ 0,1.
Returns
(; n, i, expo_in_ok, expo_out_ok, frob_ok, bprime_ok, mirror_ok,
   n_expo, n_frob, n_bprime).
"""
function equivalences_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    len = 1 << n
    e   = (1 << i) + 1
    expo_in_ok  = true
    expo_out_ok = true
    frob_ok   = true
    bprime_ok = true
    mirror_ok = true
    n_expo    = 0
    n_frob    = 0
    n_bprime  = 0
    for alpha in 1:len-1
        for beta in 1:len-1
            n_frob += 1
            frobenius_equiv_check(n, i, alpha, beta; modulus) || (frob_ok = false)
            for t in 0:n-1
                n_expo += 1
                in_ok, out_ok = exponent_equiv_check(n, i, t, alpha, beta; modulus)
                in_ok  || (expo_in_ok = false)
                out_ok || (expo_out_ok = false)
            end
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
    (; n, i, expo_in_ok, expo_out_ok, frob_ok, bprime_ok, mirror_ok,
       n_expo, n_frob, n_bprime)
end

"""
    exponent_du_build(n, i; modulus) -> NamedTuple

The differential-uniformity consequence of bullet 1, at the SBox level: for every
twist t and every α,β ≠ 0,

    DU(V^{(t)}_{α,β}) == DU(V_{α^{2^t},β})     (the corrected partner)

while the tex's literal "same α, β" reading fails for t ≠ 0.  `n_literal_mismatch`
counts the (t,α,β) with DU(V^{(t)}_{α,β}) ≠ DU(V_{α,β}); it is 0 at t=0 and
strictly positive at t=1 (see P2 in README).
Returns (; n, i, n_cases, du_twisted_ok, n_literal_mismatch, literal_ok_t0).
"""
function exponent_du_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    len = 1 << n
    n_cases            = 0
    du_twisted_ok      = true
    n_literal_mismatch = 0
    literal_ok_t0      = true
    for t in 0:n-1, alpha in 1:len-1, beta in 1:len-1
        n_cases += 1
        du_t = differential_uniformity(butterfly_exponent_lut(n, i, t, alpha, beta; modulus))
        du_p = differential_uniformity(
            butterfly_closed_lut(n, i, gf_pow(alpha, 1 << t, n; modulus), beta; modulus))
        du_0 = differential_uniformity(butterfly_closed_lut(n, i, alpha, beta; modulus))
        du_t == du_p || (du_twisted_ok = false)
        if du_t != du_0
            n_literal_mismatch += 1
            t == 0 && (literal_ok_t0 = false)
        end
    end
    (; n, i, n_cases, du_twisted_ok, n_literal_mismatch, literal_ok_t0)
end

function equivalences_report(io::IO = stdout;
                             cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Section 2.2 — Equivalence relations: exponent 2^t twist, V_{α,β}≅V_{α²,β²}, β↔β′", io)
    for (n, i) in cases
        r = equivalences_build(n, i)
        print_check(io,
            "n=$n i=$i: exponent identity (2^i+1)·2^t ≅ 2^i+1, both Frobenius forms ($(r.n_expo) cases)",
            r.expo_in_ok && r.expo_out_ok)
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
    d = exponent_du_build(3, 1)
    print_check(io,
        "n=3 i=1: DU(V^{(t)}_{α,β}) = DU(V_{α^{2^t},β}) for all t,α,β ($(d.n_cases) cases)",
        d.du_twisted_ok)
    print_kv(io, "P2 (paper)",
             "tex says the exponent twist keeps \"the same α, β\"; it keeps β but sends " *
             "α ↦ α^{2^t}. $(d.n_literal_mismatch)/$(d.n_cases) cases at n=3,i=1 have " *
             "DU(V^{(t)}_{α,β}) ≠ DU(V_{α,β}), so the literal reading is false " *
             "(the paper's conclusion still holds — see README)")
    print_kv(io, "completeness",
             "exhaustive over F_{2^n}, all t ∈ {0..n-1}, all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    equivalences_report()
end
