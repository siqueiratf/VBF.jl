# Implements Section 5, Theorem 3 — new APN polynomials for m divisible by 6.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5 — New cases of AB and APN functions
#
# Pseudocode:
#   T(x) = trm/3(x^{2^i+1})
#   F1(x) = x + T(x)^2 + T(x)^4          (linear permutation of order dividing 6)
#   F2(x) = x^{2^i+1}                     (Gold power function)
#   F'  = F2 ∘ F1^{-1}                    (Theorem 3 construction)
#
#   NOTE: The theorem-statement formula for F1^{-1} is checked exhaustively
#   over GF(2^6) below. The construction F' = F2 ∘ F1^{-1} is implemented
#   directly by permutation inversion.
#
#   F_8 computer check (Theorem 3 proof, p. 771):
#   For all u ∈ F*_8, w ∈ F*_8 with tr_3(w)=0:
#     (u^{2^i+1}·w)^2 + (u^{2^i+1}·w)^4 ≠ u  [confirms F1 is a permutation]
#
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, differential_uniformity,
#               algebraic_degree, are_ccz_equivalent, are_ea_equivalent, gold_apn,
#               kasami_apn, kim_apn, apn_catalog_names, load_apn_function

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

"""
    theorem3_lut(m, i; modulus) -> Vector{Int}

LUT of the Theorem 3 APN function F' = F₂ ∘ F₁⁻¹ over GF(2^m), where
  T(x)  = trm/3(x^{2^i+1})
  F₁(x) = x + T(x)² + T(x)⁴
  F₂(x) = x^{2^i+1}
and F₁⁻¹ is obtained by permutation inversion.

Requires 6 | m and gcd(i, m) = 1.
"""
function theorem3_f1_lut(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    m % 6 == 0 || throw(ArgumentError("theorem3_lut: 6 must divide m, got m=$m"))
    gcd(i, m) == 1 || throw(ArgumentError("theorem3_lut: need gcd(i,m)=1, got i=$i, m=$m"))
    gold_exp = (1 << i) + 1
    N = 1 << m

    T(x) = gf_relative_trace(gf_pow(x, gold_exp, m; modulus = modulus), m, 3; modulus = modulus)
    F1(x) = begin
        tx = T(x)
        x ⊻ gf_pow(tx, 2, m; modulus = modulus) ⊻ gf_pow(tx, 4, m; modulus = modulus)
    end

    [F1(x) for x in 0:N-1]
end

function theorem3_paper_f1_inverse_lut(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    m % 6 == 0 || throw(ArgumentError("theorem3_lut: 6 must divide m, got m=$m"))
    gcd(i, m) == 1 || throw(ArgumentError("theorem3_lut: need gcd(i,m)=1, got i=$i, m=$m"))
    gold_exp = (1 << i) + 1
    N = 1 << m
    s = i % 3

    T(x) = gf_relative_trace(gf_pow(x, gold_exp, m; modulus = modulus), m, 3; modulus = modulus)
    paper_F1inv(x) = begin
        tx = T(x)
        tr_term = gf_trace(x, m; modulus = modulus) == 0 ? 0 : tx ⊻ gf_pow(tx, 1 << (2s), m; modulus = modulus)
        x ⊻ gf_pow(tx, 2, m; modulus = modulus) ⊻ gf_pow(tx, 4, m; modulus = modulus) ⊻ tr_term
    end

    [paper_F1inv(x) for x in 0:N-1]
end

# TODO(promote-to-core): inverse_permutation_lut inverts a raw permutation LUT.
# VBF core has `compositional_inverse(::SBox)` and `is_permutation`; a
# LUT-level `inverse_permutation_lut` (no SBox wrapping) would be a natural
# core helper. Kept paper-local for now (core is frozen).
function inverse_permutation_lut(lut::Vector{Int})
    N = length(lut)
    lut_inv = fill(-1, N)
    for x in 0:N-1
        y = lut[x+1]
        0 <= y < N || throw(ArgumentError("permutation value $y outside 0:$(N-1)"))
        lut_inv[y+1] == -1 || throw(ArgumentError("duplicate permutation value $y"))
        lut_inv[y+1] = x
    end
    all(!=(-1), lut_inv) || throw(ArgumentError("LUT is not a permutation"))
    lut_inv
end

function theorem3_lut(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    gold_exp = (1 << i) + 1
    N = 1 << m
    F2(x) = gf_pow(x, gold_exp, m; modulus = modulus)

    lut_F1inv = inverse_permutation_lut(theorem3_f1_lut(m, i; modulus = modulus))
    [F2(lut_F1inv[x+1]) for x in 0:N-1]
end

"""
    theorem3_paper_explicit_lut(m, i; modulus) -> Vector{Int}

The explicit closed form of F' as printed in the Theorem 3 statement (tex eq.
l.588–590), which the derivation multiplies out at l.666–669:

  F'(x) = [ x + tr_{m/3}(x^{2(2^i+1)} + x^{4(2^i+1)})
              + tr(x)·tr_{m/3}(x^{2^i+1} + x^{2^{2i}(2^i+1)}) ]^{2^i+1}

(the bracket is F₁⁻¹(x) = F₁⁵(x), then raised by F₂ = Gold). Implemented
literally so it can be checked against the permutation-inverse construction.
"""
function theorem3_paper_explicit_lut(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    m % 6 == 0 || throw(ArgumentError("theorem3_lut: 6 must divide m, got m=$m"))
    gcd(i, m) == 1 || throw(ArgumentError("theorem3_lut: need gcd(i,m)=1, got i=$i, m=$m"))
    gold_exp = (1 << i) + 1
    N = 1 << m
    tr3(x) = gf_relative_trace(x, m, 3; modulus = modulus)
    trr(x) = gf_trace(x, m; modulus = modulus)
    pw(x, e) = gf_pow(x, e, m; modulus = modulus)

    out = Vector{Int}(undef, N)
    for x in 0:N-1
        a1 = tr3(pw(x, 2 * gold_exp) ⊻ pw(x, 4 * gold_exp))
        a2 = tr3(pw(x, gold_exp) ⊻ pw(x, (1 << (2i)) * gold_exp))
        inner = x ⊻ a1 ⊻ (trr(x) == 1 ? a2 : 0)
        out[x+1] = pw(inner, gold_exp)
    end
    out
end

"""
    theorem3_explicit_formula_check(; m, i, io) -> NamedTuple

Verify the paper's explicit F' expansion (tex l.588–590 / l.666–669) matches the
permutation-inverse construction F₂∘F₁⁻¹, exhaustively over GF(2^m).
"""
function theorem3_explicit_formula_check(; m::Int = 6, i::Int = 1, io::IO = devnull)
    modulus = primitive_polynomial(m)
    constr = theorem3_lut(m, i; modulus = modulus)
    explicit = theorem3_paper_explicit_lut(m, i; modulus = modulus)
    N = length(constr)
    mism = count(x -> constr[x] != explicit[x], 1:N)
    ok = mism == 0

    print_section("Theorem 3 — explicit F' expansion vs. construction (GF(2^$m), i=$i)", io)
    print_kv("elements checked", N, io)
    print_check("explicit F' (l.588–590 / l.666–669) = F₂∘F₁⁻¹ (mismatches=$mism)", ok, io)
    print_kv("completeness", "exhaustive", io)

    (; ok, checked = N, mismatch_count = mism)
end

"""
    theorem3_ccz_to_gold_check(; m, i, io) -> NamedTuple

The paper's Conclusion states every function of Theorems 1–4 is CCZ-equivalent
to a Gold function. Verify that directly for Theorem 3's F' at GF(2^m) using the
(recently fixed) `are_ccz_equivalent` oracle, matching F' against `gold_apn(m, i)`.
This is a real CCZ/EA test — it replaces the earlier `deg == 4` heuristic as the
evidence for inequivalence-to-known / equivalence-to-Gold. F' is degree 4 (non-
quadratic) and a non-permutation, so this exercises the fixed non-permutation
path of the oracle.
"""
function theorem3_ccz_to_gold_check(; m::Int, i::Int, io::IO = devnull)
    modulus = primitive_polynomial(m)
    F = SBox{m}(theorem3_lut(m, i; modulus = modulus))
    G = gold_apn(m, i; modulus = modulus)
    is_ccz = are_ccz_equivalent(F, G)

    print_section("Theorem 3 — CCZ-equivalence to Gold x^{2^$i+1} (GF(2^$m))", io)
    print_check("F' is CCZ-equivalent to gold_apn($m, $i)", is_ccz, io)
    print_kv("deg(F')", algebraic_degree(F), io)

    (; is_ccz, m, i)
end

"""
    theorem3_f1_inverse_formula_check(; m, i, io) -> NamedTuple

Compare the paper's closed formula for F₁⁻¹ against the inverse permutation
obtained from the F₁ LUT. The report uses `m = 6`, so this checks all 64 field
elements.
"""
function theorem3_f1_inverse_formula_check(; m::Int = 6, i::Int = 1, io::IO = devnull)
    modulus = primitive_polynomial(m)
    true_inv = inverse_permutation_lut(theorem3_f1_lut(m, i; modulus = modulus))
    formula_inv = theorem3_paper_f1_inverse_lut(m, i; modulus = modulus)
    N = length(true_inv)
    mismatches = [(x, true_inv[x+1], formula_inv[x+1]) for x in 0:N-1 if true_inv[x+1] != formula_inv[x+1]]
    sample_x = min(32, N - 1)
    sample_inverse = true_inv[sample_x+1]
    sample_formula = formula_inv[sample_x+1]
    ok = isempty(mismatches)

    print_section("Theorem 3 — F1⁻¹ formula check (GF(2^$m), i=$i)", io)
    print_kv("elements checked", N, io)
    print_check("paper formula matches permutation inverse (mismatches=$(length(mismatches)))", ok, io)
    print_kv("sample x=$sample_x", "inverse=$sample_inverse, formula=$sample_formula", io)
    print_kv("completeness", "exhaustive", io)

    (; ok, checked = N, mismatch_count = length(mismatches), mismatches, sample_x, sample_inverse, sample_formula)
end

"""
    theorem3_f8_check(; io) -> NamedTuple

F_8 computer check from Theorem 3 proof (Budaghyan et al., p. 771):
For every u ∈ F*_8 and w ∈ F*_8 with tr_3(w) = 0:
  (u^{2^i+1}·w)^2 + (u^{2^i+1}·w)^4 ≠ u

Tested for i ∈ {1, 2} (covering both residue classes mod 3 for valid i).
This check is exact and exhaustive (at most 7×3×2 = 42 pairs).
"""
function theorem3_f8_check(; io::IO = devnull)
    mod3 = primitive_polynomial(3)
    N3 = 8

    violations = 0
    pairs_checked = 0

    for i in (1, 2)
        gold_exp = (1 << i) + 1
        for u in 1:N3-1, w in 1:N3-1
            gf_trace(w, 3; modulus = mod3) == 0 || continue
            v = gf_mul(gf_pow(u, gold_exp, 3; modulus = mod3), w, 3; modulus = mod3)
            lhs = gf_pow(v, 2, 3; modulus = mod3) ⊻ gf_pow(v, 4, 3; modulus = mod3)
            lhs == u && (violations += 1)
            pairs_checked += 1
        end
    end

    ok = violations == 0
    print_section("Theorem 3 — F_8 computer check (i=1,2)", io)
    print_kv("pairs (u ∈ F*_8, w ∈ {tr_3(w)=0,w≠0}, i∈{1,2})", pairs_checked, io)
    print_check("(u^{2^i+1}w)^2+(u^{2^i+1}w)^4 ≠ u for all pairs (violations=$violations)", ok, io)
    print_kv("completeness", "exhaustive", io)

    (; violations, pairs_checked, ok)
end

"""
    theorem3_ea_inequivalence_check(; m, i, io) -> NamedTuple

The claim Theorem 3 actually makes: F' has algebraic degree 4, and since for
`6 | m` no known APN function has algebraic degree 4, F' is **EA-inequivalent**
to every known APN function. `theorem3_ccz_to_gold_check` verifies the
*converse* half (F' *is* CCZ-equivalent to Gold) and says nothing about EA, so
the novelty claim needs its own test.

Runs `are_ea_equivalent(F', G; on_inconclusive = :throw)` — never
`:best_effort`, whose guessed `false` would manufacture the claim — against
every known APN in dimension `m`: the `n<m>_apn.toml` catalog entries plus the
directly-constructed `gold_apn`, `kasami_apn` and (at m=6) `kim_apn`.

The sound witness is the degree separation: every known APN at n=6 is quadratic,
F' has degree 4, and algebraic degree is an EA-invariant for degrees ≥ 2, so the
oracle decides each pair on an invariant rather than on a capped search.
"""
function theorem3_ea_inequivalence_check(; m::Int = 6, i::Int = 1, io::IO = devnull)
    modulus = primitive_polynomial(m)
    F = SBox{m}(theorem3_lut(m, i; modulus = modulus))
    deg_F = algebraic_degree(F)

    known = Pair{String,SBox}[]
    for name in apn_catalog_names()
        apn_catalog_metadata(name)["n"] == m || continue
        push!(known, name => load_apn_function(name))
    end
    for k in 1:m-1
        gcd(k, m) == 1 || continue
        push!(known, "gold_apn($m,$k)" => gold_apn(m, k; modulus = modulus))
        push!(known, "kasami_apn($m,$k)" => kasami_apn(m, k; modulus = modulus))
    end
    m == 6 && push!(known, "kim_apn()" => kim_apn())

    print_section("Theorem 3 — EA-inequivalence to known APN (GF(2^$m), i=$i)", io)
    print_kv("deg(F')", deg_F, io)
    results = Tuple{String,Bool,Int}[]
    all_inequiv = true
    degrees_separate = true
    for (name, G) in known
        eq = are_ea_equivalent(F, G; on_inconclusive = :throw)
        dg = algebraic_degree(G)
        push!(results, (name, eq, dg))
        eq && (all_inequiv = false)
        dg == deg_F && (degrees_separate = false)
        print_check("F' EA-inequivalent to $name (deg $dg)", !eq, io)
    end
    print_check("deg(F') = $deg_F separates F' from every known APN at n=$m",
                degrees_separate, io)
    print_kv("known APN compared", length(known), io)

    (; deg_F, all_inequiv, degrees_separate, n_compared = length(known), results)
end

"""
    theorem3_check(; m, i, io) -> NamedTuple

Verify Theorem 3 claims for one (m, i) pair:
- F' is APN (differential_uniformity == 2)
- algebraic degree of F' is 4
"""
function theorem3_check(; m::Int, i::Int, io::IO = devnull)
    modulus = primitive_polynomial(m)
    lut = theorem3_lut(m, i; modulus = modulus)
    s = SBox{m}(lut)

    is_apn = differential_uniformity(s) == 2
    deg = algebraic_degree(s)

    print_section("Theorem 3 — GF(2^$m), i=$i", io)
    print_check("APN (differential uniformity = 2)", is_apn, io)
    print_check("algebraic degree = 4", deg == 4, io)

    (; is_apn, deg)
end

function theorem3_report(io::IO = stdout)
    print_section("Section 5 — Theorem 3: APN polynomials (6 | m)", io)
    println(io, "  [NOTE] F1⁻¹ formula checked by exhaustive comparison with")
    println(io, "         the permutation inverse; F'=F2∘F1⁻¹ is still implemented")
    println(io, "         via permutation inversion.")
    theorem3_f1_inverse_formula_check(; m = 6, i = 1, io = io)
    theorem3_f1_inverse_formula_check(; m = 6, i = 5, io = io)
    theorem3_f8_check(; io = io)
    theorem3_explicit_formula_check(; m = 6, i = 1, io = io)
    theorem3_explicit_formula_check(; m = 6, i = 5, io = io)
    theorem3_check(; m = 6, i = 1, io = io)
    theorem3_check(; m = 6, i = 5, io = io)
    theorem3_ccz_to_gold_check(; m = 6, i = 1, io = io)
    theorem3_ccz_to_gold_check(; m = 6, i = 5, io = io)
    theorem3_ea_inequivalence_check(; m = 6, i = 1, io = io)
    theorem3_ea_inequivalence_check(; m = 6, i = 5, io = io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem3_report()
end
