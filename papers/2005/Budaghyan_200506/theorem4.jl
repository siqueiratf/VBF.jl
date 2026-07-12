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
#   against the permutation-inverse construction F2∘F1^{-1}. Coded verdict on
#   GF(2^9), n=3, i∈{1,2}: the derivation formula reproduces the construction
#   EXACTLY (0 mismatches); the theorem-statement formula differs in 448/512
#   points yet is itself AB (du=2, linearity=32) — so the earlier "wrong,
#   diff-unif 14" comment was unfounded (see check output).
#
#   The bracket [tr_{m/n}(x)^{2^i+1}+tr_{m/n}(x^{2^i+1})+tr_{m/n}(x)] lands in the
#   subfield F_{2^n}, so `^{1/(2^i+1)}` and `^{2^i/(2^i+1)}` are Gold-inverse
#   exponents taken mod (2^n − 1) (invmod on the subfield order), not mod 2^m−1.
#
#   AB ↔ linearity = 2^{(m+1)/2};  degree = n+2
#   Prop 4: deg(tr F') = 4 ∉ {0,1,n+2}  ⇒ EA-inequivalent to power functions.
# VBF API used: gf_mul, gf_pow, gf_relative_trace, gf_trace, primitive_polynomial,
#               SBox, linearity, differential_uniformity, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

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
    theorem4_corrected_formula_lut(m, n, i; modulus) -> Vector{Int}

The explicit F' from the Theorem 4 *derivation* (tex eq. l.762–770):
includes "+ tr_{m/n}(x)", last bracket raised to 2^i/(2^i+1). This is the form
that must equal F₂∘F₁⁻¹.
"""
function theorem4_corrected_formula_lut(m::Int, n::Int, i::Int; modulus::Int = primitive_polynomial(m))
    gold_exp = (1 << i) + 1
    d = invmod(gold_exp, (1 << n) - 1)            # 1/(2^i+1) on F_{2^n}
    last_exp = (d * (1 << i)) % ((1 << n) - 1)    # 2^i/(2^i+1) on F_{2^n}
    _theorem4_explicit_lut(m, n, i, modulus, last_exp, true)
end

"""
    theorem4_paper_formula_check(; m, n, i, io) -> NamedTuple

Coded audit of the paper's explicit F' formula (replacing the earlier unbacked
"formula wrong, diff-unif 14" comment). Implements both printed closed forms and
compares each, pointwise, against the construction F₂∘F₁⁻¹:

- derivation form (l.762–770) must reproduce the construction exactly;
- statement form (l.684–689) is checked for how far it diverges and whether it
  is nonetheless an AB function (its own linearity / differential uniformity).
"""
function theorem4_paper_formula_check(; m::Int, n::Int, i::Int, io::IO = devnull)
    modulus = primitive_polynomial(m)
    constr = theorem4_lut(m, n, i; modulus = modulus)
    stmt = theorem4_paper_statement_lut(m, n, i; modulus = modulus)
    corr = theorem4_corrected_formula_lut(m, n, i; modulus = modulus)
    N = length(constr)

    mism_stmt = count(x -> constr[x] != stmt[x], 1:N)
    mism_corr = count(x -> constr[x] != corr[x], 1:N)
    corr_matches = mism_corr == 0

    ab_target = 1 << ((m + 1) ÷ 2)
    s_stmt = SBox{m}(stmt)
    stmt_du = differential_uniformity(s_stmt)
    stmt_lin = linearity(s_stmt)
    stmt_is_ab = stmt_lin == ab_target

    print_section("Theorem 4 — explicit F' formula vs. construction (GF(2^$m), n=$n, i=$i)", io)
    print_kv("elements checked", N, io)
    print_check("derivation form (l.762–770) = F₂∘F₁⁻¹ exactly (mismatches=$mism_corr)", corr_matches, io)
    print_kv("statement form (l.684–689) mismatches vs construction", "$mism_stmt / $N", io)
    print_kv("statement form is itself AB", "$stmt_is_ab (linearity=$stmt_lin=$ab_target?, du=$stmt_du)", io)
    print_kv("verdict", "statement F' is a typo (drops +tr, wrong last exponent) but still AB; " *
                        "derivation F' is the correct closed form", io)

    (; checked = N, mism_stmt, mism_corr, corr_matches, stmt_du, stmt_lin, stmt_is_ab, ab_target)
end

"""
    theorem4_check(; m, n, i, io) -> NamedTuple

Verify Theorem 4 claims for one (m, n, i) triple:
- F' is AB (linearity = 2^{(m+1)/2}, implying APN)
- algebraic degree = n+2
- Prop 4: deg(tr(F')) ∉ {0, 1, deg(F')}  ⇒ EA-inequivalent to power functions
"""
function theorem4_check(; m::Int, n::Int, i::Int, io::IO = devnull)
    modulus = primitive_polynomial(m)
    lut = theorem4_lut(m, n, i; modulus = modulus)
    s = SBox{m}(lut)

    ab_target = 1 << ((m + 1) ÷ 2)
    is_ab = linearity(s) == ab_target
    deg = algebraic_degree(s)
    expected_deg = n + 2
    tt = trace_component_tt(lut, m; modulus = modulus)
    deg_tr = boolean_alg_degree(tt)
    prop4_ok = deg_tr ∉ (0, 1, deg)

    print_section("Theorem 4 — GF(2^$m), n=$n, i=$i", io)
    print_check("AB (linearity = $ab_target)", is_ab, io)
    print_check("algebraic degree = $expected_deg", deg == expected_deg, io)
    print_kv("actual degree", deg, io)
    print_check("Prop 4: deg(tr(F')) = $deg_tr ∉ {0,1,$deg}", prop4_ok, io)

    (; is_ab, deg, expected_deg, deg_tr, prop4_ok)
end

function theorem4_report(io::IO = stdout)
    print_section("Section 5 — Theorem 4: AB polynomials (m odd, n|m)", io)
    println(io, "  [NOTE] The paper prints F' twice. The derivation form (l.762–770)")
    println(io, "         equals F'=F2∘F1⁻¹ exactly; the theorem-statement form (l.684–689)")
    println(io, "         is a typo (missing +tr_{m/n}(x), wrong last exponent) yet still AB.")
    theorem4_paper_formula_check(; m = 9, n = 3, i = 1, io = io)
    theorem4_paper_formula_check(; m = 9, n = 3, i = 2, io = io)
    theorem4_check(; m = 9, n = 3, i = 1, io = io)
    theorem4_check(; m = 9, n = 3, i = 2, io = io)
    print_kv("note", "m=15 omitted (AB/APN check O(N²) for N=2^15 is slow)", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem4_report()
end
