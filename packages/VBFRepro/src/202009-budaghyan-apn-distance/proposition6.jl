# Implements Proposition 6 and Table I (Section IV.E)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.E — Examples and Computation Results
#
# Pseudocode (Proposition 6, eq. (9) — transcribed verbatim from the paper):
#   For Gold F(x)=x³ over F₂ⁿ, β, b ∈ F₂ⁿ:
#     if b = β³:                             |Π_F^β(b)| = 2ⁿ - 1     ← paper; see P1 below
#     elif n odd:                            |Π_F^β(b)| = 2^{n-1} - 1
#     elif n/2 odd and b+β³ is cube:         |Π_F^β(b)| = 2^{n-1} + 2^{n/2}   - 1
#     elif n/2 odd and b+β³ not cube:        |Π_F^β(b)| = 2^{n-1} - 2^{n/2-1} - 1
#     elif n/2 even and b+β³ is cube:        |Π_F^β(b)| = 2^{n-1} - 2^{n/2}   - 1
#     else (n/2 even, not cube):             |Π_F^β(b)| = 2^{n-1} + 2^{n/2-1} - 1
# VBF API used: SBox, pi_multiset, sorted_pairs, gf_pow, gf_is_dth_power, gold_apn,
#               compute_m_F, pi_counts, apply_modifications, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    pi_formula_gold(N, β, b; modulus) -> Int

Proposition 6: exact formula for |Π_F^β(b)| when F(x) = x³ over GF(2^N).

Paper issue P2 — eq. (9) has exactly **one** typo, in its first branch: for
`b = β³` the paper prints `2ⁿ − 1`, but the correct value is `2ⁿ` (every one of
the `2ⁿ` directions `a`, including `a = 0`, reaches `b = β³`). Brute-forced over
all `(β, b)` for n = 3,4,5,6,8: that branch mismatches in every single instance
(8/8, 16/16, 32/32, 64/64, 256/256), and every other branch matches perfectly
(0 mismatches out of 56, 240, 992, 4032, 65280).

The five remaining branches below are transcribed **as printed** in the paper and
all reproduce; earlier revisions of this file wrongly accused two of them of
being typos. Table I (m_F) is unaffected either way, since m_F is the minimum of
Π_F and the `b = β³` branch never attains it.
"""
function pi_formula_gold(
    N::Int,
    β::Integer,
    b::Integer;
    modulus::Integer = primitive_polynomial(N),
)
    n_half = 1 << (N - 1)  # 2^{N-1}
    β3 = gf_pow(Int(β), 3, N; modulus = Int(modulus))

    # b = β³: all 2^N directions a reach this value.
    # Paper issue P2: eq. (9) prints 2^N - 1 here. This is the paper's only typo.
    Int(b) == β3 && return 1 << N

    if N % 2 == 1  # N odd
        return n_half - 1
    end

    # N even
    diff = Int(b) ⊻ β3  # b + β³ in GF(2^N)
    cube = gf_is_dth_power(diff, 3, N; modulus = Int(modulus))
    half_n = N ÷ 2

    if half_n % 2 == 1  # N/2 odd — both branches as printed in eq. (9)
        return cube ? n_half + (1 << half_n) - 1 : n_half - (1 << (half_n - 1)) - 1
    else  # N/2 even — both branches as printed in eq. (9)
        return cube ? n_half - (1 << half_n) - 1 : n_half + (1 << (half_n - 1)) - 1
    end
end

"""
    pi_formula_gold_as_published(N, β, b; modulus) -> Int

Equation (9) exactly as printed, `2ⁿ − 1` in the `b = β³` branch included. Used
only to *demonstrate* paper issue P2: this disagrees with the true `|Π_F^β(b)|`
on the `b = β³` branch and nowhere else.
"""
function pi_formula_gold_as_published(
    N::Int,
    β::Integer,
    b::Integer;
    modulus::Integer = primitive_polynomial(N),
)
    β3 = gf_pow(Int(β), 3, N; modulus = Int(modulus))
    Int(b) == β3 && return (1 << N) - 1     # ← the published (wrong) value
    pi_formula_gold(N, β, b; modulus)
end

"""
    m_F_formula_gold(N) -> Int

The minimum m_F for Gold x^3 from Proposition 6.
"""
function m_F_formula_gold(N::Int)
    n_half = 1 << (N - 1)
    N % 2 == 1 && return n_half - 1
    half_n = N ÷ 2
    half_n % 2 == 1 && return n_half - (1 << (half_n - 1)) - 1
    return n_half - (1 << half_n) - 1
end

"""
    proposition6_table1(; io, n_range) -> NamedTuple

Verify Table I: m_F and lower bounds for Gold x^3, using Proposition 6 formula.
For n ≤ 7, also verify formula against pi_multiset numerically.
"""
function proposition6_table1(; io::IO = stdout, n_range = 3:10)
    # Table I expected values
    expected = Dict(
        1 => (0, 1),
        2 => (0, 1),
        3 => (3, 2),
        4 => (3, 2),
        5 => (15, 6),
        6 => (27, 10),
        7 => (63, 22),
        8 => (111, 38),
        9 => (255, 86),
        10 => (495, 166),
    )

    print_section("Proposition 6 + Table I — Gold x^3 m_F and distance bounds", io)
    println(io, "  n   m_F(formula)   lower bound   match Table I")
    all_ok = true
    for N in n_range
        mF = m_F_formula_gold(N)
        bd = lower_bound_distance(mF)
        exp = get(expected, N, nothing)
        ok = exp === nothing || (mF == exp[1] && bd == exp[2])
        all_ok &= ok
        marker = ok ? "✓" : "✗ (exp $(exp))"
        println(io, "  $N   $mF   $bd   $marker")
    end
    print_check("Table I: all m_F values match paper (Table I is correct)", all_ok, io)

    # Numeric verification over *every* (β, b) pair, for small n.
    print_section("Proposition 6 — eq. (9) vs |Π_F^β(b)| (exhaustive, n ≤ 7)", io)
    num_ok = true
    for N in 3:min(maximum(n_range), 7)
        mod = primitive_polynomial(N)
        F = gold_apn(N, 1)
        sz = 1 << N
        r = proposition6_check_formula(N; modulus = mod)
        ok = r.mismatches == 0
        num_ok &= ok
        print_check(
            "n=$N: corrected eq. (9) matches |Π_F^β(b)| on all $(sz * sz) (β,b) pairs",
            ok,
            io,
        )
        print_kv(
            "  P2 — as-published eq. (9) mismatches",
            "$(r.published_mismatches) / $(sz * sz) (all on the b=β³ branch: $(r.published_mismatches == sz))",
            io,
        )
    end

    (; all_ok = all_ok && num_ok, formula_ok = all_ok, numeric_ok = num_ok)
end

"""
    proposition6_check_formula(N; modulus) -> NamedTuple

Compare eq. (9) — both the corrected form and the as-published form — against
the directly computed `|Π_F^β(b)|` for **every** pair `(β, b) ∈ F₂ᴺ × F₂ᴺ`.
Returns the mismatch counts for each. P2 predicts `mismatches == 0` and
`published_mismatches == 2^N` (one per β, on the `b = β³` branch).
"""
function proposition6_check_formula(N::Int; modulus::Integer = primitive_polynomial(N))
    F = gold_apn(N, 1; modulus = Int(modulus))
    sz = 1 << N
    mismatches = 0
    published_mismatches = 0
    for β = 0:(sz-1)
        counts = pi_counts(F, β)     # counts[b+1] = |Π_F^β(b)|
        for b = 0:(sz-1)
            pi_formula_gold(N, β, b; modulus) == counts[b+1] || (mismatches += 1)
            pi_formula_gold_as_published(N, β, b; modulus) == counts[b+1] ||
                (published_mismatches += 1)
        end
    end
    (; N, mismatches, published_mismatches, pairs = sz * sz)
end

"""
    tightness_witnesses(; io) -> NamedTuple

Section IV-E: "for 1 ≤ n ≤ 4 the bound is tight as witnessed by ...". The paper
lists, for `F(x) = x³`:

  * n=1: u₁=0, v₁=1
  * n=2: u₁=0, v₁=α
  * n=3: u₁=0, u₂=1, v₁=1, v₂=α   ← **paper issue P1: never yields an APN G**
  * n=4: u₁=0, u₂=1, v₁=1, v₂=1

Each witness must give an APN `G` at Hamming distance exactly `⌈m_F/3⌉+1`. The
n=2 and n=4 witnesses check out. The n=3 witness does not: it gives `DU(G) = 4`
for α ∈ {2,4,6} and `DU(G) = 6` for α ∈ {3,5,7} — every primitive element of
GF(8), so no reading of "α primitive" rescues it. The bound *is* tight at n=3
(distance 2), but only for the **corrected** witnesses `v₁ = v₂ ∈ {α, α², α⁴}`
(with α = 2 the class of x, the root of the defining polynomial): exhaustively,
`(v₁,v₂) ∈ {(2,2),(4,4),(6,6)}` are the only shifts of `U = {0,1}` giving an
APN `G`.
"""
function tightness_witnesses(; io::IO = stdout)
    print_section("Section IV-E — tightness of the Corollary 2 bound for n ≤ 4", io)

    # n=2 and n=4: the paper's own witnesses.
    checks = Tuple{Int,Vector{Int},Vector{Int},String}[
        (2, [0], [2], "u₁=0, v₁=α  (α=2)"),
        (4, [0, 1], [1, 1], "u₁=0, u₂=1, v₁=v₂=1"),
    ]
    all_ok = true
    for (n, U, V, label) in checks
        F = gold_apn(n, 1)
        G = apply_modifications(F, U, V)
        apn = differential_uniformity(G) == 2
        d = hamming_distance(F, G)
        bound = lower_bound_distance(m_F_formula_gold(n))
        ok = apn && d == bound
        all_ok &= ok
        print_check("n=$n: $label → G APN, d(F,G)=$d = bound $bound", ok, io)
    end

    # n=3: the paper's witness (P1) — never APN, for any primitive α.
    F3 = gold_apn(3, 1)
    paper_du = Dict(α => differential_uniformity(apply_modifications(F3, [0, 1], [1, α]))
                    for α = 2:7)  # every α ≠ 0,1 in GF(8) is primitive
    paper_never_apn = all(du != 2 for du in values(paper_du))
    print_check(
        "n=3 (P1): paper witness v₁=1, v₂=α is NOT APN for any primitive α " *
        "(DU ∈ $(sort(unique(values(paper_du)))))",
        paper_never_apn,
        io,
    )

    # n=3: the corrected witnesses — v₁ = v₂ ∈ {α, α², α⁴}, α = 2.
    mod3 = primitive_polynomial(3)
    conj = sort([gf_pow(2, e, 3; modulus = mod3) for e in (1, 2, 4)])   # {2,4,6}
    apn_pairs = sort([(v1, v2) for v1 = 0:7 for v2 = 0:7
                      if !(v1 == 0 && v2 == 0) &&
                         differential_uniformity(apply_modifications(F3, [0, 1], [v1, v2])) == 2])
    corrected = sort([(v, v) for v in conj])
    corrected_ok = apn_pairs == corrected
    bound3 = lower_bound_distance(m_F_formula_gold(3))
    dist_ok = all(hamming_distance(F3, apply_modifications(F3, [0, 1], [v, v])) == bound3
                  for v in conj)
    print_check(
        "n=3 (P1 corrected): the only APN shifts of U={0,1} are v₁=v₂ ∈ {α,α²,α⁴} = $conj",
        corrected_ok,
        io,
    )
    print_check("n=3: those witnesses sit at d(F,G)=$bound3 = bound (bound is tight)", dist_ok, io)

    all_ok &= paper_never_apn && corrected_ok && dist_ok
    (; all_ok, paper_n3_du = paper_du, corrected_n3 = corrected)
end

function proposition6_report(; io::IO = stdout)
    print_header(io)
    r = proposition6_table1(; io)
    w = tightness_witnesses(; io)
    return (; all_ok = r.all_ok && w.all_ok, table1 = r, witnesses = w)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition6_report()
end
