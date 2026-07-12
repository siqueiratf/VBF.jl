# Implements Theorem 4
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 3 — Another example (Theorem 4 and the substitution link to Theorem 3)
#
# Pseudocode:
#   1. Theorem 4 form: F₄(x,y) = (x^τ·y, G(x,y)) where x^τ = x^{2^{-2m}},
#      G(x,y) = x^{2^m+1} + a·x·y^{2^m} + b·y^{2^m+1}
#   2. The paper: "Theorem 3 is obtained from Theorem 4 by the substitution
#      x ↦ x^{2^{2m}}" — an EXACT identity, not merely an equivalence:
#         F₃(x, y) = F₄(x^{2^{2m}}, y)   for every (x, y) and every (a, b)
#      Indeed (x^{2^{2m}})^τ = x and (x^{2^{2m}})^{2^m+1} = x^{2^{3m}+2^{2m}},
#      which is exactly Theorem 3's G.
#   3. x ↦ x^{2^{2m}} is a GF(2)-linear bijection, so F₃ and F₄ are EA-equivalent;
#      the equal-mugshot check is the (necessary-only) corollary of the identity.
# VBF API used: taniguchi_apn, apn_ea_mugshot, differential_uniformity,
#               gf_pow, gf_mul, primitive_polynomial, SBox

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

"""
    taniguchi_thm4(half, m, a, b) -> SBox{2·half}

Theorem 4 form: F(x,y) = (x^{2^{n-2m mod n}}·y, x^{2^m+1}+a·x·y^{2^m}+b·y^{2^m+1}).
APN iff P(x)=x^{2^m+1}+ax+b has no root (same condition as Theorem 3).
Input/output packed as (x|(y<<n)) and (u|(v<<n)) respectively.
"""
function taniguchi_thm4(half::Int, m::Int, a::Int, b::Int)
    n = half
    gcd(m, n) == 1 || error("need gcd(m,n)=1, got m=$m n=$n")
    b != 0 || error("b must be nonzero")
    modl = primitive_polynomial(n)
    # x^τ = x^{2^{n-2m mod n}}; the exponent as an integer power
    τ_exp = 1 << ((n - (2m % n)) % n)
    Em = (1 << m) + 1
    Eym = 1 << m
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:len-1, y = 0:len-1
        xτ = gf_pow(x, τ_exp, n; modulus=modl)
        u = gf_mul(xτ, y, n; modulus=modl)
        v = gf_pow(x, Em, n; modulus=modl) ⊻
            gf_mul(a, gf_mul(x, gf_pow(y, Eym, n; modulus=modl), n; modulus=modl), n; modulus=modl) ⊻
            gf_mul(b, gf_pow(y, Em, n; modulus=modl), n; modulus=modl)
        lut[(x | (y << n)) + 1] = u | (v << n)
    end
    SBox{2n}(lut)
end

"""
    theorem4_substitution_identity(; half, m, a, b, twist=2m) -> Bool

The paper's actual claim, as an exact LUT identity:

    F₃(x, y) == F₄(x^{2^{2m}}, y)   for every (x, y) ∈ GF(2^half)²

This is strictly stronger than "F₃ and F₄ have equal `apn_ea_mugshot`" (a
necessary-only condition), and it is meaningful for **every** (a,b) — APN or not —
whereas the mugshot is only defined on the quadratic-APN members.

`twist` is the exponent `e` in the substitution `x ↦ x^{2^e}`; it defaults to the
paper's `2m` and exists so the tests can aim the check at a *wrong* substitution and
watch it fail. (A substitution identity that held for every exponent would be
telling us nothing.)
"""
function theorem4_substitution_identity(;
    half::Int,
    m::Int,
    a::Int,
    b::Int,
    twist::Int = 2m,
)
    n = half
    modl = primitive_polynomial(n)
    F3 = taniguchi_apn(n, m, a, b)
    F4 = taniguchi_thm4(n, m, a, b)
    sub = 1 << (twist % n)   # the Frobenius has order n, so the exponent reduces mod n
    for x = 0:(1<<n)-1, y = 0:(1<<n)-1
        xs = gf_pow(x, sub, n; modulus=modl)
        F3.lut[(x | (y << n)) + 1] == F4.lut[(xs | (y << n)) + 1] || return false
    end
    true
end

"""
    theorem4_identity_verify(; half, m) -> NamedTuple

Check the exact substitution identity over **all** (a,b) with b≠0 — the APN members
and the non-APN members alike.
"""
function theorem4_identity_verify(; half::Int=4, m::Int=1)
    n = half
    gcd(m, n) == 1 || error("need gcd(m,n)=1")
    pass = 0
    fail = 0
    for a = 0:(1<<n)-1, b = 1:(1<<n)-1
        theorem4_substitution_identity(; half, m, a, b) ? (pass += 1) : (fail += 1)
    end
    (; ok=(fail == 0), pass, fail)
end

"""
    theorem4_verify(; half, m, a, b) -> NamedTuple

For a single admissible (half,m,a,b): verify F₃ and F₄ share the same
apn_ea_mugshot (the EA-equivalence implied by the substitution x→x^{2^{2m}}).
"""
function theorem4_verify(; half::Int=4, m::Int=1, a::Int, b::Int)
    F3 = taniguchi_apn(half, m, a, b)
    F4 = taniguchi_thm4(half, m, a, b)
    apn3 = differential_uniformity(F3) == 2
    apn4 = differential_uniformity(F4) == 2
    same_apn = apn3 == apn4
    # EA-mugshot only defined for quadratic APN; only compare when both are APN
    if apn3 && apn4
        mg3 = apn_ea_mugshot(F3)
        mg4 = apn_ea_mugshot(F4)
        (; ok=mg3 == mg4, apn3, apn4, same_mugshot=(mg3 == mg4))
    else
        (; ok=same_apn, apn3, apn4, same_mugshot=nothing)
    end
end

"""
    theorem4_batch_verify(; half, m) -> NamedTuple

Verify equal mugshots of F₃ and F₄ over all admissible (APN) (a,b) with b≠0.
"""
function theorem4_batch_verify(; half::Int=4, m::Int=1)
    n = half
    gcd(m, n) == 1 || error("need gcd(m,n)=1")
    pass = 0
    fail = 0
    for a = 0:(1<<n)-1, b = 1:(1<<n)-1
        projective_polynomial_rootless(n, m, a, b) || continue  # APN members only
        r = theorem4_verify(; half, m, a, b)
        r.ok ? (pass += 1) : (fail += 1)
    end
    (; ok=(fail == 0), pass, fail)
end

function theorem4_report(io::IO = stdout)
    print_section(io, "Theorem 4 — F₃(x,y) = F₄(x^{2^{2m}}, y), the exact substitution")

    for (half, m) in [(4, 1), (4, 3), (5, 1), (5, 2)]
        r = theorem4_identity_verify(; half, m)
        print_check(io,
            "half=$half m=$m: LUT identity F₃(x,y)=F₄(x^{2^{2m}},y) for all $(r.pass) (a,b)",
            r.ok)
    end

    print_section(io, "Theorem 4 — EA-equivalence corollary (mugshot)")
    for (half, m) in [(4, 1), (5, 1)]
        r = theorem4_batch_verify(; half, m)
        print_check(io, "half=$half m=$m: F₃ and F₄ share a mugshot on all $(r.pass) APN (a,b)", r.ok)
    end
    println(io, "  completeness: the identity is exhaustive over ALL (a,b), APN or not,")
    println(io, "  for (half,m) ∈ {(4,1),(4,3),(5,1),(5,2)}; the mugshot corollary is")
    println(io, "  exhaustive over the APN members at half∈{4,5}, m=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem4_report()
end
