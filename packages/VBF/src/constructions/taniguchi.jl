"""
Taniguchi's family of quadratic APN functions — Taniguchi, "On some quadratic
APN functions" (Designs, Codes and Cryptography, 2019).

Carlet's construction `F(x, y) = (B(x, y), G(x, y))` with the bent function
`B(x, y) = x·y` turns a suitable `G` over `GF(2ⁿ) × GF(2ⁿ)` into an APN function
on `GF(2ⁿ)² ≅ F₂^{2n}`. Taniguchi's family (Theorem 3) takes, for integers `m`
with `gcd(m, n) = 1` and coefficients `a ∈ GF(2ⁿ)`, `b ∈ GF(2ⁿ)∖{0}`,

    G(x, y) = x^{2^{2m}+2^{3m}} + a·x^{2^{2m}}·y^{2^m} + b·y^{2^m+1},

so that `F(x, y) = (x·y, G(x, y))` is APN **if and only if** the projective
polynomial `P(x) = x^{2^m+1} + a·x + b` has no root in `GF(2ⁿ)`.

With `a = 0` the function falls into the earlier Zhou–Pott family; the `a ≠ 0`
members give the genuinely new classes. On `F₂⁸` the family has three CCZ-classes
(Tan19's Γ-ranks 13642 / 13700 / 13798) — the `a = 0` one and the two new ones;
see [`taniguchi_apn_representatives`](@ref).

`(x, y)` is packed as `x | (y << n)` on input and `(x·y) | (G(x,y) << n)` on
output, yielding an `SBox{2n}`. The half-field representation only fixes a basis;
APN-ness and the EA/CCZ class are independent of that choice.
"""

"""
    taniguchi_apn(half, m, a, b; modulus=primitive_polynomial(half)) -> SBox{2·half}

One member of Taniguchi's family (Theorem 3) over `GF(2^half) × GF(2^half)`,
packed into an `SBox{2·half}`. Requires `gcd(m, half) = 1` and `b ≠ 0`. The
result is APN iff `P(x) = x^{2^m+1} + a·x + b` has no root in `GF(2^half)`
([`taniguchi_apn_representatives`](@ref) enumerates the admissible, APN members).
"""
function taniguchi_apn(half::Integer, m::Integer, a::Integer, b::Integer;
                       modulus::Integer = primitive_polynomial(half))
    n = Int(half); mod = Int(modulus); mm = Int(m); A = Int(a); B = Int(b)
    n ≥ 1 || throw(ArgumentError("taniguchi_apn: half-dimension must be ≥ 1, got $half"))
    gcd(mm, n) == 1 || throw(ArgumentError("taniguchi_apn: need gcd(m, $n) = 1, got m = $m"))
    B != 0 || throw(ArgumentError("taniguchi_apn: b must be nonzero"))
    E1 = (1 << (2mm)) + (1 << (3mm))       # exponent of the y-free term
    E2 = 1 << (2mm)                        # x-exponent of the mixed term
    Ey = 1 << mm                           # y-exponent of the mixed term
    E3 = (1 << mm) + 1                      # exponent of the y^(2^m+1) term
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x in 0:len - 1, y in 0:len - 1
        u = gf_mul(x, y, n; modulus = mod)
        v = gf_pow(x, E1, n; modulus = mod) ⊻
            gf_mul(gf_mul(A, gf_pow(x, E2, n; modulus = mod), n; modulus = mod),
                   gf_pow(y, Ey, n; modulus = mod), n; modulus = mod) ⊻
            gf_mul(B, gf_pow(y, E3, n; modulus = mod), n; modulus = mod)
        lut[(x | (y << n)) + 1] = u | (v << n)
    end
    SBox{2n}(lut)
end

# P(x) = x^(2^m+1) + a·x + b has no root in GF(2^half) — the APN admissibility
# condition of Theorem 3 (and b ≠ 0).
function _taniguchi_admissible(half::Integer, m::Integer, a::Integer, b::Integer;
                               modulus::Integer = primitive_polynomial(half))
    n = Int(half); mod = Int(modulus); A = Int(a); B = Int(b)
    B == 0 && return false
    e = (1 << Int(m)) + 1
    for x in 0:(1 << n) - 1
        gf_pow(x, e, n; modulus = mod) ⊻ gf_mul(A, x, n; modulus = mod) ⊻ B == 0 && return false
    end
    true
end

"""
    taniguchi_apn_representatives(half; modulus=primitive_polynomial(half))
        -> Vector{@NamedTuple{m::Int, a::Int, b::Int, new::Bool, sbox::SBox{2half}}}

The distinct CCZ-classes of Taniguchi's family on `F₂^{2·half}`, one representative
each (deduplicated by [`apn_ea_mugshot`](@ref), the ortho-derivative EA-invariant
that separates quadratic-APN classes). Enumerates every admissible `(m, a, b)`
(`gcd(m, half)=1`, `b ≠ 0`, `P` rootless), keeps the quadratic-APN members, and
tags `new = (a ≠ 0)`. On `half = 4` this returns the three classes of Tan19 — one
old (`a = 0`, Zhou–Pott) and the two new (`a ≠ 0`) ones.
"""
function taniguchi_apn_representatives(half::Integer;
                                       modulus::Integer = primitive_polynomial(half))
    n = Int(half); mod = Int(modulus)
    reps = NamedTuple[]
    seen = Set{APNEAMugshot}()
    for m in 1:n - 1
        gcd(m, n) == 1 || continue
        for a in 0:(1 << n) - 1, b in 1:(1 << n) - 1
            _taniguchi_admissible(n, m, a, b; modulus = mod) || continue
            F = taniguchi_apn(n, m, a, b; modulus = mod)
            (differential_uniformity(F) == 2 && algebraic_degree(F) == 2) || continue
            mg = apn_ea_mugshot(F)
            mg in seen && continue
            push!(seen, mg)
            push!(reps, (m = m, a = a, b = b, new = (a != 0), sbox = F))
        end
    end
    reps
end
