# Implements Theorem 4
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 3 — Another example (Theorem 4 and the substitution link to Theorem 3)
#
# Pseudocode:
#   1. Theorem 4 form: F₄(x,y) = (x^τ·y, G(x,y)) where x^τ = x^{2^{n-2m}},
#      G(x,y) = x^{2^m+1} + a·x·y^{2^m} + b·y^{2^m+1}
#   2. Theorem 3 is obtained from Theorem 4 by substituting x → x^{2^{2m}},
#      which is GF(2ⁿ)-linear, hence F₃ and F₄ are EA-equivalent
#   3. Verify: F₃(half,m,a,b) and F₄(half,m,a,b) share the same EA-mugshot
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
    mod = primitive_polynomial(n)
    # x^τ = x^{2^{n-2m mod n}}; the exponent as an integer power
    τ_exp = 1 << ((n - (2m % n)) % n)
    Em = (1 << m) + 1
    Eym = 1 << m
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:len-1, y = 0:len-1
        xτ = gf_pow(x, τ_exp, n; modulus=mod)
        u = gf_mul(xτ, y, n; modulus=mod)
        v = gf_pow(x, Em, n; modulus=mod) ⊻
            gf_mul(a, gf_mul(x, gf_pow(y, Eym, n; modulus=mod), n; modulus=mod), n; modulus=mod) ⊻
            gf_mul(b, gf_pow(y, Em, n; modulus=mod), n; modulus=mod)
        lut[(x | (y << n)) + 1] = u | (v << n)
    end
    SBox{2n}(lut)
end

"""
    theorem4_verify(; half, m, a, b) -> NamedTuple

For a single admissible (half,m,a,b): verify F₃ and F₄ share the same
apn_ea_mugshot (EA-equivalence via the substitution x→x^{2^{2m}}).
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

Verify EA-equivalence of F₃ and F₄ over all admissible (a,b) with b≠0.
"""
function theorem4_batch_verify(; half::Int=4, m::Int=1)
    n = half
    gcd(m, n) == 1 || error("need gcd(m,n)=1")
    mod = primitive_polynomial(n)
    e = (1 << m) + 1
    pass = 0
    fail = 0
    for a = 0:(1<<n)-1, b = 1:(1<<n)-1
        # only verify on APN instances (P rootless)
        rootless = !any(
            gf_pow(x, e, n; modulus=mod) ⊻ gf_mul(a, x, n; modulus=mod) ⊻ b == 0
            for x = 0:(1<<n)-1
        )
        rootless || continue
        r = theorem4_verify(; half, m, a, b)
        r.ok ? (pass += 1) : (fail += 1)
    end
    (; ok=(fail == 0), pass, fail)
end

function theorem4_report(io::IO = stdout)
    print_section(io, "Theorem 4 — alternate form, EA-equiv to Theorem 3")

    r = theorem4_batch_verify(; half=4, m=1)
    print_check(io, "half=4 m=1: F₃ and F₄ share mugshot for all APN (a,b)", r.ok)
    print_kv(io, "pairs verified", string(r.pass))

    r2 = theorem4_batch_verify(; half=5, m=1)
    print_check(io, "half=5 m=1: F₃ and F₄ share mugshot for all APN (a,b)", r2.ok)
    print_kv(io, "pairs verified", string(r2.pass))
    println(io, "  completeness: exhaustive over all APN (a,b) for half∈{4,5}")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem4_report()
end
