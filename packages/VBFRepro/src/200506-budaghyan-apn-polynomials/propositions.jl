# Implements Sections 3–4 — Example 1, Propositions 3, 5 and 6.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 3 (CCZ-equivalence, Prop 3 + Example 1), 4 (Gold permutations, Prop 5/6)
#
# Pseudocode:
#   Example 1 (tex l.357–384): m = 2n+1, s ≡ n (mod 2),
#     L(y)      = Σ_{j=0}^{n-s} y^{2^{2j+s}}          (linear, L(1) = 1)
#     L⁻¹(x)    = x + x² + tr(x)
#     𝓛(x,y)    = (x + tr(x) + L(y),  y + tr(x))       — BOTH parts use BOTH vars
#     F(x) = x³ ; F₁(x) = L₁(x,F(x)) = x + tr(x) + L(x³) = L((x+1)³) + 1
#     F₁⁻¹(x)   = [L⁻¹(x+1)]^{1/3} + 1
#     F₂(x) = L₂(x,F(x)) = x³ + tr(x)
#     F' = F₂∘F₁⁻¹ = L⁻¹(x+1) + L⁻¹([L⁻¹(x+1)]^{1/3})
#              = A₁(G(A₂(x))) + A_drift(x)  with G = x^{1/3}, A₁ = L⁻¹,
#                A₂(x) = L⁻¹(x+1), A_drift = A₂  ⇒ F' is EA-equivalent to (x³)⁻¹.
#     ⇒ "L₁ depends on both variables" is NOT sufficient for EA-inequivalence.
#
#   Prop 3 (tex l.275): F' EA-equiv to F or F⁻¹ ⟺ ∃ linear permutation
#     𝓛 = (L₁,L₂) on F_2^{2m} with 𝓛(G_F) = G_{F'} and L₁ depending on one
#     variable only. Checked constructively in both one-variable shapes, with
#     Theorem 1's 𝓛 (L₁ on both variables, F' EA-inequiv. to every power
#     function by Prop 4) as the contrapositive witness.
#
#   Prop 5 (tex l.394): F(x) = L(x^{2^i+1}) + L'(x), gcd(m,i)=1. F is a
#     permutation ⟺ ∀u≠0 ∀v with tr(v)=tr(1): L(u^{2^i+1}·v) ≠ L'(u).
#
#   Prop 6 (tex l.409): F(x) = L(x^{2^i+1}) + x, m even, gcd(m,i)=1, L* the
#     adjoint of L. F is a permutation ⟺ ∀v with L*(v) ≠ 0 ∃u:
#     L*(v) = u^{2^i+1} and tr_{m/2}(v/u) ≠ 0.
#
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, gf_relative_trace,
#               primitive_polynomial, SBox, is_permutation, algebraic_degree,
#               F2LinearMap, F2AffineMap, ccz_equivalent_function,
#               compositional_inverse, random_linear_function

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))

using Random

# ── shared field/linear-map utilities ─────────────────────────────────────────

"""
    linear_map_lut(L::F2LinearMap) -> Vector{Int}

Truth table of an `F2LinearMap` as plain `Int`s, for use next to the GF(2^m)
helpers (which are all `Int`-based).
"""
linear_map_lut(L::F2LinearMap{N,T}) where {N,T} = [Int(L(T(x))) for x in 0:(1<<N)-1]

"""
    adjoint_lut(L_lut, m; modulus) -> Vector{Int}

LUT of the adjoint `L*` of the F₂-linear `L`, i.e. the unique linear map with
`tr(v·L(x)) = tr(L*(v)·x)` for all `v, x ∈ F_{2^m}` (Prop 6). Built by indexing
each `w` by the coordinate vector `(tr(w·2^j))_{j<m}` of the linear functional
`x ↦ tr(w·x)`; the trace form is non-degenerate, so that index is a bijection.
"""
function adjoint_lut(L_lut::Vector{Int}, m::Int; modulus::Int = primitive_polynomial(m))
    N = 1 << m
    functional_key(w) = begin
        k = 0
        for j in 0:m-1
            k |= gf_trace(gf_mul(w, 1 << j, m; modulus = modulus), m; modulus = modulus) << j
        end
        k
    end
    by_key = Dict{Int,Int}(functional_key(w) => w for w in 0:N-1)
    out = Vector{Int}(undef, N)
    for v in 0:N-1
        k = 0
        for j in 0:m-1
            k |= gf_trace(
                gf_mul(v, L_lut[(1<<j)+1], m; modulus = modulus), m; modulus = modulus,
            ) << j
        end
        out[v+1] = by_key[k]
    end
    out
end

# ── Example 1 ─────────────────────────────────────────────────────────────────

"""
    example1_L_lut(m; modulus) -> Vector{Int}

`L(y) = Σ_{j=0}^{n-s} y^{2^{2j+s}}` from Example 1, with `m = 2n+1` and
`s ≡ n (mod 2)`. The number of summands `n-s+1` is odd, hence `L(1) = 1` — the
fact the paper's derivation of `L((y+1)³) = L(y³) + y + tr(y) + 1` rests on.
"""
function example1_L_lut(m::Int; modulus::Int = primitive_polynomial(m))
    m % 2 == 1 || throw(ArgumentError("example1_L_lut: need m = 2n+1 odd, got m=$m"))
    m > 3 || throw(ArgumentError("example1_L_lut: need m > 3, got m=$m"))
    n = (m - 1) ÷ 2
    s = n % 2
    N = 1 << m
    [
        foldl(⊻, (gf_pow(y, 1 << (2j + s), m; modulus = modulus) for j in 0:(n-s)); init = 0)
        for y in 0:N-1
    ]
end

"""
    example1_check(; m, io) -> NamedTuple

Example 1 (tex l.357–384) — the counterexample to the naive converse of
Proposition 3: a linear permutation `𝓛 = (L₁, L₂)` on `F_{2^m}²` whose **both**
components depend on **both** variables, yet whose `F' = F₂∘F₁⁻¹` is
EA-equivalent to the inverse of the Gold AB function `x³`.

Everything in the example is checked exhaustively over `GF(2^m)`:
- `L` is a permutation and `L⁻¹(x) = x + x² + tr(x)`;
- `F₁(x) = x + tr(x) + L(x³)` is a permutation and equals `L((x+1)³) + 1`;
- `F₁⁻¹(x) = [L⁻¹(x+1)]^{1/3} + 1` (against the true permutation inverse);
- `𝓛` is a permutation of `F_{2^m}²` and both components depend on both variables;
- `F' = F₂∘F₁⁻¹` equals the paper's closed form
  `L⁻¹(x+1) + L⁻¹([L⁻¹(x+1)]^{1/3})`, which *is* an explicit EA-decomposition
  `A₁ ∘ x^{1/3} ∘ A₂ + A_drift` with `A₁ = L⁻¹`, `A₂(x) = L⁻¹(x+1)`,
  `A_drift = A₂` — verified pointwise, so the EA-equivalence to `(x³)⁻¹` is a
  constructed witness rather than an oracle verdict.
"""
function example1_check(; m::Int = 5, io::IO = devnull)
    modulus = primitive_polynomial(m)
    N = 1 << m
    n = (m - 1) ÷ 2
    s = n % 2
    pw(x, e) = gf_pow(x, e, m; modulus = modulus)
    tr(x) = gf_trace(x, m; modulus = modulus)

    L_lut = example1_L_lut(m; modulus = modulus)
    L(y) = L_lut[y+1]
    Linv(x) = x ⊻ pw(x, 2) ⊻ tr(x)                       # paper: L⁻¹(x) = x + x² + tr(x)

    L_is_perm = is_permutation(SBox{m}(L_lut))
    Linv_ok = all(L(Linv(x)) == x && Linv(L(x)) == x for x in 0:N-1)
    L_one = L(1)

    # F(x) = x³ ; F₁ = L₁(x, F(x)) ; F₂ = L₂(x, F(x))
    F1_lut = [x ⊻ tr(x) ⊻ L(pw(x, 3)) for x in 0:N-1]
    F1_is_perm = is_permutation(SBox{m}(F1_lut))
    F1_alt_ok = all(F1_lut[x+1] == L(pw(x ⊻ 1, 3)) ⊻ 1 for x in 0:N-1)   # L((x+1)³)+1

    d3 = invmod(3, N - 1)                                 # 1/3 on F_{2^m}, m odd
    F1inv_true = compositional_inverse(SBox{m}(F1_lut)).lut
    F1inv_formula = [pw(Linv(x ⊻ 1), d3) ⊻ 1 for x in 0:N-1]
    F1inv_ok = all(Int(F1inv_true[x+1]) == F1inv_formula[x+1] for x in 0:N-1)

    F2(x) = pw(x, 3) ⊻ tr(x)
    Fp = [F2(Int(F1inv_true[x+1])) for x in 0:N-1]

    # Paper's closed form, which is literally an EA-decomposition of x^{1/3}.
    A2(x) = Linv(x ⊻ 1)                                   # affine permutation
    Fp_closed = [(u = A2(x); Linv(pw(u, d3)) ⊻ u) for x in 0:N-1]
    closed_ok = Fp == Fp_closed
    A2_is_perm = is_permutation(SBox{m}([A2(x) for x in 0:N-1]))

    # 𝓛(x,y) = (x + tr(x) + L(y), y + tr(x)) — permutation of F_{2^m}², both parts
    # depending on both variables.
    L1(x, y) = x ⊻ tr(x) ⊻ L(y)
    L2(x, y) = y ⊻ tr(x)
    pairs = Set{Tuple{Int,Int}}()
    for x in 0:N-1, y in 0:N-1
        push!(pairs, (L1(x, y), L2(x, y)))
    end
    script_L_is_perm = length(pairs) == N * N
    L1_uses_x = any(L1(x, 0) != L1(0, 0) for x in 0:N-1)
    L1_uses_y = any(L1(0, y) != L1(0, 0) for y in 0:N-1)
    L2_uses_x = any(L2(x, 0) != L2(0, 0) for x in 0:N-1)
    L2_uses_y = any(L2(0, y) != L2(0, 0) for y in 0:N-1)
    both_depend_on_both = L1_uses_x && L1_uses_y && L2_uses_x && L2_uses_y

    deg_Fp = algebraic_degree(SBox{m}(Fp))
    deg_cuberoot = algebraic_degree(SBox{m}([pw(x, d3) for x in 0:N-1]))

    print_section("Example 1 — L₁,L₂ both depend on both variables, yet F' ~EA (x³)⁻¹ (GF(2^$m))", io)
    print_kv("m = 2n+1", "n=$n, s=$s, L has $(n - s + 1) summands", io)
    print_check("L is a permutation and L(1) = 1 (got $L_one)", L_is_perm && L_one == 1, io)
    print_check("L⁻¹(x) = x + x² + tr(x)", Linv_ok, io)
    print_check("F₁(x) = x + tr(x) + L(x³) is a permutation", F1_is_perm, io)
    print_check("F₁(x) = L((x+1)³) + 1", F1_alt_ok, io)
    print_check("F₁⁻¹(x) = [L⁻¹(x+1)]^{1/3} + 1  (1/3 = $d3)", F1inv_ok, io)
    print_check("𝓛(x,y) = (x+tr(x)+L(y), y+tr(x)) is a permutation of F_{2^$m}²", script_L_is_perm, io)
    print_check("BOTH L₁ and L₂ depend on BOTH variables", both_depend_on_both, io)
    print_check("F' = L⁻¹(x+1) + L⁻¹([L⁻¹(x+1)]^{1/3})", closed_ok, io)
    print_check("that closed form is an EA-witness A₁∘x^{1/3}∘A₂ + A_drift (A₂ affine perm)",
                closed_ok && A2_is_perm && L_is_perm, io)
    print_kv("deg F' / deg x^{1/3}", "$deg_Fp / $deg_cuberoot", io)
    print_kv("completeness", "exhaustive over $N elements", io)

    (; m, n, s, L_is_perm, L_one, Linv_ok, F1_is_perm, F1_alt_ok, F1inv_ok,
       script_L_is_perm, both_depend_on_both, closed_ok, A2_is_perm,
       ea_witness_ok = closed_ok && A2_is_perm && L_is_perm,
       d3, deg_Fp, deg_cuberoot, checked = N)
end

# ── Proposition 3 ─────────────────────────────────────────────────────────────

"""
    pair_linear_map(m, L1, L2) -> F2LinearMap

The `2m`-bit linear map `(x, y) ↦ (L1(x,y), L2(x,y))` in the packing used by
`FunctionGraph` / `ccz_equivalent_function`: a graph point is `(x << m) | y`, so
bits `0:m-1` carry `y` and bits `m:2m-1` carry `x`, and the image packs `L1` in
the high half and `L2` in the low half.
"""
function pair_linear_map(m::Int, L1, L2)
    cols = Int[]
    for j in 0:m-1                       # e_j with j < m ↦ (x, y) = (0, 2^j)
        push!(cols, (L1(0, 1 << j) << m) | L2(0, 1 << j))
    end
    for j in 0:m-1                       # e_{m+j}          ↦ (x, y) = (2^j, 0)
        push!(cols, (L1(1 << j, 0) << m) | L2(1 << j, 0))
    end
    F2LinearMap{2m}(cols)
end

"""
    prop3_check(; m, i, seed, io) -> NamedTuple

Proposition 3 (tex l.275): `F'` is EA-equivalent to `F` or to `F⁻¹` **iff** some
linear permutation `𝓛 = (L₁, L₂)` with `𝓛(G_F) = G_{F'}` has `L₁` depending on
only one variable.

Checked by construction on the Gold function `F(x) = x^{2^i+1}` over `GF(2^m)`
(`m` odd, so `F` is a permutation and `F⁻¹` exists):

- **`L₁(x,y) = L(x)`** with `L`, `M₂` invertible and `L₂(x,y) = M₁(x) + M₂(y)`.
  `F'` is read off the graph image `𝓛(G_F)` (never from the formula), then the
  EA-witness `F'(z) = M₂(F(L⁻¹(z))) + M₁(L⁻¹(z))` is verified pointwise ⇒ `F'` is
  EA-equivalent to `F`.
- **`L₁(x,y) = L(y)`** with `L`, `M₁` invertible. Same, against
  `F'(z) = M₁(F⁻¹(L⁻¹(z))) + M₂(L⁻¹(z))` ⇒ `F'` is EA-equivalent to `F⁻¹`.
- **contrapositive**: Theorem 1's own `𝓛(x,y) = (x + tr(x) + tr(y), y + tr(x) + tr(y))`
  has `L₁` depending on both variables; its graph image is exactly Theorem 1's
  `F'`, which Proposition 4 certifies EA-inequivalent to *every* power function —
  hence to both `F` and `F⁻¹`. By Proposition 3 no `𝓛` with a one-variable `L₁`
  can produce it.
"""
function prop3_check(; m::Int = 5, i::Int = 1, seed::Int = 20050601, io::IO = devnull)
    m % 2 == 1 || throw(ArgumentError("prop3_check: need m odd so x^{2^i+1} is a permutation"))
    modulus = primitive_polynomial(m)
    N = 1 << m
    gold_exp = (1 << i) + 1
    pw(x, e) = gf_pow(x, e, m; modulus = modulus)
    tr(x) = gf_trace(x, m; modulus = modulus)

    F = SBox{m}([pw(x, gold_exp) for x in 0:N-1])
    is_permutation(F) || throw(ArgumentError("prop3_check: x^{2^i+1} is not a permutation at m=$m, i=$i"))
    Finv = compositional_inverse(F)

    rng = Xoshiro(seed)
    Lm = random_invertible_linear_map(rng, Val(m))
    M1m = random_invertible_linear_map(rng, Val(m))
    M2m = random_invertible_linear_map(rng, Val(m))
    Lv = linear_map_lut(Lm)
    M1v = linear_map_lut(M1m)
    M2v = linear_map_lut(M2m)
    Linv_lut = compositional_inverse(SBox{m}(Lv)).lut

    # --- case A: L₁(x,y) = L(x)  ⇒  F' EA-equivalent to F -----------------------
    mapA = pair_linear_map(m, (x, y) -> Lv[x+1], (x, y) -> M1v[x+1] ⊻ M2v[y+1])
    FpA = ccz_equivalent_function(F, F2AffineMap(mapA, 0))
    caseA_is_function = FpA !== nothing
    caseA_ok = caseA_is_function && all(
        Int(FpA.lut[z+1]) ==
        M2v[Int(F.lut[Int(Linv_lut[z+1])+1])+1] ⊻ M1v[Int(Linv_lut[z+1])+1]
        for z in 0:N-1
    )

    # --- case B: L₁(x,y) = L(y)  ⇒  F' EA-equivalent to F⁻¹ ---------------------
    mapB = pair_linear_map(m, (x, y) -> Lv[y+1], (x, y) -> M1v[x+1] ⊻ M2v[y+1])
    FpB = ccz_equivalent_function(F, F2AffineMap(mapB, 0))
    caseB_is_function = FpB !== nothing
    caseB_ok = caseB_is_function && all(
        Int(FpB.lut[z+1]) ==
        M1v[Int(Finv.lut[Int(Linv_lut[z+1])+1])+1] ⊻ M2v[Int(Linv_lut[z+1])+1]
        for z in 0:N-1
    )

    # --- contrapositive: Theorem 1's 𝓛, L₁ depending on both variables ---------
    # F₁(x) = x + tr(x) + tr(x^{2^i+1}), F₂(x) = x^{2^i+1} + tr(x^{2^i+1}) + tr(x)
    # (the a = 1 case of the Theorem 1 proof, tex l.489–493).
    mapC = pair_linear_map(m, (x, y) -> x ⊻ tr(x) ⊻ tr(y), (x, y) -> y ⊻ tr(y) ⊻ tr(x))
    FpC = ccz_equivalent_function(F, F2AffineMap(mapC, 0))
    t1_lut = theorem1_lut(m, i; modulus = modulus)
    caseC_matches_theorem1 = FpC !== nothing && all(Int(FpC.lut[x+1]) == t1_lut[x+1] for x in 0:N-1)
    L1C_uses_x = any((x ⊻ tr(x)) != 0 for x in 0:N-1)
    L1C_uses_y = any(tr(y) != 0 for y in 0:N-1)
    caseC_L1_both = L1C_uses_x && L1C_uses_y
    degC = algebraic_degree(SBox{m}(t1_lut))
    caseC_prop4_witnesses = length(prop4_witnesses(t1_lut, m, degC; modulus = modulus))
    caseC_ea_inequivalent = caseC_prop4_witnesses > 0

    print_section("Proposition 3 — L₁ on one variable ⟺ EA-equivalent to F or F⁻¹ (GF(2^$m), i=$i)", io)
    print_check("L₁(x,y)=L(x): 𝓛(G_F) is a graph", caseA_is_function, io)
    print_check("L₁(x,y)=L(x): F' = M₂∘F∘L⁻¹ + M₁∘L⁻¹  ⇒ EA-equivalent to F", caseA_ok, io)
    print_check("L₁(x,y)=L(y): 𝓛(G_F) is a graph", caseB_is_function, io)
    print_check("L₁(x,y)=L(y): F' = M₁∘F⁻¹∘L⁻¹ + M₂∘L⁻¹ ⇒ EA-equivalent to F⁻¹", caseB_ok, io)
    print_check("Theorem 1's 𝓛: L₁ depends on BOTH variables", caseC_L1_both, io)
    print_check("Theorem 1's 𝓛: 𝓛(G_F) is exactly Theorem 1's F'", caseC_matches_theorem1, io)
    print_kv("Prop 4 witnesses c for that F'", "$caseC_prop4_witnesses / $(N - 1)", io)
    print_check("⇒ F' EA-inequivalent to every power function (so to F and F⁻¹): " *
                "no one-variable L₁ can yield it", caseC_ea_inequivalent, io)
    print_kv("completeness", "exhaustive over $N elements per case", io)

    (; m, i, caseA_is_function, caseA_ok, caseB_is_function, caseB_ok,
       caseC_L1_both, caseC_matches_theorem1, caseC_prop4_witnesses,
       caseC_ea_inequivalent, checked = N)
end

# ── Proposition 5 ─────────────────────────────────────────────────────────────

"""
    prop5_criterion(m, i, L_lut, Lp_lut; modulus) -> Bool

The Proposition 5 predicate: `true` iff `L(u^{2^i+1}·v) ≠ L'(u)` for every
`u ≠ 0` and every `v` with `tr(v) = tr(1)`.
"""
function prop5_criterion(
    m::Int,
    i::Int,
    L_lut::Vector{Int},
    Lp_lut::Vector{Int};
    modulus::Int = primitive_polynomial(m),
)
    N = 1 << m
    gold_exp = (1 << i) + 1
    tr1 = gf_trace(1, m; modulus = modulus)
    vs = [v for v in 0:N-1 if gf_trace(v, m; modulus = modulus) == tr1]
    for u in 1:N-1
        ug = gf_pow(u, gold_exp, m; modulus = modulus)
        for v in vs
            L_lut[gf_mul(ug, v, m; modulus = modulus)+1] == Lp_lut[u+1] && return false
        end
    end
    true
end

"""
    prop5_function_lut(m, i, L_lut, Lp_lut; modulus) -> Vector{Int}

`F(x) = L(x^{2^i+1}) + L'(x)`.
"""
function prop5_function_lut(
    m::Int,
    i::Int,
    L_lut::Vector{Int},
    Lp_lut::Vector{Int};
    modulus::Int = primitive_polynomial(m),
)
    N = 1 << m
    gold_exp = (1 << i) + 1
    [L_lut[gf_pow(x, gold_exp, m; modulus = modulus)+1] ⊻ Lp_lut[x+1] for x in 0:N-1]
end

# `L(y) = tr_{m/3}(y² + y⁴)` with `L'(x) = x` is Theorem 3's F₁ — a *permutation*
# instance of Prop 5's shape, so the criterion is not only exercised on
# non-permutations.
function _theorem3_L_lut(m::Int; modulus::Int = primitive_polynomial(m))
    N = 1 << m
    [
        gf_relative_trace(
            gf_pow(y, 2, m; modulus = modulus) ⊻ gf_pow(y, 4, m; modulus = modulus),
            m, 3; modulus = modulus,
        ) for y in 0:N-1
    ]
end

"""
    prop5_check(; m, i, trials, seed, io) -> NamedTuple

Proposition 5 (tex l.394) verified by brute force: for every tested pair of
linear `(L, L')` the criterion must agree *exactly* with `is_permutation` of
`F(x) = L(x^{2^i+1}) + L'(x)`.

The pool always contains permutation instances (otherwise the "⟸" half is
vacuous): `L = 0` with `L'` invertible; `L =` identity with `L' = 0` (a
permutation exactly for `m` odd, matching `gcd(2^i+1, 2^m−1) = 1`); and, for
`3 | m`, Theorem 3's `L(y) = tr_{m/3}(y²+y⁴)` with `L'(x) = x`. The remaining
`trials` pairs are drawn uniformly at random.
"""
function prop5_check(;
    m::Int = 6,
    i::Int = 1,
    trials::Int = 60,
    seed::Int = 20050602,
    io::IO = devnull,
)
    modulus = primitive_polynomial(m)
    N = 1 << m
    rng = Xoshiro(seed)

    zero_lut = zeros(Int, N)
    id_lut = collect(0:N-1)
    pool = Vector{Tuple{String,Vector{Int},Vector{Int}}}()
    push!(pool, ("L=0, L'=id", zero_lut, id_lut))
    push!(pool, ("L=0, L'=random invertible", zero_lut,
                 linear_map_lut(random_invertible_linear_map(rng, Val(m)))))
    push!(pool, ("L=id, L'=0", id_lut, zero_lut))
    m % 3 == 0 && push!(pool, ("Theorem 3 F₁: L=tr_{m/3}(y²+y⁴), L'=id",
                               _theorem3_L_lut(m; modulus = modulus), id_lut))
    for t in 1:trials
        push!(pool, ("random #$t",
                     linear_map_lut(random_linear_function(rng, Val(m))),
                     linear_map_lut(random_linear_function(rng, Val(m)))))
    end

    agree = 0
    permutations = 0
    disagreements = String[]
    for (name, L_lut, Lp_lut) in pool
        isperm = is_permutation(SBox{m}(prop5_function_lut(m, i, L_lut, Lp_lut; modulus = modulus)))
        crit = prop5_criterion(m, i, L_lut, Lp_lut; modulus = modulus)
        isperm == crit ? (agree += 1) : push!(disagreements, name)
        isperm && (permutations += 1)
    end

    ok = isempty(disagreements)
    print_section("Proposition 5 — permutation criterion for L(x^{2^$i+1})+L'(x) (GF(2^$m))", io)
    print_kv("(L,L') pairs tested", length(pool), io)
    print_kv("of which permutations", permutations, io)
    print_check("criterion ≡ is_permutation on every pair (agree=$agree/$(length(pool)))", ok, io)
    print_check("the permutation branch is non-vacuous", permutations > 0, io)

    (; m, i, tested = length(pool), agree, permutations, ok, disagreements)
end

"""
    prop5_exhaustive_check(; m, i, io) -> NamedTuple

Exhaustive form of [`prop5_check`](@ref) at small `m`: **all** `2^{m²}` linear
`L` with `L'` fixed to the identity, and all `2^{m²}` linear `L'` with `L` fixed
to the identity. At `m = 4` that is 2·65536 pairs, cheap enough to leave nothing
to sampling.
"""
function prop5_exhaustive_check(; m::Int = 4, i::Int = 1, io::IO = devnull)
    m <= 4 || throw(ArgumentError("prop5_exhaustive_check: 2^(m²) blows up past m=4, got m=$m"))
    modulus = primitive_polynomial(m)
    N = 1 << m
    id_lut = collect(0:N-1)

    agree = 0
    tested = 0
    permutations = 0
    for fix_second in (true, false), packed in 0:(1<<(m*m))-1
        cols = [(packed >> (m * j)) & (N - 1) for j in 0:m-1]
        var_lut = linear_map_lut(F2LinearMap{m}(cols))
        L_lut, Lp_lut = fix_second ? (var_lut, id_lut) : (id_lut, var_lut)
        isperm = is_permutation(SBox{m}(prop5_function_lut(m, i, L_lut, Lp_lut; modulus = modulus)))
        crit = prop5_criterion(m, i, L_lut, Lp_lut; modulus = modulus)
        isperm == crit && (agree += 1)
        isperm && (permutations += 1)
        tested += 1
    end

    ok = agree == tested
    print_section("Proposition 5 — exhaustive over all linear maps (GF(2^$m), i=$i)", io)
    print_kv("(L,L') pairs tested", tested, io)
    print_kv("of which permutations", permutations, io)
    print_check("criterion ≡ is_permutation on every pair", ok, io)
    print_kv("completeness", "exhaustive in one factor (L'=id, then L=id)", io)

    (; m, i, tested, agree, permutations, ok)
end

# ── Proposition 6 ─────────────────────────────────────────────────────────────

"""
    prop6_criterion(m, i, L_lut; modulus) -> Bool

The Proposition 6 predicate for `F(x) = L(x^{2^i+1}) + x` with `m` even: `true`
iff for every `v` with `L*(v) ≠ 0` there is a `u` with `L*(v) = u^{2^i+1}` and
`tr_{m/2}(v/u) ≠ 0`.
"""
function prop6_criterion(
    m::Int,
    i::Int,
    L_lut::Vector{Int};
    modulus::Int = primitive_polynomial(m),
    adj::Union{Nothing,Vector{Int}} = nothing,
)
    m % 2 == 0 || throw(ArgumentError("prop6_criterion: Proposition 6 needs m even, got m=$m"))
    N = 1 << m
    gold_exp = (1 << i) + 1
    A = adj === nothing ? adjoint_lut(L_lut, m; modulus = modulus) : adj
    gold = [gf_pow(u, gold_exp, m; modulus = modulus) for u in 0:N-1]
    for v in 0:N-1
        z = A[v+1]
        z == 0 && continue
        found = false
        for u in 1:N-1
            gold[u+1] == z || continue
            vu = gf_mul(v, gf_inv(u, m; modulus = modulus), m; modulus = modulus)
            if gf_relative_trace(vu, m, 2; modulus = modulus) != 0
                found = true
                break
            end
        end
        found || return false
    end
    true
end

"""
    prop6_check(; m, i, trials, seed, io) -> NamedTuple

Proposition 6 (tex l.409) by brute force over linear `L`, `m` even: the
adjoint criterion must agree exactly with `is_permutation` of
`F(x) = L(x^{2^i+1}) + x`.

The adjoint itself is verified first (`tr(v·L(x)) = tr(L*(v)·x)` over all
`(v, x)` at `m = 4`, sampled above that), because a wrong `L*` would make the
criterion agree for the wrong reason. `L = 0` (so `F = x`) and, for `3 | m`,
Theorem 3's `L(y) = tr_{m/3}(y²+y⁴)` supply permutation instances.
"""
function prop6_check(;
    m::Int = 6,
    i::Int = 1,
    trials::Int = 25,
    seed::Int = 20050603,
    io::IO = devnull,
)
    m % 2 == 0 || throw(ArgumentError("prop6_check: Proposition 6 needs m even, got m=$m"))
    modulus = primitive_polynomial(m)
    N = 1 << m
    rng = Xoshiro(seed)
    id_lut = collect(0:N-1)

    pool = Vector{Tuple{String,Vector{Int}}}()
    push!(pool, ("L=0", zeros(Int, N)))
    push!(pool, ("L=id", id_lut))
    m % 3 == 0 && push!(pool, ("Theorem 3 F₁: L=tr_{m/3}(y²+y⁴)", _theorem3_L_lut(m; modulus = modulus)))
    for t in 1:trials
        push!(pool, ("random #$t", linear_map_lut(random_linear_function(rng, Val(m)))))
    end

    # adjoint sanity: tr(v·L(x)) = tr(L*(v)·x)
    adj_ok = true
    for (_, L_lut) in pool
        A = adjoint_lut(L_lut, m; modulus = modulus)
        for v in 0:min(N - 1, 63), x in 0:min(N - 1, 63)
            lhs = gf_trace(gf_mul(v, L_lut[x+1], m; modulus = modulus), m; modulus = modulus)
            rhs = gf_trace(gf_mul(A[v+1], x, m; modulus = modulus), m; modulus = modulus)
            if lhs != rhs
                adj_ok = false
                break
            end
        end
        adj_ok || break
    end

    agree = 0
    permutations = 0
    disagreements = String[]
    for (name, L_lut) in pool
        F_lut = prop5_function_lut(m, i, L_lut, id_lut; modulus = modulus)   # L(x^{2^i+1}) + x
        isperm = is_permutation(SBox{m}(F_lut))
        crit = prop6_criterion(m, i, L_lut; modulus = modulus)
        isperm == crit ? (agree += 1) : push!(disagreements, name)
        isperm && (permutations += 1)
    end

    ok = isempty(disagreements)
    print_section("Proposition 6 — adjoint permutation criterion for L(x^{2^$i+1})+x (GF(2^$m))", io)
    print_check("adjoint L* satisfies tr(v·L(x)) = tr(L*(v)·x)", adj_ok, io)
    print_kv("L tested", length(pool), io)
    print_kv("of which permutations", permutations, io)
    print_check("criterion ≡ is_permutation on every L (agree=$agree/$(length(pool)))", ok, io)
    print_check("the permutation branch is non-vacuous", permutations > 0, io)

    (; m, i, tested = length(pool), agree, permutations, ok, adj_ok, disagreements)
end

"""
    prop6_exhaustive_check(; m, i, io) -> NamedTuple

Exhaustive form of [`prop6_check`](@ref): all `2^{m²}` linear `L` at `m = 4`
(65536 maps, 16 of which make `L(x³)+x` a permutation).
"""
function prop6_exhaustive_check(; m::Int = 4, i::Int = 1, io::IO = devnull)
    m <= 4 || throw(ArgumentError("prop6_exhaustive_check: 2^(m²) blows up past m=4, got m=$m"))
    m % 2 == 0 || throw(ArgumentError("prop6_exhaustive_check: Proposition 6 needs m even"))
    modulus = primitive_polynomial(m)
    N = 1 << m
    id_lut = collect(0:N-1)

    agree = 0
    tested = 0
    permutations = 0
    for packed in 0:(1<<(m*m))-1
        cols = [(packed >> (m * j)) & (N - 1) for j in 0:m-1]
        L_lut = linear_map_lut(F2LinearMap{m}(cols))
        isperm = is_permutation(SBox{m}(prop5_function_lut(m, i, L_lut, id_lut; modulus = modulus)))
        crit = prop6_criterion(m, i, L_lut; modulus = modulus)
        isperm == crit && (agree += 1)
        isperm && (permutations += 1)
        tested += 1
    end

    ok = agree == tested
    print_section("Proposition 6 — exhaustive over all $tested linear L (GF(2^$m), i=$i)", io)
    print_kv("of which permutations", permutations, io)
    print_check("criterion ≡ is_permutation on every L", ok, io)
    print_kv("completeness", "exhaustive", io)

    (; m, i, tested, agree, permutations, ok)
end

# ── report ────────────────────────────────────────────────────────────────────

function propositions_report(io::IO = stdout)
    print_section("Sections 3–4 — Example 1 and Propositions 3, 5, 6", io)
    println(io, "  [SCOPE] Propositions 1 and 2 (the transversality characterisation and")
    println(io, "          CCZ-invariance of Δ_F/Λ_F) and Remarks 1–3 are the derivation")
    println(io, "          apparatus behind Theorems 1–4 rather than checkable claims of")
    println(io, "          their own; they are exercised implicitly by Theorems 1–4.")
    example1_check(; m = 5, io = io)
    example1_check(; m = 7, io = io)
    prop3_check(; m = 5, i = 1, io = io)
    prop3_check(; m = 5, i = 2, io = io)
    prop5_exhaustive_check(; m = 4, i = 1, io = io)
    prop5_check(; m = 6, i = 1, io = io)
    prop5_check(; m = 8, i = 3, io = io)
    prop5_check(; m = 5, i = 1, io = io)
    prop6_exhaustive_check(; m = 4, i = 1, io = io)
    prop6_check(; m = 6, i = 1, io = io)
    prop6_check(; m = 8, i = 3, io = io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    propositions_report()
end
