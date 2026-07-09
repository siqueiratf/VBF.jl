# Implements paper-local helpers for the Kaleyski–Nesheim–Stănică (2022) reproduction.
# Paper: Kaleyski, Nesheim, Stănică (2022), "A doubly-infinite family of 0-APN monomials"
# Section: General — shared helpers, GF(2)[x] arithmetic, 0-APN checking
#
# Pseudocode:
#   1. Define e(l,k) = Σ_{j=0}^{l-1} 2^{jk}
#   2. Build derivative polynomial f(x) = x^e + (x+1)^e + 1 in GF(2)[x]
#   3. Count roots in GF(2^n) via gcd(f, x^{2^n}+x) in GF(2)[x]
#   4. Theorem 1 / Remark 1 condition checkers
# VBF API used: gf_pow, gf_mul, primitive_polynomial, print_banner, print_section,
#               print_check, print_kv, status_str

using VBF

# ── Report header ────────────────────────────────────────────────────────────

function print_header(io::IO = stdout)
    print_banner(io,
        "Kaleyski, Nesheim, Stănică (2022)",
        "A doubly-infinite family of 0-APN monomials")
end

# ── Exponent family ──────────────────────────────────────────────────────────

e_exponent(l::Int, k::Int) = sum(1 << (j * k) for j in 0:l-1)

# ── GF(2)[x] polynomial arithmetic (BigInt bit-vectors) ─────────────────────
# Bit i of a BigInt represents the coefficient of x^i.

function gf2poly_deg(a::BigInt)
    a == 0 && return -1
    return ndigits(a, base=2) - 1
end

function gf2poly_square(a::BigInt)
    result = BigInt(0)
    temp = a
    i = 0
    while temp != 0
        if (temp & 1) == 1
            result |= (BigInt(1) << (2i))
        end
        temp >>= 1
        i += 1
    end
    return result
end

function gf2poly_mod(a::BigInt, m::BigInt)
    dm = gf2poly_deg(m)
    r = a
    dr = gf2poly_deg(r)
    while dr >= dm
        r ⊻= m << (dr - dm)
        dr = gf2poly_deg(r)
    end
    return r
end

function gf2poly_gcd(a::BigInt, b::BigInt)
    while b != BigInt(0)
        a, b = b, gf2poly_mod(a, b)
    end
    return a
end

# ── Derivative polynomial ────────────────────────────────────────────────────

function build_derivative_poly(e::Int)
    f = BigInt(1) << e
    for i in 0:e
        if (i & e) == i
            f ⊻= BigInt(1) << i
        end
    end
    f ⊻= BigInt(1)
    return f
end

# ── Root counting in GF(2^n) ────────────────────────────────────────────────

function root_count_in_gf2n(f::BigInt, n::Int)
    df = gf2poly_deg(f)
    df <= 0 && return 0
    h = BigInt(2)
    for _ in 1:n
        h = gf2poly_mod(gf2poly_square(h), f)
    end
    g = gf2poly_gcd(f, h ⊻ BigInt(2))
    return gf2poly_deg(g)
end

# ── 0-APN checkers ──────────────────────────────────────────────────────────

function is_zero_apn_poly(e::Int, n::Int)
    f = build_derivative_poly(e)
    return root_count_in_gf2n(f, n) == 2
end

function is_zero_apn_direct(e::Int, n::Int; modulus::Int = primitive_polynomial(n))
    N = 1 << n
    for x in 2:(N - 1)
        xe = gf_pow(x, e, n; modulus)
        x1e = gf_pow(x ⊻ 1, e, n; modulus)
        if (xe ⊻ x1e ⊻ 1) == 0
            return false
        end
    end
    return true
end

# ── Theorem 1 conditions (corrected) ────────────────────────────────────────

function theorem1_holds(l::Int, k::Int, n::Int)
    gcd(k * l, n) == 1 || return false
    el_1 = e_exponent(l - 1, k)
    gcd(el_1, (big(1) << n) - 1) == 1 || return false
    return true
end

# ── Theorem 1 as printed (buggy — swapped arguments) ───────────────────────

function theorem1_printed(l::Int, k::Int, n::Int)
    gcd(k * l, n) == 1 || return false
    ek = e_exponent(k, l - 1)
    gcd(ek, (big(1) << n) - 1) == 1 || return false
    return true
end

# ── Remark 1 alternative condition ──────────────────────────────────────────

function remark1_holds(l::Int, k::Int, n::Int)
    for i in 2:l
        gcd(i * k, n) == 1 || return false
    end
    return true
end
