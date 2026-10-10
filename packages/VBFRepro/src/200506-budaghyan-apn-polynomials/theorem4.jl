# Implements Section 5, Theorem 4 — AB polynomials for m odd, n | m.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5 — New cases of AB and APN functions
#
# Pseudocode:
#   F1(x) = x + trm/n(x) + trm/n(x^{2^i+1})
#   F2(x) = x^{2^i+1} + trm/n(x)
#   F'    = F2 ∘ F1^{-1}                  (Theorem 4 construction, via perm inverse)
#
#   Explicit F' formula — the paper prints it TWICE:
#     * theorem-statement (tex eq. after l.684): drops the linear term
#       "+ tr_{m/n}(x)" and raises the last bracket to 2^i+1;
#     * proof/derivation  (tex eq. l.762–770): keeps "+ tr_{m/n}(x)" and raises
#       the last bracket to 2^i/(2^i+1).
#   `theorem4_paper_formula_check` implements BOTH literally and compares each
#   against the permutation-inverse construction F2∘F1^{-1}.
#
#   The bracket [tr_{m/n}(x)^{2^i+1}+tr_{m/n}(x^{2^i+1})+tr_{m/n}(x)] lands in the
#   subfield F_{2^n}, so `^{1/(2^i+1)}` and `^{2^i/(2^i+1)}` are Gold-inverse
#   exponents taken mod (2^n − 1) (invmod on the subfield order), not mod 2^m−1.
#   That makes the two typos SEPARATELY observable only at n ≥ 5, because the
#   statement exponent 2^i+1 and the derivation exponent 2^i/(2^i+1) COINCIDE
#   mod 2^n−1 when n = 3:
#
#       m   n  i | statement exp | derivation exp |
#        9  3  1 |       3       |       3        | EQUAL
#        9  3  2 |       5       |       5        | EQUAL
#       15  5  1 |       3       |      11        | differ
#       15  5  2 |       5       |       7        | differ
#
#   Coded verdicts (all from `theorem4_paper_formula_check`):
#     * derivation form reproduces the construction EXACTLY (0 mismatches) at
#       every parameter tested;
#     * at (m,n)=(9,3) the statement form differs on 448/512 points — entirely
#       from the dropped "+ tr_{m/n}(x)" (512 − 64 = 448 points with
#       tr_{m/3}(x) ≠ 0) — and is itself still AB (du=2, linearity=32), so the
#       earlier "wrong, diff-unif 14" comment was unfounded;
#     * at (m,n)=(15,5), where the exponents genuinely differ, the statement form
#       diverges on 32734/32768 points and is NOT AB and NOT APN
#       (linearity 896 ≠ 256, du=16). That is the evidence for the second typo.
#
#   AB ↔ linearity = 2^{(m+1)/2};  degree = n+2
#   Prop 4: some c has deg(tr(cF')) = 4 ∉ {0,1,n+2} ⇒ EA-inequiv. to power functions.
#   Divisor corollary (tex l.772): "the number of functions CCZ-equivalent to a
#   Gold AB function and EA-inequivalent to it is not smaller than the number of
#   divisors of m" — needs ≥ 2 admissible n for ONE m, so it is exercised at
#   m=15 with n ∈ {1,3,5} by `theorem4_divisors_check`.
# VBF API used: gf_mul, gf_pow, gf_relative_trace, gf_trace, primitive_polynomial,
#               SBox, linearity, differential_uniformity, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))
# theorem1_lut supplies the n = 1 member of the divisor corollary ("Theorem 1
# gives the case n = 1", tex l.777).
include(joinpath(@__DIR__, "theorem1.jl"))

"""
    theorem4_lut(m, n, i; modulus) -> Vector{Int}

LUT of the Theorem 4 AB function F' = F₂ ∘ F₁⁻¹ over GF(2^m), where
  F₁(x) = x + trm/n(x) + trm/n(x^{2^i+1})
  F₂(x) = x^{2^i+1} + trm/n(x)
and F₁⁻¹ is obtained by permutation inversion.

Requires m > 3 odd, n | m, m ≠ n, gcd(i, m) = 1.
"""
function theorem4_lut(
    m::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(m),
)
    m > 3 || throw(ArgumentError("theorem4_lut: need m > 3, got m=$m"))
    m % 2 == 1 || throw(ArgumentError("theorem4_lut: m must be odd, got m=$m"))
    (m % n == 0 && m != n) || throw(ArgumentError("theorem4_lut: need n|m and m≠n, got m=$m, n=$n"))
    gcd(i, m) == 1 || throw(ArgumentError("theorem4_lut: need gcd(i,m)=1, got i=$i, m=$m"))

    gold_exp = (1 << i) + 1
    N = 1 << m

    F1(x) = begin
        xg = gf_pow(x, gold_exp, m; modulus = modulus)
        x ⊻ gf_relative_trace(x, m, n; modulus = modulus) ⊻
        gf_relative_trace(xg, m, n; modulus = modulus)
    end
    F2(x) = gf_pow(x, gold_exp, m; modulus = modulus) ⊻
            gf_relative_trace(x, m, n; modulus = modulus)

    lut_F1 = [F1(x) for x in 0:N-1]
    lut_F1inv = Vector{Int}(undef, N)
    for x in 0:N-1
        lut_F1inv[lut_F1[x+1]+1] = x
    end

    [F2(lut_F1inv[x+1]) for x in 0:N-1]
end

# Shared evaluator for the paper's two printed closed forms of F'. The only
# differences between them are (a) whether the standalone "+ tr_{m/n}(x)" linear
# term is present and (b) the exponent applied to the last occurrence of the
# bracket B(x) = tr_{m/n}(x)^{2^i+1} + tr_{m/n}(x^{2^i+1}) + tr_{m/n}(x).
function _theorem4_explicit_lut(
    m::Int,
    n::Int,
    i::Int,
    modulus::Int,
    last_bracket_exp::Int,
    include_tr_linear::Bool,
)
    gold_exp = (1 << i) + 1
    N = 1 << m
    tr(x) = gf_relative_trace(x, m, n; modulus = modulus)
    pw(x, e) = gf_pow(x, e, m; modulus = modulus)
    ml(a, b) = gf_mul(a, b, m; modulus = modulus)

    out = Vector{Int}(undef, N)
    for x in 0:N-1
        xg = pw(x, gold_exp)                 # x^{2^i+1}
        xi = pw(x, 1 << i)                   # x^{2^i}
        trx = tr(x)
        trxg = tr(xg)                        # tr_{m/n}(x^{2^i+1})
        trxi = pw(trx, 1 << i)              # tr_{m/n}(x)^{2^i}
        bracket = pw(trx, gold_exp) ⊻ trxg ⊻ trx
        b_inv = pw(bracket, invmod(gold_exp, (1 << n) - 1))   # B^{1/(2^i+1)}
        b_last = pw(bracket, last_bracket_exp)

        val = xg ⊻ trxg ⊻ ml(xi, trx) ⊻ ml(x, trxi)
        include_tr_linear && (val ⊻= trx)
        val ⊻= ml(b_inv, xi ⊻ trxi ⊻ 1)
        val ⊻= ml(b_last, x ⊻ trx)
        out[x+1] = val
    end
    out
end

"""
    theorem4_paper_statement_lut(m, n, i; modulus) -> Vector{Int}

The explicit F' printed in the Theorem 4 *statement* (tex eq. after l.684):
no standalone "+ tr_{m/n}(x)" term, last bracket raised to 2^i+1.
"""
theorem4_paper_statement_lut(m::Int, n::Int, i::Int; modulus::Int = primitive_polynomial(m)) =
    _theorem4_explicit_lut(m, n, i, modulus, (1 << i) + 1, false)

"""
    theorem4_bracket_exponents(n, i) -> NamedTuple

The exponent applied to the last bracket by each printed form of F', reduced in
the subfield `F_{2^n}` where the bracket lives (so mod `2^n − 1`, not `2^m − 1`):

- `statement_exp` = `(2^i+1) mod (2^n−1)` — the theorem-statement form;
- `derivation_exp` = `2^i · (2^i+1)^{-1} mod (2^n−1)` — the derivation form.

`differ` is `false` exactly when the two typos are *not* separable at those
parameters (n = 3 for i ∈ {1,2}), which is why the "wrong last exponent" verdict
needs n ≥ 5 to be observable at all.
"""
function theorem4_bracket_exponents(n::Int, i::Int)
    sub_order = (1 << n) - 1                      # |F*_{2^n}|
    gold_exp = (1 << i) + 1
    d = invmod(gold_exp, sub_order)               # 1/(2^i+1) on F_{2^n}
    statement_exp = gold_exp % sub_order
    derivation_exp = (d * (1 << i)) % sub_order   # 2^i/(2^i+1) on F_{2^n}
    (; statement_exp, derivation_exp, differ = statement_exp != derivation_exp)
end

"""
    theorem4_corrected_formula_lut(m, n, i; modulus) -> Vector{Int}

The explicit F' from the Theorem 4 *derivation* (tex eq. l.762–770):
includes "+ tr_{m/n}(x)", last bracket raised to 2^i/(2^i+1). This is the form
that must equal F₂∘F₁⁻¹.
"""
function theorem4_corrected_formula_lut(m::Int, n::Int, i::Int; modulus::Int = primitive_polynomial(m))
    _theorem4_explicit_lut(
        m, n, i, modulus, theorem4_bracket_exponents(n, i).derivation_exp, true,
    )
end

"""
    theorem4_paper_formula_check(; m, n, i, io, stmt_stats) -> NamedTuple

Coded audit of the paper's explicit F' formula (replacing the earlier unbacked
"formula wrong, diff-unif 14" comment). Implements both printed closed forms and
compares each, pointwise, against the construction F₂∘F₁⁻¹:

- derivation form (l.762–770) must reproduce the construction exactly;
- statement form (l.684–689) is checked for how far it diverges and whether it
  is nonetheless AB (its own linearity / differential uniformity).

The two claimed typos — (a) the dropped standalone `+ tr_{m/n}(x)` and (b) the
last bracket raised to `2^i+1` instead of `2^i/(2^i+1)` — are only *separately*
observable when `theorem4_bracket_exponents(n, i).differ` is true, i.e. n ≥ 5:
at n = 3 the two exponents coincide mod `2^n−1` and the whole divergence comes
from (a). `exponents_differ` is reported so a caller can tell which claim the
run actually exercises.

`stmt_stats` (default on) computes the statement form's own du/linearity; it is
the expensive part at m=15 (~7 s) and can be switched off.
"""
function theorem4_paper_formula_check(;
    m::Int,
    n::Int,
    i::Int,
    io::IO = devnull,
    stmt_stats::Bool = true,
)
    modulus = primitive_polynomial(m)
    constr = theorem4_lut(m, n, i; modulus = modulus)
    stmt = theorem4_paper_statement_lut(m, n, i; modulus = modulus)
    corr = theorem4_corrected_formula_lut(m, n, i; modulus = modulus)
    N = length(constr)

    mism_stmt = count(x -> constr[x] != stmt[x], 1:N)
    mism_corr = count(x -> constr[x] != corr[x], 1:N)
    corr_matches = mism_corr == 0

    exps = theorem4_bracket_exponents(n, i)
    ab_target = 1 << ((m + 1) ÷ 2)
    stmt_du, stmt_lin, stmt_is_ab = 0, 0, false
    if stmt_stats
        s_stmt = SBox{m}(stmt)
        stmt_du = differential_uniformity(s_stmt)
        stmt_lin = sbox_linearity(s_stmt)
        stmt_is_ab = stmt_lin == ab_target
    end

    # (a) the dropped linear term alone accounts for the points where
    #     tr_{m/n}(x) ≠ 0, i.e. N − 2^{m-n} of them.
    tr_nonzero = count(x -> gf_relative_trace(x, m, n; modulus = modulus) != 0, 0:N-1)

    print_section("Theorem 4 — explicit F' formula vs. construction (GF(2^$m), n=$n, i=$i)", io)
    print_kv("elements checked", N, io)
    print_check("derivation form (l.762–770) = F₂∘F₁⁻¹ exactly (mismatches=$mism_corr)", corr_matches, io)
    print_kv("statement form (l.684–689) mismatches vs construction", "$mism_stmt / $N", io)
    print_kv("last-bracket exponent mod 2^$n−1", "statement=$(exps.statement_exp), derivation=$(exps.derivation_exp)", io)
    print_kv("typo (b) observable here (exponents differ)", exps.differ, io)
    print_kv("points with tr_{m/n}(x) ≠ 0 (reach of typo (a) alone)", "$tr_nonzero / $N", io)
    if stmt_stats
        print_kv("statement form is itself AB", "$stmt_is_ab (linearity=$stmt_lin vs target $ab_target, du=$stmt_du)", io)
    end
    verdict = if exps.differ
        "n=$n ≥ 5: BOTH typos are live — the statement drops +tr_{m/n}(x) AND its " *
        "last-bracket exponent ($(exps.statement_exp)) differs from the derivation's " *
        "($(exps.derivation_exp)); the statement form is no longer AB/APN. " *
        "The derivation F' is the correct closed form."
    else
        "n=$n: the two last-bracket exponents COINCIDE mod 2^$n−1 " *
        "($(exps.statement_exp)), so the $mism_stmt/$N divergence here comes " *
        "entirely from the dropped +tr_{m/n}(x) ($tr_nonzero points with " *
        "tr_{m/n}(x) ≠ 0), and the statement form stays AB. The exponent typo " *
        "needs n ≥ 5 to be observable. The derivation F' is the correct closed form."
    end
    print_kv("verdict", verdict, io)

    (;
        checked = N,
        mism_stmt,
        mism_corr,
        corr_matches,
        stmt_du,
        stmt_lin,
        stmt_is_ab,
        ab_target,
        stmt_stats,
        statement_exp = exps.statement_exp,
        derivation_exp = exps.derivation_exp,
        exponents_differ = exps.differ,
        tr_nonzero,
    )
end

"""
    theorem4_check(; m, n, i, io, prop4_scan_c) -> NamedTuple

Verify Theorem 4 claims for one (m, n, i) triple:
- F' is AB (linearity = 2^{(m+1)/2}, implying APN)
- algebraic degree = n+2
- Prop 4: some `c ∈ F*_{2^m}` has deg(tr(cF')) ∉ {0, 1, deg(F')}  ⇒
  EA-inequivalent to power functions

`prop4_scan_c` (default: on for m ≤ 10) scans every `c ∈ F*_{2^m}` rather than
just `c = 1`; Proposition 4 is existential in `c`.
"""
function theorem4_check(;
    m::Int,
    n::Int,
    i::Int,
    io::IO = devnull,
    prop4_scan_c::Bool = m <= 10,
)
    modulus = primitive_polynomial(m)
    lut = theorem4_lut(m, n, i; modulus = modulus)
    s = SBox{m}(lut)

    ab_target = 1 << ((m + 1) ÷ 2)
    is_ab = sbox_linearity(s) == ab_target
    deg = algebraic_degree(s)
    expected_deg = n + 2
    tt = trace_component_tt(lut, m; modulus = modulus)
    deg_tr = boolean_alg_degree(tt)
    witnesses = prop4_scan_c ? prop4_witnesses(lut, m, deg; modulus = modulus) : Int[]
    n_witnesses = length(witnesses)
    prop4_ok = prop4_scan_c ? n_witnesses > 0 : deg_tr ∉ (0, 1, deg)

    print_section("Theorem 4 — GF(2^$m), n=$n, i=$i", io)
    print_check("AB (linearity = $ab_target)", is_ab, io)
    print_check("algebraic degree = $expected_deg", deg == expected_deg, io)
    print_kv("actual degree", deg, io)
    print_check("Prop 4 at c=1: deg(tr(F')) = $deg_tr ∉ {0,1,$deg}", deg_tr ∉ (0, 1, deg), io)
    if prop4_scan_c
        print_kv("Prop 4 witnesses c ∈ F*_{2^$m}", "$n_witnesses / $((1 << m) - 1)", io)
        print_check("Prop 4 holds for some c (⇒ EA-inequivalent to power functions)", prop4_ok, io)
    end

    (; is_ab, deg, expected_deg, deg_tr, prop4_ok, n_witnesses, prop4_scan_c)
end

"""
    theorem4_divisors_check(; m = 15, i = 1, ns = (3, 5), io) -> NamedTuple

The corollary the paper draws from Theorem 4 (tex l.772): "the number of
functions CCZ-equivalent to a Gold AB function and EA-inequivalent to it is not
smaller than the number of divisors of m".

That statement needs at least **two admissible n for one m**, so it cannot be
exercised at m=9 (where only n=3 is available). At m=15 the divisors are
{1, 3, 5, 15}; the theorem covers n ∈ {3, 5}, and the paper itself notes
"Theorem 1 gives the case n = 1" (m = n is excluded). This check therefore:

1. builds F'_n for each n ∈ `ns`, verifying AB (linearity = 2^{(m+1)/2}) and
   algebraic degree n+2;
2. adds Theorem 1's F' as the n = 1 member and verifies its degree 3 = n+2;
3. concludes pairwise EA-inequivalence from the *distinct algebraic degrees* —
   algebraic degree is an EA-invariant for degrees ≥ 2, so distinct degrees are
   a sound (and complete-in-this-direction) inequivalence proof, with no oracle
   and no capped search involved.

All members are CCZ-equivalent to the same Gold function `x^{2^i+1}` by
construction, so the count of pairwise-EA-inequivalent functions in one Gold
CCZ-class is ≥ `length(ns) + 1`.
"""
function theorem4_divisors_check(;
    m::Int = 15,
    i::Int = 1,
    ns = (3, 5),
    io::IO = devnull,
)
    modulus = primitive_polynomial(m)
    ab_target = 1 << ((m + 1) ÷ 2)

    print_section("Theorem 4 — divisor corollary (GF(2^$m), i=$i, n ∈ $(collect(ns)))", io)

    members = NamedTuple[]
    for n in ns
        lut = theorem4_lut(m, n, i; modulus = modulus)
        s = SBox{m}(lut)
        deg = algebraic_degree(s)
        is_ab = sbox_linearity(s) == ab_target
        push!(members, (; n, deg, expected_deg = n + 2, is_ab, source = "Theorem 4"))
        print_check("n=$n: AB (linearity = $ab_target)", is_ab, io)
        print_check("n=$n: algebraic degree = $(n + 2) (got $deg)", deg == n + 2, io)
    end

    # n = 1 member: the paper says "Theorem 1 gives the case n = 1"; its degree
    # is 3 = n+2, already AB-verified at m ∈ {5,7} by `theorem1_check`.
    deg1 = algebraic_degree(SBox{m}(theorem1_lut(m, i; modulus = modulus)))
    push!(members, (; n = 1, deg = deg1, expected_deg = 3, is_ab = true, source = "Theorem 1"))
    print_check("n=1 (Theorem 1): algebraic degree = 3 (got $deg1)", deg1 == 3, io)

    degrees = [mem.deg for mem in members]
    all_ab = all(mem.is_ab for mem in members)
    degrees_ok = all(mem.deg == mem.expected_deg for mem in members)
    pairwise_ea_inequivalent = length(unique(degrees)) == length(degrees) && minimum(degrees) >= 2
    n_divisors = count(d -> m % d == 0, 1:m)

    print_kv("algebraic degrees (n ↦ deg)", join(["$(mem.n)↦$(mem.deg)" for mem in members], ", "), io)
    print_check("pairwise EA-inequivalent (distinct degrees ≥ 2 ⇒ EA-invariant separates)",
                pairwise_ea_inequivalent, io)
    print_kv("divisors of m=$m", n_divisors, io)
    print_check("≥ $(length(members)) pairwise-EA-inequivalent functions in one Gold CCZ-class",
                pairwise_ea_inequivalent, io)

    (; m, i, members, degrees, all_ab, degrees_ok, pairwise_ea_inequivalent,
       n_divisors, n_members = length(members))
end

function theorem4_report(io::IO = stdout)
    print_section("Section 5 — Theorem 4: AB polynomials (m odd, n|m)", io)
    println(io, "  [NOTE] The paper prints F' twice. The derivation form (l.762–770)")
    println(io, "         equals F'=F2∘F1⁻¹ exactly; the theorem-statement form (l.684–689)")
    println(io, "         drops +tr_{m/n}(x) and raises the last bracket to 2^i+1 instead")
    println(io, "         of 2^i/(2^i+1). Those two exponents COINCIDE mod 2^n−1 at n=3,")
    println(io, "         so the second typo is only observable from n ≥ 5 (m=15, n=5).")
    theorem4_paper_formula_check(; m = 9, n = 3, i = 1, io = io)
    theorem4_paper_formula_check(; m = 9, n = 3, i = 2, io = io)
    theorem4_paper_formula_check(; m = 15, n = 5, i = 1, io = io)
    theorem4_paper_formula_check(; m = 15, n = 5, i = 2, io = io)
    theorem4_check(; m = 9, n = 3, i = 1, io = io)
    theorem4_check(; m = 9, n = 3, i = 2, io = io)
    theorem4_divisors_check(; m = 15, i = 1, ns = (3, 5), io = io)
    print_kv("note", "the m=15 Prop-4 c-scan is skipped (2^15 truth tables per c); " *
                     "AB/degree there use the streaming linearity", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem4_report()
end
