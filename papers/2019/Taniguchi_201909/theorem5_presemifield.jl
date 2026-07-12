# Implements Theorem 5 (presemifield) and Lemma 2
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 4 — Related presemifields on F_{p^n}
#
# Pseudocode:
#   Setting: F=GF(2⁴), K=GF(2²), σ(x)=x^4 (Frobenius of F over K), [F:K]=2
#   Conditions:
#     P(x) = x^{σ+1}+ax+b = x^5+ax+b has no root in F   (b≠0)
#     N_{F/K}(α) = α^5 ≠ 1   (α∈F*)
#   Lemma 2: x ∘_α y = x^σ·y + α·x·y^σ; if x∘_α y=0 then x=0 or y=0
#   Theorem 5: multiplication * defined by Eq.(3) makes (F×F,+,*) a presemifield:
#     (x,s)*(y,t) = ((x∘_α y)^{σ²}+a(x^σt+αy^σs)^σ+b(s∘_α t),  xt+ys)
#     [σ²=id for [F:K]=2, so (x∘_α y)^{σ²} = x∘_α y in GF(2⁴)]
#   Verify: for all nonzero (x,s),(y,t)∈F×F, (x,s)*(y,t)≠(0,0)
# VBF API used: gf_pow, gf_mul, primitive_polynomial

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

const _T5_N = 4   # |F|=2⁴=16
const _T5_K = 2   # |K|=2²=4; [F:K]=2
const _T5_MOD = primitive_polynomial(_T5_N)

# σ(x)=x^{2^k}=x^4 in GF(2⁴)/GF(2²)
_σ(x::Int)  = gf_pow(x, 1 << _T5_K, _T5_N; modulus=_T5_MOD)
# σ²=id when [F:K]=2 (applying Frobenius twice returns to identity)
_σ2(x::Int) = x

_gf(a, b) = gf_mul(a, b, _T5_N; modulus=_T5_MOD)

# x ∘_α y = x^σ·y + α·x·y^σ
_circ(x::Int, y::Int, α::Int) = _gf(_σ(x), y) ⊻ _gf(α, _gf(x, _σ(y)))

# norm N_{F/K}(α) = α·α^{2^k} = α^{(|F|-1)/(|K|-1)} = α^5 over GF(2⁴)/GF(2²)
_norm(α::Int) = gf_pow(α, (1<<_T5_N - 1) ÷ (1<<_T5_K - 1), _T5_N; modulus=_T5_MOD)

"""
    _P_rootless_T5(a, b) -> Bool

Check x^5+ax+b has no root in GF(2⁴).
"""
function _P_rootless_T5(a::Int, b::Int)
    b == 0 && return false
    for x = 0:(1<<_T5_N)-1
        gf_pow(x, 5, _T5_N; modulus=_T5_MOD) ⊻ _gf(a, x) ⊻ b == 0 && return false
    end
    true
end

"""
    presemi_mul(x, s, y, t, a, b, α) -> (Int, Int)

Theorem 5 multiplication: (x,s)*(y,t) in F×F (F=GF(2⁴)).
  = ( (x∘_α y)^{σ²} + a(x^σt+αy^σs)^σ + b(s∘_α t),  xt+ys )
With σ²=id (since [F:K]=2):
  = ( (x∘_α y) + a(x^σt+αy^σs)^σ + b(s∘_α t),  xt+ys )
"""
function presemi_mul(x::Int, s::Int, y::Int, t::Int, a::Int, b::Int, α::Int)
    circ_xy = _circ(x, y, α)
    mid     = _σ(_gf(_σ(x), t) ⊻ _gf(α, _gf(_σ(y), s)))
    circ_st = _circ(s, t, α)
    first   = _σ2(circ_xy) ⊻ _gf(a, mid) ⊻ _gf(b, circ_st)
    second  = _gf(x, t) ⊻ _gf(y, s)
    (first, second)
end

"""
    lemma2_verify(α) -> Bool

Lemma 2: for all x,y∈GF(2⁴), x∘_α y=0 ⟹ x=0 or y=0.
"""
function lemma2_verify(α::Int)
    for x = 0:(1<<_T5_N)-1, y = 0:(1<<_T5_N)-1
        if _circ(x, y, α) == 0 && x != 0 && y != 0
            return false
        end
    end
    true
end

"""
    theorem5_verify(a, b, α) -> NamedTuple

Verify Theorem 5: (F×F,+,*) is a presemifield by checking
no-zero-divisors exhaustively over GF(2⁴)×GF(2⁴). Also checks Lemma 2.
"""
function theorem5_verify(a::Int, b::Int, α::Int)
    _P_rootless_T5(a, b) || return (; ok=false, msg="P(x)=x⁵+ax+b has a root")
    _norm(α) != 1        || return (; ok=false, msg="N_{F/K}(α)=1, condition violated")
    α != 0               || return (; ok=false, msg="α must be nonzero")

    lem2 = lemma2_verify(α)
    lem2 || return (; ok=false, msg="Lemma 2 failed")

    n = 1 << _T5_N  # 16
    for x = 0:n-1, s = 0:n-1
        (x == 0 && s == 0) && continue  # skip zero
        for y = 0:n-1, t = 0:n-1
            (y == 0 && t == 0) && continue
            p1, p2 = presemi_mul(x, s, y, t, a, b, α)
            (p1 == 0 && p2 == 0) &&
                return (; ok=false, msg="zero-divisor: ($x,$s)*($y,$t)=(0,0)")
        end
    end
    (; ok=true, msg="no zero-divisors found; Lemma 2 holds; Theorem 5 verified")
end

"""
    theorem5_find_params() -> (a,b,α) or nothing

Find the first valid (a,b,α) in GF(2⁴)×GF(2⁴)*×GF(2⁴)* satisfying:
P(x)=x⁵+ax+b rootless and N_{F/K}(α)≠1.
"""
function theorem5_find_params()
    for α = 1:(1<<_T5_N)-1
        _norm(α) != 1 || continue
        for a = 0:(1<<_T5_N)-1, b = 1:(1<<_T5_N)-1
            _P_rootless_T5(a, b) || continue
            return (a, b, α)
        end
    end
    nothing
end

function theorem5_presemifield_report(io::IO = stdout)
    print_section(io, "Theorem 5 — presemifield over GF(2⁴)/GF(2²)")

    params = theorem5_find_params()
    if params === nothing
        println(io, "  [FAIL] no valid (a,b,α) found in GF(2⁴)")
        return
    end
    a, b, α = params
    print_kv(io, "Parameters", "a=$a b=$b α=$α in GF(2⁴) [modulus=0x$(string(_T5_MOD, base=16)) = $(string(_T5_MOD, base=2))]")
    print_kv(io, "N_{F/K}(α)=α^5", string(_norm(α)))
    print_kv(io, "Norm ≠ 1", string(_norm(α) != 1))

    r = theorem5_verify(a, b, α)
    print_check(io, "Lemma 2: x∘_α y=0 ⟹ x=0 or y=0", r.ok)
    print_check(io, "Theorem 5: (F×F,+,*) has no zero-divisors", r.ok)
    print_kv(io, "details", r.msg)
    println(io, "  completeness: exhaustive over all nonzero pairs in GF(2⁴)×GF(2⁴)")
    println(io, "  [skip] Theorem 6 (nuclei ≅ K): algebraic proof only, no nucleus algorithm in VBF")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem5_presemifield_report()
end
