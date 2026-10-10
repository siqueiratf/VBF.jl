# Paper-local helpers for the Göloğlu–Kölsch (2025) reproduction.
# Paper: Faruk Göloğlu, Lukas Kölsch (2025), "Equivalences of biprojective
#        almost perfect nonlinear functions", Electron. J. Combin.
# Section: 2. Preliminaries — projective and biprojective polynomials
#          (Notation 3.1, Notation 4.4, Table 2.1)
#
# Pseudocode:
#   1. Fix M = F_{2^m} with a pinned modulus (the paper pins none — see below).
#   2. A q-biprojective polynomial is the 4-tuple (a,b,c,d)_q standing for
#        f(x,y) = a x^{q+1} + b x^q y + c x y^q + d y^{q+1},  q = 2^e.
#   3. A (q,r)-biprojective pair F = (f, g) is a map M × M -> M × M.
#   4. Provide: evaluation, SBox lift, the D_f^u / D_g^u linear maps of
#      Lemma 2.1, the coefficient transform of f(c1 x + c2 y, c3 x + c4 y),
#      the Table 2.1 family constructors and their admissibility predicates.
#
# VBF API used: gf_mul, gf_pow, gf_inv, gf_is_dth_power, in_subfield,
#               subfield_elements, primitive_polynomial, kernel_f2, rank_f2,
#               SBox, print_banner
#
# FIELD CONVENTION.  The paper never pins a modulus for M = F_{2^m} nor a
# primitive element.  Every *statement* reproduced here is modulus-independent
# (being a cube, lying in a subfield, being APN are all intrinsic), but the
# *witnesses* (concrete B, a, d values) are not.  We pin
# `VBF.primitive_polynomial(m)` throughout and print it in every report, so the
# integer literals in this reproduction are only meaningful under that modulus.

using VBF

# ── Notation 3.1 / 4.4: the field M = F_{2^m} ────────────────────────────────

"""
    BiField(m; modulus = primitive_polynomial(m))

The field `M = F_{2^m}` of Notation 3.1. `F = F_{2^n}` with `n = 2m` is
identified with `M × M` throughout the paper; we never build `F` itself.
`Q = 2^{m/2}` is defined only when `m` is even.
"""
struct BiField
    m::Int
    modulus::Int
end
BiField(m::Integer; modulus::Integer = primitive_polynomial(Int(m))) =
    BiField(Int(m), Int(modulus))

nbits(fld::BiField) = 2 * fld.m
order(fld::BiField) = 1 << fld.m                       # |M|
mstar(fld::BiField) = 1:(order(fld)-1)                 # M^×
Qof(fld::BiField) = 1 << (fld.m ÷ 2)                   # Q = 2^{m/2}, m even

gmul(fld::BiField, a, b) = gf_mul(a, b, fld.m; modulus = fld.modulus)
gpow(fld::BiField, a, k) = gf_pow(a, k, fld.m; modulus = fld.modulus)
ginv(fld::BiField, a) = gf_inv(a, fld.m; modulus = fld.modulus)
gdiv(fld::BiField, a, b) = gmul(fld, a, ginv(fld, b))

"""
    frob(fld, x, e) -> Int

`x^{2^e}` in `M`. The exponent is reduced mod `m` (the Frobenius has order
`m`), so callers may pass `e = k + m/2`, `2k`, `3k`, … unreduced.
"""
frob(fld::BiField, x::Integer, e::Integer) = gpow(fld, x, 1 << mod(Int(e), fld.m))

"""Non-cubes of `M^×`, i.e. `M^× ∖ C_M` of Notation 3.1."""
noncubes(fld::BiField) =
    [b for b in mstar(fld) if !gf_is_dth_power(b, 3, fld.m; modulus = fld.modulus)]

"""Non-zero cubes `C_M = (M^×)³` of Notation 3.1."""
cubes(fld::BiField) =
    [b for b in mstar(fld) if gf_is_dth_power(b, 3, fld.m; modulus = fld.modulus)]

"""`K^× = F_{2^{m/2}}^×` of Notation 3.1 (m even)."""
function kstar(fld::BiField)
    @assert iseven(fld.m)
    [x for x in subfield_elements(fld.m, fld.m ÷ 2; modulus = fld.modulus) if x != 0]
end

"""`F₄^×` — the cube roots of unity inside `M` (needs `3 | 2^m − 1`, i.e. m even)."""
function f4star(fld::BiField)
    @assert iseven(fld.m)
    [x for x in mstar(fld) if gpow(fld, x, 3) == 1]
end

# ── Biprojective polynomials (Section 2.1) ──────────────────────────────────

"""
    BiProj(e, (a, b, c, d))

The `q`-biprojective polynomial `(a,b,c,d)_q` with `q = 2^e`:

    f(x, y) = a x^{q+1} + b x^q y + c x y^q + d y^{q+1}

Note `e = 0` (`q = 1`) is degenerate: `x^q y` and `x y^q` collapse to the same
monomial `xy`, and `x^{q+1} = x²`, `y^{q+1} = y²` are *linear*. Only the Carlet
family uses `e = 0`; that degeneracy is exactly why Carlet needs the `N` part of
an EL-mapping (paper: Appendix B, and the `k ≡ 0 (mod m)` caveat in Lemma A.1).
"""
struct BiProj
    e::Int
    c::NTuple{4,Int}
end

"""
    BiPair(f, g, fld, name)

A `(q,r)`-biprojective polynomial pair `F(x,y) = (f(x,y), g(x,y))`,
`F : M × M → M × M` (Section 2.1).
"""
struct BiPair
    f::BiProj
    g::BiProj
    fld::BiField
    name::String
end

kexp(F::BiPair) = F.f.e      # k, with q = 2^k
lexp(F::BiPair) = F.g.e      # l, with r = 2^l

"""Evaluate a biprojective polynomial at `(x, y) ∈ M × M`."""
function biproj_eval(fld::BiField, p::BiProj, x::Integer, y::Integer)
    a, b, c, d = p.c
    xq = frob(fld, x, p.e)
    yq = frob(fld, y, p.e)
    v = 0
    a != 0 && (v ⊻= gmul(fld, a, gmul(fld, xq, x)))
    b != 0 && (v ⊻= gmul(fld, b, gmul(fld, xq, y)))
    c != 0 && (v ⊻= gmul(fld, c, gmul(fld, x, yq)))
    d != 0 && (v ⊻= gmul(fld, d, gmul(fld, yq, y)))
    v
end

"""Evaluate the pair: `F(x,y) = (f(x,y), g(x,y))`."""
bipair_eval(F::BiPair, x::Integer, y::Integer) =
    (biproj_eval(F.fld, F.f, x, y), biproj_eval(F.fld, F.g, x, y))

"""
    bipair_sbox(F) -> SBox{2m}

Lift `F : M × M → M × M` to an `SBox` on `n = 2m` bits. Encoding: the input
index is `(x << m) | y` and the output is `(f << m) | g` — `x` and `f` occupy
the high half. The encoding is a fixed F₂-linear identification of `M × M` with
`F₂^{2m}`, so no CCZ/EA statement depends on the choice.
"""
function bipair_sbox(F::BiPair)
    fld = F.fld
    m = fld.m
    n = 2m
    lut = Vector{Int}(undef, 1 << n)
    for x = 0:(order(fld)-1), y = 0:(order(fld)-1)
        fv, gv = bipair_eval(F, x, y)
        lut[((x << m) | y)+1] = (fv << m) | gv
    end
    SBox{n}(lut)
end

# ── Lemma 2.1: the D_f^u / D_g^u linearised maps ────────────────────────────
#
#   D_f^∞(x,y) = a x^q + a x + c y^q + b y
#   D_f^u(x,y) = (a u + b) x^q + (a u^q + c) x + (c u + d) y^q + (b u^q + d) y
#
# `u === nothing` encodes the point ∞ of P¹(M).

"""Evaluate `D_p^u(x, y)` for a biprojective polynomial `p` (Section 2.1)."""
function du_eval(fld::BiField, p::BiProj, u, x::Integer, y::Integer)
    a, b, c, d = p.c
    xq = frob(fld, x, p.e)
    yq = frob(fld, y, p.e)
    if u === nothing                                     # u = ∞
        return gmul(fld, a, xq) ⊻ gmul(fld, a, x) ⊻ gmul(fld, c, yq) ⊻ gmul(fld, b, y)
    end
    uq = frob(fld, u, p.e)
    k1 = gmul(fld, a, u) ⊻ b
    k2 = gmul(fld, a, uq) ⊻ c
    k3 = gmul(fld, c, u) ⊻ d
    k4 = gmul(fld, b, uq) ⊻ d
    gmul(fld, k1, xq) ⊻ gmul(fld, k2, x) ⊻ gmul(fld, k3, yq) ⊻ gmul(fld, k4, y)
end

"""
    du_solution_count(F, u) -> Int

Number of `(x,y) ∈ M × M` with `D_f^u(x,y) = D_g^u(x,y) = 0`.

Both `D_f^u` and `D_g^u` are **F₂-linear** in `(x,y)`, so the solution set is a
kernel: we build the `2m × 2m` matrix over F₂ and call `kernel_f2` from core.
That is what makes the criterion usable at `n = 20, 28`, where a `2ⁿ × 2ⁿ` DDT
is hopeless.
"""
function du_solution_count(F::BiPair, u)
    fld = F.fld
    m = fld.m
    nb = 2m
    # column j = image of the j-th basis vector of M × M, packed as (Df << m) | Dg
    cols = Vector{UInt64}(undef, nb)
    for i = 0:(m-1)
        b = 1 << i
        df = du_eval(fld, F.f, u, b, 0)
        dg = du_eval(fld, F.g, u, b, 0)
        cols[i+1] = UInt64((df << m) | dg)
        df = du_eval(fld, F.f, u, 0, b)
        dg = du_eval(fld, F.g, u, 0, b)
        cols[m+i+1] = UInt64((df << m) | dg)
    end
    rows = zeros(UInt64, nb)                              # transpose to row form
    for j = 1:nb, i = 0:(nb-1)
        ((cols[j] >> i) & 1) == 1 && (rows[i+1] |= UInt64(1) << (j - 1))
    end
    1 << length(kernel_f2(rows; nbits = nb))
end

"""
    biprojective_is_apn(F) -> Bool

Lemma 2.1: `F` is APN iff `D_f^u = D_g^u = 0` has exactly two solutions for
every `u ∈ P¹(M)`. Cost `O(2^m · m³)` — independent of `2ⁿ`.
"""
function biprojective_is_apn(F::BiPair)
    du_solution_count(F, nothing) == 2 || return false
    for u = 0:(order(F.fld)-1)
        du_solution_count(F, u) == 2 || return false
    end
    true
end

"""
    biprojective_apn_witness(F) -> NamedTuple | nothing

The first `u ∈ P¹(M)` at which the Lemma 2.1 criterion fails (with its solution
count), or `nothing` when `F` is APN. Used as the *negative* diagnostic.
"""
function biprojective_apn_witness(F::BiPair)
    c = du_solution_count(F, nothing)
    c == 2 || return (u = nothing, count = c)
    for u = 0:(order(F.fld)-1)
        c = du_solution_count(F, u)
        c == 2 || return (u = u, count = c)
    end
    nothing
end

# ── Coefficient transform (Theorem 4.8, Lemma A.1, Appendix B) ──────────────

"""
    biproj_compose(fld, p, c1, c2, c3, c4) -> BiProj

Coefficients of `p(c₁x + c₂y, c₃x + c₄y)`, again a `q`-biprojective polynomial
with the same `q` (expand `(c₁x + c₂y)^q = c₁^q x^q + c₂^q y^q`). This is the
matrix part of the group action `M·f` of Appendix B and the engine of Lemma A.1.

Beware `e = 0`: the four returned coefficients are a correct *representation*,
but `x^q y` and `x y^q` are then the same monomial, so the function is
`A x² + (B ⊕ C) xy + D y²`. Callers needing `e = 0` (Carlet) must fold `B ⊕ C`.
"""
function biproj_compose(fld::BiField, p::BiProj, c1, c2, c3, c4)
    a, b, c, d = p.c
    q1 = frob(fld, c1, p.e)
    q2 = frob(fld, c2, p.e)
    q3 = frob(fld, c3, p.e)
    q4 = frob(fld, c4, p.e)
    mm(u, v) = gmul(fld, u, v)
    A = mm(a, mm(q1, c1)) ⊻ mm(b, mm(q1, c3)) ⊻ mm(c, mm(c1, q3)) ⊻ mm(d, mm(q3, c3))
    B = mm(a, mm(q1, c2)) ⊻ mm(b, mm(q1, c4)) ⊻ mm(c, mm(c2, q3)) ⊻ mm(d, mm(q3, c4))
    C = mm(a, mm(c1, q2)) ⊻ mm(b, mm(q2, c3)) ⊻ mm(c, mm(c1, q4)) ⊻ mm(d, mm(c3, q4))
    D = mm(a, mm(q2, c2)) ⊻ mm(b, mm(q2, c4)) ⊻ mm(c, mm(c2, q4)) ⊻ mm(d, mm(q4, c4))
    BiProj(p.e, (A, B, C, D))
end

"""Scalar action `a·f = (a p₁, a p₂, a p₃, a p₄)_q` of Appendix B."""
biproj_scale(fld::BiField, p::BiProj, a::Integer) =
    BiProj(p.e, ntuple(i -> gmul(fld, a, p.c[i]), 4))

"""
    proportional_scalar(fld, p, target) -> Int | nothing

The unique `λ ∈ M^×` with `p = λ · target` coefficientwise, or `nothing`.
"""
function proportional_scalar(fld::BiField, p::BiProj, target::BiProj)
    idx = findfirst(!=(0), target.c)
    idx === nothing && return nothing
    λ = gdiv(fld, p.c[idx], target.c[idx])
    λ == 0 && return nothing
    for i = 1:4
        gmul(fld, λ, target.c[i]) == p.c[i] || return nothing
    end
    λ
end

# ── Table 2.1: the known biprojective APN families ──────────────────────────
#
#  G   Gold          m odd : ((0,1,1,0)_q, (1,0,1,1)_q)
#                    m even: ((1,0,b,a)_q, (0,1,1,b+1)_q), Tr(a)=1, b = Σ_{i<k} a^{2^{2i}}
#  C   Carlet        (xy, (1,b,c,d)_q)
#  T   Taniguchi     ((1,0,1,d)_q, (0,0,1,0)_{q²})
#  ZP  Zhou–Pott     ((1,0,0,d)_q, (0,0,1,0)_r)
#  F1  Göloğlu       ((1,0,1,1)_q, (1,1,0,1)_{q²})
#  F2  Göloğlu       ((1,0,1,1)_q, (0,1,1,0)_{q³})
#  F4  NEW (Thm 3.3) ((1,0,0,B)_q, (0,1,a/B,0)_r),  r = q·Q

"""Gold, Table 2.1 row 2 (`m` odd): `((0,1,1,0)_q, (1,0,1,1)_q)`."""
gold_odd(fld::BiField, k::Integer) =
    BiPair(BiProj(k, (0, 1, 1, 0)), BiProj(k, (1, 0, 1, 1)), fld, "G(q=2^$k)")

"""
Gold, Table 2.1 row 3 (`m` even): `((1,0,b,a)_q, (0,1,1,b+1)_q)` with
`Tr_{M/F₂}(a) = 1` and `b = Σ_{i=0}^{k-1} a^{2^i}`.

TRANSCRIPTION NOTE (reproduction-side, not a paper bug). The `.tex` shipped in
`input/` is an OCR conversion of the published PDF and renders the exponent as
`a^{2^{2}}`, dropping the summation index. The **PDF** (authoritative, p. 5,
Table 2.1) prints `b = Σ_{i=0}^{k-1} a^{2^i}`, and a brute-force search over
`m ∈ {4,6,8}` and every admissible `(k, a)` confirms it: `Σ_{i<k} a^{2^i}` always
lands in the APN-valid set for `b`, while `Σ_{i<k} a^{2^{2i}}` (the plausible
alternative reading, and the one that coincides at `k = 1`) does not — it fails
for every admissible `a` at `m=4, k=3`. See `lemma2_1.jl`, which cross-validates
every Table 2.1 entry against `differential_uniformity`.
"""
function gold_even(fld::BiField, k::Integer, a::Integer)
    b = 0
    for i = 0:(k-1)
        b ⊻= frob(fld, a, i)
    end
    BiPair(BiProj(k, (1, 0, b, a)), BiProj(k, (0, 1, 1, b ⊻ 1)), fld, "G(q=2^$k,a=$a)")
end

"""Carlet, Table 2.1: `(xy, (1,b,c,d)_q)`. The first component is `(0,1,0,0)₁`."""
carlet(fld::BiField, k::Integer, b::Integer, c::Integer, d::Integer) =
    BiPair(BiProj(0, (0, 1, 0, 0)), BiProj(k, (1, b, c, d)), fld, "C(q=2^$k;1,$b,$c,$d)")

"""Taniguchi, Table 2.1: `((1,0,1,d)_q, (0,0,1,0)_{q²})`."""
taniguchi(fld::BiField, k::Integer, d::Integer) =
    BiPair(BiProj(k, (1, 0, 1, d)), BiProj(2k, (0, 0, 1, 0)), fld, "T(q=2^$k,d=$d)")

"""Zhou–Pott, Table 2.1: `((1,0,0,d)_q, (0,0,1,0)_r)`, `r = 2^j`."""
zhou_pott(fld::BiField, k::Integer, j::Integer, d::Integer) =
    BiPair(BiProj(k, (1, 0, 0, d)), BiProj(j, (0, 0, 1, 0)), fld, "ZP(q=2^$k,r=2^$j,d=$d)")

"""Family `F₁` [Göl22], Table 2.1: `((1,0,1,1)_q, (1,1,0,1)_{q²})`."""
family_f1(fld::BiField, k::Integer) =
    BiPair(BiProj(k, (1, 0, 1, 1)), BiProj(2k, (1, 1, 0, 1)), fld, "F1(q=2^$k)")

"""Family `F₂` [Göl22], Table 2.1: `((1,0,1,1)_q, (0,1,1,0)_{q³})`."""
family_f2(fld::BiField, k::Integer) =
    BiPair(BiProj(k, (1, 0, 1, 1)), BiProj(3k, (0, 1, 1, 0)), fld, "F2(q=2^$k)")

"""
Family `F₄` — the new family of Theorem 3.3:
`((1,0,0,B)_q, (0,1,a/B,0)_r)` with `q = 2^k` and `r = 2^{k+m/2} = qQ`.
Theorem C.3 restates it as `F(x,y) = (x^{q+1} + B y^{q+1}, x^{qQ}y + (a/B)x y^{qQ})`.
"""
function family_f4(fld::BiField, k::Integer, B::Integer, a::Integer)
    l = k + fld.m ÷ 2
    BiPair(
        BiProj(k, (1, 0, 0, B)),
        BiProj(l, (0, 1, gdiv(fld, a, B), 0)),
        fld,
        "F4(q=2^$k,B=$B,a=$a)",
    )
end

# ── Admissibility predicates (Table 2.1, "Notes" column) ────────────────────

"""`f(x,1) = p₁x^{q+1} + p₂x^q + p₃x + p₄` has no root in `M` (Appendix B)."""
function projective_rootfree(fld::BiField, p::BiProj)
    for x = 0:(order(fld)-1)
        biproj_eval(fld, p, x, 1) == 0 && return false
    end
    true
end

"""Carlet admissibility: `0<k<m`, `gcd(k,m)=1`, `x^{q+1}+bx^q+cx+d ≠ 0` on `M`."""
carlet_valid(fld::BiField, k, b, c, d) =
    0 < k < fld.m && gcd(k, fld.m) == 1 && projective_rootfree(fld, BiProj(k, (1, b, c, d)))

"""Taniguchi admissibility: `0<k<m`, `gcd(k,m)=1`, `x^{q+1}+x+d ≠ 0` on `M`."""
taniguchi_valid(fld::BiField, k, d) =
    0 < k < fld.m && gcd(k, fld.m) == 1 && projective_rootfree(fld, BiProj(k, (1, 0, 1, d)))

"""
The excluded set `{ a^{q+1}(b^q+b)^{1−r} : a, b ∈ M }` of the Zhou–Pott note in
Table 2.1. `d` is admissible iff it lies outside it.
"""
function zhou_pott_excluded_d(fld::BiField, k::Integer, j::Integer)
    bad = Set{Int}()
    for b = 0:(order(fld)-1)
        t = frob(fld, b, k) ⊻ b                      # b^q + b
        t == 0 && continue
        w = gdiv(fld, t, frob(fld, t, j))            # (b^q+b)^{1-r}
        for a in mstar(fld)
            push!(bad, gmul(fld, gmul(fld, frob(fld, a, k), a), w))
        end
    end
    bad
end

"""Zhou–Pott admissibility: `m` even, `0<j,k<m`, `gcd(k,m)=1`, `d` not excluded."""
function zhou_pott_valid(fld::BiField, k, j, d)
    iseven(fld.m) && 0 < k < fld.m && 0 < j < fld.m && gcd(k, fld.m) == 1 || return false
    d != 0 && !(d ∈ zhou_pott_excluded_d(fld, k, j))
end

"""`F₁` admissibility: `0<k<m`, `gcd(3k,m)=1`."""
f1_valid(fld::BiField, k) = 0 < k < fld.m && gcd(3k, fld.m) == 1

"""`F₂` admissibility: `F₁`'s conditions plus `m` odd."""
f2_valid(fld::BiField, k) = f1_valid(fld, k) && isodd(fld.m)

"""
`F₄` admissibility (Theorem 3.3): `m ≡ 2 (mod 4)`, `0<k<m`, `gcd(k,m)=1`,
`B ∈ M^× ∖ C_M` (a non-cube), `a ∈ K^×`, and `B^{q+r} ≠ a^{q+1}`.
"""
function f4_valid(fld::BiField, k::Integer, B::Integer, a::Integer)
    m = fld.m
    mod(m, 4) == 2 || return false
    0 < k < m && gcd(k, m) == 1 || return false
    (B != 0 && !gf_is_dth_power(B, 3, m; modulus = fld.modulus)) || return false
    (a != 0 && in_subfield(a, m ÷ 2, m; modulus = fld.modulus)) || return false
    l = k + m ÷ 2
    Bqr = gmul(fld, frob(fld, B, k), frob(fld, B, l))          # B^{q+r}
    aq1 = gmul(fld, frob(fld, a, k), a)                        # a^{q+1}
    Bqr != aq1
end

"""All admissible `F₄` parameter triples `(k, B, a)` on `M` (Theorem 3.3)."""
function f4_parameters(fld::BiField)
    out = NTuple{3,Int}[]
    mod(fld.m, 4) == 2 || return out
    for k = 1:(fld.m-1), B in noncubes(fld), a in kstar(fld)
        f4_valid(fld, k, B, a) && push!(out, (k, B, a))
    end
    out
end

# ── EL-mappings (Definition 4.1): monomial blocks ───────────────────────────

"""
    MonoMap(c, t)

The linearised monomial `x ↦ c · x^{2^t}` (`c = 0` is the zero map). These are
exactly the shapes Theorem 4.8 forces on `M₁…M₄` and `L₁…L₄`.
"""
struct MonoMap
    c::Int
    t::Int
end
zero_mono() = MonoMap(0, 0)
mono_apply(fld::BiField, mm::MonoMap, x::Integer) =
    mm.c == 0 ? 0 : gmul(fld, mm.c, frob(fld, x, mm.t))

"""A `2 × 2` block of `MonoMap`s acting on `M × M` — an `M` or `L` of Thm 4.8."""
struct BlockMap
    m1::MonoMap
    m2::MonoMap
    m3::MonoMap
    m4::MonoMap
end

block_apply(fld::BiField, B::BlockMap, x::Integer, y::Integer) = (
    mono_apply(fld, B.m1, x) ⊻ mono_apply(fld, B.m2, y),
    mono_apply(fld, B.m3, x) ⊻ mono_apply(fld, B.m4, y),
)

"""Is `B` a bijection of `M × M`? (an F₂-rank check on `2m` bits)"""
function block_invertible(fld::BiField, B::BlockMap)
    m = fld.m
    rows = UInt64[]
    for i = 0:(m-1)
        u, v = block_apply(fld, B, 1 << i, 0)
        push!(rows, UInt64((u << m) | v))
        u, v = block_apply(fld, B, 0, 1 << i)
        push!(rows, UInt64((u << m) | v))
    end
    rank_f2(rows; nbits = 2m) == 2m
end

"""
    el_identity_holds(Fleft, M, L, Fright; N = nothing) -> Bool

Check the paper's EL-equation **verbatim**:

    Fleft(M(x, y)) = L(Fright(x, y)) + N(x, y)   for all (x, y) ∈ M × M.

Theorem 5.1 states its explicit equivalences in exactly this orientation
(`F_q ∘ M = L ∘ F_{q̄}`), so the argument order here mirrors the paper's and the
call sites can be read straight off the page. `N` is an optional
`(x, y) -> (n₁, n₂)` callable; only the Carlet family needs it.
"""
function el_identity_holds(
    Fleft::BiPair,
    M::BlockMap,
    L::BlockMap,
    Fright::BiPair;
    N = nothing,
)
    fld = Fleft.fld
    for x = 0:(order(fld)-1), y = 0:(order(fld)-1)
        mx, my = block_apply(fld, M, x, y)
        lhs1, lhs2 = bipair_eval(Fleft, mx, my)
        f1, f2 = bipair_eval(Fright, x, y)
        r1, r2 = block_apply(fld, L, f1, f2)
        if N !== nothing
            n1, n2 = N(x, y)
            r1 ⊻= n1
            r2 ⊻= n2
        end
        (lhs1 == r1 && lhs2 == r2) || return false
    end
    true
end

# ── Lemma 4.5 / Notation 4.4: the cyclic subgroup Z^{(q,r)} ─────────────────

"""
    z_qr_is_automorphism(F, a; kk = kexp(F), ll = lexp(F)) -> Bool

Whether `diag(m_a, m_a, m_{a^{q+1}}, m_{a^{r+1}})` stabilises the graph of `F`,
which is Lemma 4.5's pointwise identity

    F(a x, a y) = (a^{q+1} f(x,y),  a^{r+1} g(x,y)).

`kk`/`ll` override the exponents used to build the group element — passing a
wrong pair is the negative control for Lemma 4.5.
"""
function z_qr_is_automorphism(
    F::BiPair,
    a::Integer;
    kk::Integer = kexp(F),
    ll::Integer = lexp(F),
)
    fld = F.fld
    aq1 = gmul(fld, frob(fld, a, kk), a)
    ar1 = gmul(fld, frob(fld, a, ll), a)
    for x = 0:(order(fld)-1), y = 0:(order(fld)-1)
        f1, f2 = bipair_eval(F, x, y)
        g1, g2 = bipair_eval(F, gmul(fld, a, x), gmul(fld, a, y))
        (g1 == gmul(fld, aq1, f1) && g2 == gmul(fld, ar1, f2)) || return false
    end
    true
end

# ── Lemma A.1: the centralizer C_F ──────────────────────────────────────────

"""
    centralizer_classes(F; carlet_f = false) -> Vector{NTuple{4,Int}}

Representatives of `C_F / Z^{(q,r)}`; the length is the index
`I = [C_F : Z^{(q,r)}]` of Lemma A.1 and condition (C).

By Lemma 4.7 every `λ = (M 0; N L) ∈ C_F` has `M = (m_{c₁} m_{c₂}; m_{c₃} m_{c₄})`
with `cᵢ ∈ M`; then `λ ∈ Aut_EL(F)` means `F ∘ M = L ∘ F + N`, which by the proof
of Lemma A.1 forces `L = diag(m_{d₁}, m_{d₄})` (and `N = 0` unless `k ≡ 0 mod m`).
Membership therefore reduces to a coefficient test:

    f ∘ M = d₁ · f      and      g ∘ M = d₄ · g.

`C_F` is closed under `M ↦ aM` (`a ∈ M^×`; it sends `d₁ ↦ a^{q+1}d₁`,
`d₄ ↦ a^{r+1}d₄`) and `Z^{(q,r)}` is precisely the class of the identity matrix,
so enumerating `(c₁:c₂:c₃:c₄)` **projectively** — first nonzero entry normalised
to 1 — gives the index directly: `1 + 2^m + 2^{2m} + 2^{3m}` candidates instead
of `2^{4m}`.

`carlet_f = true` handles the degenerate `e = 0` first component `f = xy`: there
`A x² + D y²` is absorbed by `N` and only the `xy` coefficient `B ⊕ C = det(M)`
matters, which is automatic — so only `g` is constrained (paper: Eq. (A.15)–(A.16)).
"""
function centralizer_classes(F::BiPair; carlet_f::Bool = false)
    fld = F.fld
    N = order(fld)
    out = NTuple{4,Int}[]
    for c1 = 0:(N-1), c2 = 0:(N-1), c3 = 0:(N-1), c4 = 0:(N-1)
        cs = (c1, c2, c3, c4)
        idx = findfirst(!=(0), cs)               # projective normalisation
        idx === nothing && continue
        cs[idx] == 1 || continue
        det = gmul(fld, c1, c4) ⊻ gmul(fld, c2, c3)
        det == 0 && continue                     # M must be invertible
        if !carlet_f
            fc = biproj_compose(fld, F.f, c1, c2, c3, c4)
            proportional_scalar(fld, fc, F.f) === nothing && continue
        end
        gc = biproj_compose(fld, F.g, c1, c2, c3, c4)
        proportional_scalar(fld, gc, F.g) === nothing && continue
        push!(out, cs)
    end
    out
end

"""`[C_F : Z^{(q,r)}]` — the index in condition (C) of Theorem 4.8."""
centralizer_index(F::BiPair; carlet_f::Bool = false) =
    length(centralizer_classes(F; carlet_f = carlet_f))

"""Distinct prime factors of `n`, by trial division (`n < 2³²` here)."""
function prime_factors(n::Integer)
    out = Int[]
    x = Int(n)
    d = 2
    while d * d ≤ x
        if x % d == 0
            push!(out, d)
            while x % d == 0
                x ÷= d
            end
        end
        d += 1
    end
    x > 1 && push!(out, x)
    out
end

"""
    primitive_prime_divisor(m) -> Int | nothing

A prime `p` dividing `2^m − 1` but no `2^i − 1` for `i < m` (Notation 4.4).
Exists for `m > 1`, `m ≠ 6` by Zsygmondy's theorem — `nothing` at `m = 6`, which
is exactly why every equivalence theorem in the paper excludes `m = 6`.
"""
function primitive_prime_divisor(m::Integer)
    v = (1 << Int(m)) - 1
    for p in prime_factors(v)
        all(mod((1 << i) - 1, p) != 0 for i = 1:(Int(m)-1)) && return p
    end
    nothing
end

"""A primitive element of `M^×` under the pinned modulus."""
function primitive_element(fld::BiField)
    ord = order(fld) - 1
    for g = 2:(order(fld)-1)
        all(gpow(fld, g, ord ÷ p) != 1 for p in prime_factors(ord)) && return g
    end
    error("primitive_element: none found for m=$(fld.m)")
end

# ── Appendix B: the group action of G = M^× × GL(2, M) ──────────────────────

"""
    g_orbit(fld, p; limit) -> Set{NTuple{4,Int}}

Orbit of a biprojective polynomial `p` (with `p₁ ≠ 0`) under
`G = M^× × GL(2,M)`, acting by `((a,M)·f)(x,y) = a · f(c₁x+c₂y, c₃x+c₄y)`
(Appendix B).

BFS from a generating set of `G` rather than the whole group: scalar
multiplication by a primitive element, plus the standard generators of
`GL(2,M)` — `diag(g,1)`, the upper unitriangular matrix, and the swap.
"""
function g_orbit(fld::BiField, p::BiProj; limit::Int = typemax(Int))
    gen = primitive_element(fld)
    acts = (
        f -> biproj_scale(fld, f, gen),                 # M^× scalar
        f -> biproj_compose(fld, f, gen, 0, 0, 1),      # diag(g, 1)
        f -> biproj_compose(fld, f, 1, 1, 0, 1),        # upper unitriangular
        f -> biproj_compose(fld, f, 0, 1, 1, 0),        # swap
    )
    seen = Set{NTuple{4,Int}}((p.c,))
    stack = [p.c]
    while !isempty(stack) && length(seen) ≤ limit
        cur = BiProj(p.e, pop!(stack))
        for act in acts
            nxt = act(cur).c
            if !(nxt in seen)
                push!(seen, nxt)
                push!(stack, nxt)
            end
        end
    end
    seen
end

"""
    g_stabilizer_size(fld, p) -> Int

`|Stab_G(p)|` computed by orbit–stabilizer: `|G| / |orbit|` with
`|G| = (2^m − 1)·|GL(2,M)| = (2^m − 1)³(2^m + 1)2^m`. Lemma B.2 claims
`3(2^m − 1)` for every root-free `p` with `p₁ ≠ 0`.
"""
function g_stabilizer_size(fld::BiField, p::BiProj)
    N = order(fld)
    Gsize = big(N - 1)^3 * (N + 1) * N
    orb = length(g_orbit(fld, p))
    Int(Gsize ÷ orb)
end

"""
    rootfree_biprojectives(fld, k) -> Vector{NTuple{4,Int}}

All `(p₁,p₂,p₃,p₄)_q` with `p₁ ≠ 0` whose `f(x,1)` has no root in `M`.
Lemma B.1 predicts `(2^m+1)·2^m·(2^m−1)²/3` of them.
"""
function rootfree_biprojectives(fld::BiField, k::Integer)
    out = NTuple{4,Int}[]
    N = order(fld)
    for p1 = 1:(N-1), p2 = 0:(N-1), p3 = 0:(N-1), p4 = 0:(N-1)
        projective_rootfree(fld, BiProj(k, (p1, p2, p3, p4))) && push!(out, (p1, p2, p3, p4))
    end
    out
end

"""Lemma B.1's predicted count `(2^m+1)·2^m·(2^m−1)²/3`."""
lemma_b1_count(m::Integer) = ((1 << m) + 1) * (1 << m) * ((1 << m) - 1)^2 ÷ 3

# ── Report header ───────────────────────────────────────────────────────────

"""Paper banner (title, venue) plus the pinned-field caveat."""
function print_header(io::IO = stdout)
    print_banner(
        io,
        "Göloğlu, Kölsch (2025): Equivalences of biprojective almost perfect",
        "nonlinear functions — Electronic Journal of Combinatorics (accepted)",
        "",
        "Field M = F_{2^m} pinned to VBF.primitive_polynomial(m); the paper pins",
        "no modulus, so every element literal below is modulus-relative.",
    )
end
