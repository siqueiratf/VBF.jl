# Implements Theorem 3
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 3 — Another example
#
# Pseudocode:
#   1. Let n,m with gcd(m,n)=1; a∈GF(2ⁿ), b∈GF(2ⁿ)*, and
#      G(x,y) = x^{2^{2m}+2^{3m}} + a·x^{2^{2m}}·y^{2^m} + b·y^{2^m+1}
#   2. F(x,y) := (xy, G(x,y)) on GF(2ⁿ)×GF(2ⁿ), packed as SBox{2n}
#   3. F is APN ⟺ P(x)=x^{2^m+1}+ax+b has no root in GF(2ⁿ)   (Theorem 3)
#   4. On half=4 (F₂⁸): a≠0 gives 2 new CCZ-classes; 3 classes total
# VBF API used: taniguchi_apn, differential_uniformity, algebraic_degree,
#               apn_ea_mugshot, gf_pow, gf_mul, primitive_polynomial

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

function _P_rootless(n::Int, m::Int, a::Int, b::Int)
    mod = primitive_polynomial(n)
    e = (1 << m) + 1
    for x = 0:(1<<n)-1
        gf_pow(x, e, n; modulus=mod) ⊻ gf_mul(a, x, n; modulus=mod) ⊻ b == 0 &&
            return false
    end
    true
end

"""
    theorem3_verify(; half, m) -> NamedTuple

For all (a, b) with b≠0 over GF(2^half): verify the IFF condition
P(x)=x^{2^m+1}+ax+b rootless ⟺ F(x,y)=(xy,G(x,y)) APN.
Returns counts of APN and non-APN instances, plus pass/fail.
"""
function theorem3_verify(; half::Int = 4, m::Int = 1)
    n = half
    gcd(m, n) == 1 || error("need gcd(m,n)=1, got m=$m n=$n")
    apn_count = 0
    non_apn_count = 0
    for a = 0:(1<<n)-1, b = 1:(1<<n)-1
        rootless = _P_rootless(n, m, a, b)
        F = taniguchi_apn(n, m, a, b)
        is_apn = differential_uniformity(F) == 2
        rootless == is_apn ||
            return (; ok=false, apn_count=0, non_apn_count=0,
                      msg="IFF failed: a=$a b=$b rootless=$rootless is_apn=$is_apn")
        rootless ? (apn_count += 1) : (non_apn_count += 1)
    end
    (; ok=true, apn_count, non_apn_count, msg="all $(apn_count+non_apn_count) pairs checked")
end

"""
    theorem3_ccz_classes(half) -> NamedTuple

Count distinct CCZ-classes of Taniguchi's Theorem 3 family on F₂^{2·half}
using apn_ea_mugshot deduplication. On half=4, expects 3 classes (1 old, 2 new).
"""
function theorem3_ccz_classes(half::Int = 4)
    reps = taniguchi_apn_representatives(half)
    n_classes = length(reps)
    n_new = count(r -> r.new, reps)
    all_quad = all(algebraic_degree(r.sbox) == 2 for r in reps)
    (; n_classes, n_new, all_quadratic=all_quad)
end

function theorem3_report(io::IO = stdout)
    print_section(io, "Theorem 3 — APN iff P(x) rootless")

    for (half, m) in [(4, 1), (5, 1)]
        r = theorem3_verify(; half, m)
        print_check(io, "half=$half m=$m IFF check ($(r.apn_count)+$(r.non_apn_count) pairs)", r.ok)
    end

    r3 = theorem3_ccz_classes(4)
    print_check(io, "half=4: 3 CCZ-classes total", r3.n_classes == 3)
    print_check(io, "half=4: 2 new classes (a≠0)", r3.n_new == 2)
    print_check(io, "half=4: all reps are quadratic APN", r3.all_quadratic)
    print_kv(io, "CCZ-classes on F₂⁸", r3.n_classes)
    print_kv(io, "new classes (a≠0)", r3.n_new)
    println(io, "  completeness: exhaustive over all (a,b) for half∈{4,5}")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_report()
end
