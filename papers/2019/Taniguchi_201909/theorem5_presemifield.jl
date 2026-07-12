# Implements Theorem 5 (presemifield) and Lemma 2
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 4 — Related presemifields on F_{p^n}
#
# Pseudocode:
#   Setting: F=GF(2⁴), K=GF(2²), σ(x)=x^{|K|}=x^4 generates Gal(F/K), [F:K]=2
#   Conditions:
#     P(x) = x^{σ+1}+ax+b = x^{2^k+1}+ax+b = x^5+ax+b has no root in F   (b≠0)
#     N_{F/K}(α) = α^{(|F|-1)/(|K|-1)} = α^5 ≠ 1   (α∈F*)
#   Lemma 2: x ∘_α y = x^σ·y + α·x·y^σ; if x∘_α y=0 then x=0 or y=0
#   Theorem 5: multiplication * defined by Eq.(3) makes (F×F,+,*) a presemifield:
#     (x,s)*(y,t) = ((x∘_α y)^{σ²}+a(x^σt+αy^σs)^σ+b(s∘_α t),  xt+ys)
#     (char 2, so the paper's minus signs are plus signs)
#   Verify: for all nonzero (x,s),(y,t)∈F×F, (x,s)*(y,t)≠(0,0) — for EVERY admissible
#           (a,b,α), and in particular for a≠0, which is the case Section 4 is about
#           (Theorem 6's nucleus results are all conditioned on a≠0).
# VBF API used: gf_pow, gf_mul, primitive_polynomial

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

const _T5_N = 4   # |F| = 2⁴ = 16
const _T5_K = 2   # |K| = 2² = 4 ; σ(x) = x^{2^{_T5_K}}
const _T5_MOD = primitive_polynomial(_T5_N)

_T5_N % _T5_K == 0 ||
    error("theorem5: K = GF(2^$_T5_K) is not a subfield of F = GF(2^$_T5_N)")

# [F:K] — σ generates Gal(F/K) and has order exactly this.
const _T5_DEG = _T5_N ÷ _T5_K

# GF(2⁴) multiplication table: the sweep below runs ~1020 × 16⁴ products.
const _T5_MUL = [gf_mul(i, j, _T5_N; modulus = _T5_MOD) for i = 0:15, j = 0:15]
_gf(a::Int, b::Int) = _T5_MUL[a+1, b+1]

# σ(x) = x^{|K|} = x^{2^k}, the generator of Gal(F/K)
const _T5_SIGMA = [gf_pow(x, 1 << _T5_K, _T5_N; modulus = _T5_MOD) for x = 0:15]
_σ(x::Int) = _T5_SIGMA[x+1]

# σ² = the Frobenius applied twice — NOT hardcoded to the identity. For [F:K]=2 it
# *is* the identity, which is why the old `_σ2(x) = x` happened to be right here;
# writing it as σ∘σ keeps the code correct if _T5_K / _T5_N ever change.
_σ2(x::Int) = _σ(_σ(x))

# x ∘_α y = x^σ·y + α·x·y^σ  (Albert's twisted presemifield multiplication)
_circ(x::Int, y::Int, α::Int) = _gf(_σ(x), y) ⊻ _gf(α, _gf(x, _σ(y)))

# norm N_{F/K}(α) = α^{(|F|-1)/(|K|-1)} = α^5 over GF(2⁴)/GF(2²)
_norm(α::Int) = gf_pow(α, (1 << _T5_N - 1) ÷ (1 << _T5_K - 1), _T5_N; modulus = _T5_MOD)

"""
    presemi_mul(x, s, y, t, a, b, α) -> (Int, Int)

Theorem 5 multiplication, Eq. (3): (x,s)*(y,t) in F×F (F=GF(2⁴)).

    ( (x∘_α y)^{σ²} + a·(x^σ·t + α·y^σ·s)^σ + b·(s∘_α t) ,  x·t + y·s )
"""
function presemi_mul(x::Int, s::Int, y::Int, t::Int, a::Int, b::Int, α::Int)
    circ_xy = _circ(x, y, α)
    mid = _σ(_gf(_σ(x), t) ⊻ _gf(α, _gf(_σ(y), s)))
    circ_st = _circ(s, t, α)
    first = _σ2(circ_xy) ⊻ _gf(a, mid) ⊻ _gf(b, circ_st)
    second = _gf(x, t) ⊻ _gf(y, s)
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
    theorem5_admissible(a, b, α) -> Bool

Theorem 5's hypotheses: `P(x) = x^{σ+1} + a·x + b = x^{2^k+1} + a·x + b` has no root
in F (which forces b≠0), and α ≠ 0 has norm `N_{F/K}(α) ≠ 1`.
"""
theorem5_admissible(a::Int, b::Int, α::Int) =
    α != 0 &&
    _norm(α) != 1 &&
    projective_polynomial_rootless(_T5_N, _T5_K, a, b; modulus = _T5_MOD)

"""
    theorem5_no_zero_divisors(a, b, α) -> Bool

The bare no-zero-divisor scan over all nonzero (x,s),(y,t) ∈ F×F, with **no**
admissibility precondition — so it can be aimed at *inadmissible* parameters as a
negative control (see [`theorem5_sweep`](@ref)).
"""
function theorem5_no_zero_divisors(a::Int, b::Int, α::Int)
    n = 1 << _T5_N  # 16
    for x = 0:n-1, s = 0:n-1
        (x == 0 && s == 0) && continue
        for y = 0:n-1, t = 0:n-1
            (y == 0 && t == 0) && continue
            p1, p2 = presemi_mul(x, s, y, t, a, b, α)
            (p1 == 0 && p2 == 0) && return false
        end
    end
    true
end

"""
    theorem5_verify(a, b, α) -> NamedTuple

Verify Theorem 5: (F×F,+,*) is a presemifield by checking no-zero-divisors
exhaustively over GF(2⁴)×GF(2⁴). Also checks Lemma 2.
"""
function theorem5_verify(a::Int, b::Int, α::Int)
    projective_polynomial_rootless(_T5_N, _T5_K, a, b; modulus = _T5_MOD) ||
        return (; ok = false, msg = "P(x)=x⁵+ax+b has a root")
    _norm(α) != 1 || return (; ok = false, msg = "N_{F/K}(α)=1, condition violated")
    α != 0 || return (; ok = false, msg = "α must be nonzero")

    lemma2_verify(α) || return (; ok = false, msg = "Lemma 2 failed")

    theorem5_no_zero_divisors(a, b, α) ||
        return (; ok = false, msg = "zero-divisor found for (a=$a, b=$b, α=$α)")

    (; ok = true, msg = "no zero-divisors found; Lemma 2 holds; Theorem 5 verified")
end

"""
    theorem5_all_params() -> Vector{NTuple{3,Int}}

Every (a,b,α) satisfying Theorem 5's hypotheses over GF(2⁴)/GF(2²).
"""
function theorem5_all_params()
    ps = NTuple{3,Int}[]
    for α = 1:(1<<_T5_N)-1
        _norm(α) != 1 || continue
        for a = 0:(1<<_T5_N)-1, b = 1:(1<<_T5_N)-1
            theorem5_admissible(a, b, α) && push!(ps, (a, b, α))
        end
    end
    ps
end

"""
    theorem5_find_params(; require_nonzero_a=true) -> (a,b,α) or nothing

A valid (a,b,α), by default one with **a ≠ 0**.

The first valid triple in lexicographic order is `(a=0, b=2, α=2)` — the degenerate
witness. Section 4 is interesting precisely for `a ≠ 0`: the `a = 0` members are the
ones the paper hands back to Zhou-Pott, and every nucleus result in Theorem 6 is
conditioned on `a ≠ 0`.
"""
function theorem5_find_params(; require_nonzero_a::Bool = true)
    for α = 1:(1<<_T5_N)-1
        _norm(α) != 1 || continue
        for a = 0:(1<<_T5_N)-1, b = 1:(1<<_T5_N)-1
            require_nonzero_a && a == 0 && continue
            theorem5_admissible(a, b, α) && return (a, b, α)
        end
    end
    nothing
end

"""
    theorem5_sweep() -> NamedTuple

Run `theorem5_verify` on **every** admissible (a,b,α), not merely on one; and, as a
negative control, confirm the hypotheses are load-bearing — dropping either one must
actually produce a zero-divisor:

  - α with `N_{F/K}(α) = 1` (Lemma 2's hypothesis) ⇒ zero-divisors appear;
  - (a,b) whose `P(x)` has a root (Lemma 3's hypothesis) ⇒ zero-divisors appear.

Without those controls, "no zero divisors were found" is not a discriminating test.
"""
function theorem5_sweep()
    params = theorem5_all_params()
    n_a_nonzero = count(p -> p[1] != 0, params)
    fails = [p for p in params if !theorem5_verify(p...).ok]

    # a good a≠0 witness to hold fixed while we break one hypothesis at a time
    ia = findfirst(p -> p[1] != 0, params)
    a0, b0, α0 = params[ia]

    # negative control 1 — norm-1 α (Lemma 2 fails)
    bad_α = [α for α = 1:(1<<_T5_N)-1 if _norm(α) == 1]
    ctrl_norm = all(!theorem5_no_zero_divisors(a0, b0, α) for α in bad_α)

    # negative control 2 — (a,b) with P(x) rooted (Lemma 3 fails)
    bad_ab = [
        (a, b) for a = 0:(1<<_T5_N)-1 for b = 1:(1<<_T5_N)-1 if
        !projective_polynomial_rootless(_T5_N, _T5_K, a, b; modulus = _T5_MOD)
    ]
    ctrl_root = all(!theorem5_no_zero_divisors(a, b, α0) for (a, b) in bad_ab)

    (;
        ok = (isempty(fails) && ctrl_norm && ctrl_root),
        n_params = length(params),
        n_a_nonzero,
        n_a_zero = length(params) - n_a_nonzero,
        n_fail = length(fails),
        fails,
        ctrl_norm,
        ctrl_root,
        n_bad_α = length(bad_α),
        n_bad_ab = length(bad_ab),
    )
end

function theorem5_presemifield_report(io::IO = stdout)
    print_section(io, "Theorem 5 — presemifield over GF(2⁴)/GF(2²)")

    params = theorem5_find_params()   # a ≠ 0 — the case Section 4 is actually about
    if params === nothing
        println(io, "  [FAIL] no valid (a,b,α) with a≠0 found in GF(2⁴)")
        return
    end
    a, b, α = params
    print_kv(
        io,
        "Parameters (a≠0)",
        "a=$a b=$b α=$α in GF(2⁴) [modulus=0x$(string(_T5_MOD, base=16)) = $(string(_T5_MOD, base=2))]",
    )
    print_kv(io, "[F:K]", "$_T5_DEG  (σ(x)=x^$(1 << _T5_K); σ² computed as σ∘σ, not assumed)")
    print_kv(io, "N_{F/K}(α)=α^5", string(_norm(α)))
    print_kv(io, "Norm ≠ 1", string(_norm(α) != 1))

    r = theorem5_verify(a, b, α)
    print_check(io, "Lemma 2: x∘_α y=0 ⟹ x=0 or y=0", lemma2_verify(α))
    print_check(io, "Theorem 5: (F×F,+,*) has no zero-divisors (a≠0 witness)", r.ok)

    s = theorem5_sweep()
    print_check(
        io,
        "Theorem 5 holds on ALL $(s.n_params) admissible (a,b,α), not just one",
        s.n_fail == 0,
    )
    print_check(
        io,
        "$(s.n_a_nonzero) of the $(s.n_params) triples have a≠0 (Section 4 / Theorem 6's case)",
        s.n_a_nonzero == 900,
    )
    print_check(
        io,
        "negative control: each of the $(s.n_bad_α) norm-1 α gives a zero-divisor",
        s.ctrl_norm,
    )
    print_check(
        io,
        "negative control: each of the $(s.n_bad_ab) rooted (a,b) gives a zero-divisor",
        s.ctrl_root,
    )
    print_kv(io, "details", r.msg)
    print_kv(
        io,
        "admissible triples",
        "$(s.n_params)  ($(s.n_a_nonzero) with a≠0, $(s.n_a_zero) with a=0)",
    )
    println(io, "  completeness: exhaustive over all nonzero pairs in GF(2⁴)×GF(2⁴), for")
    println(io, "  every admissible (a,b,α); both hypotheses shown to be load-bearing")
    println(io, "  [skip] Theorem 6 (nuclei ≅ K): the theorem assumes [F:K] ≥ 3, while this")
    println(io, "  instance has [F:K] = 2 — so it is outside the theorem's own hypotheses and")
    println(io, "  could not have been tested here even in principle. Section 4 is stated for")
    println(io, "  any prime p, and the smallest [F:K]=3 instance is p=3, K=GF(3), F=GF(3³):")
    println(io, "  odd characteristic, which VBF's SBox/GF machinery (characteristic 2 only)")
    println(io, "  cannot represent. That, not the absence of a nucleus algorithm, is the")
    println(io, "  actual blocker.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem5_presemifield_report()
end
