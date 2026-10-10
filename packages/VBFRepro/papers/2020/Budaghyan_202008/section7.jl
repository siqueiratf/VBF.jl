# Implements Section VII — Computational Results.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: VII-A (n=8 data), VII-B (n=9 new APN + Table I), VII-D (n=6 coverage)
#
# Pseudocode:
#   Section VII-B (n=9) — the paper's central claim:
#     1. Build G_{1,L} for [ζ^424,ζ,ζ^34] → the new APN (cf. section6.jl)
#     2. Build ALL 7 known classes of Table I (rows 1–7) from the paper's own
#        expressions (cf. table1.jl), not from whatever the catalog happens to hold
#     3. Compare mugshots: new ≠ each of rows 1–7, and ≠ every quadratic n=9
#        catalog entry
#     4. Distinct mugshot ⟹ EA-inequivalent; all compared functions are quadratic
#        APN and for those EA = CCZ (Yoshiara) ⟹ CCZ-inequivalent.  Non-quadratic
#        catalog entries are power maps, excluded by the same result — exactly the
#        argument the paper makes in Sec. VII-B.
#   Section VII-A (n=8):
#     5. Build x⁹ + Tr(x³) over GF(2^8) and verify it is APN.  NOTE: this only
#        re-verifies the 2006 function; the paper's claim (that it arises as an
#        isotopic shift G_{3,L}, k=4, m=2) is NOT reproduced — see README R8.
#   Section VII-D (n=6):
#     6. Replay exact EA witnesses for each of13namedquadraticTable5rows,
#        from both permutation and2-to-1 linear L (section7d.jl).
# VBF API used: apn_ea_mugshot, algebraic_degree, SBox, differential_uniformity,
#               gold_apn, terms_to_lut, gf_trace, load_apn_function (VBFCatalog)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section6.jl"))
include(joinpath(@__DIR__, "table1.jl"))
using Dates
using VBFCatalog

# ── Section VII-B: n=9 new APN ────────────────────────────────────────────────

"""
    section7_build_x9_tr_x3(; n=8) -> SBox{8}

Compute the APN function F(x) = x⁹ + Tr(x³) over GF(2^8)
(Browning–Dillon–McQuistan–Wolfe, known since 2006).
"""
function section7_build_x9_tr_x3(; n::Int = 8)
    mod = primitive_polynomial(n)
    SBox{n}([
        gf_pow(x, 9, n; modulus = mod) ⊻ gf_trace(gf_pow(x, 3, n; modulus = mod), n; modulus = mod)
        for x in 0:(1<<n)-1
    ])
end

"""
    section7_check_n9_inequivalence(; io) -> NamedTuple

The paper's central claim (Section VII-B): the new n=9 function of Theorem VI.3
is CCZ-inequivalent to **every** known APN over GF(2⁹).

Checked against all 7 known Table I rows *and* every quadratic n=9 catalog entry,
by `apn_ea_mugshot`:

  * distinct mugshot ⟹ EA-inequivalent (the mugshot is an EA-invariant);
  * all compared functions are quadratic APN, and for quadratic APN functions
    EA-equivalence coincides with CCZ-equivalence (Yoshiara) ⟹ CCZ-inequivalent.

Only mugshot *inequality* is used.  Equal mugshots would prove nothing, and
`are_ccz_equivalent` returning `false` is not used as evidence either — it is
best-effort and may return `false` when inconclusive.

The non-quadratic n=9 catalog entries (Kasami, Welch/Niho, Inverse) are power
maps: a quadratic APN CCZ-equivalent to a power function is EA-equivalent to a
Gold function (Yoshiara), and the Gold rows are already compared — the same
argument the paper gives.
"""
function section7_check_n9_inequivalence(; io::IO = devnull)
    # NOTE: no `@assert` here — a throw would abort before the NamedTuple is
    # returned, making the caller's @tests unable to observe the failure (the
    # bug this reproduction had in `print_check`; README R1).  Scope problems
    # surface as `nonvacuous = false` instead.
    entries = table1_entries()
    new_entry = entries[end]
    known = entries[1:end-1]                      # Table I rows 1–7
    mug_new = new_entry.mugshot

    known_distinct = count(e -> e.mugshot != mug_new, known)
    all_known_inequiv = known_distinct == length(known)

    # every quadratic n=9 catalog entry (Gold x3/x5/x17 + Budaghyan2009 eq7/eq8)
    cat_names = filter(nm -> startswith(nm, "n9_"), apn_catalog_names())
    cat_quadratic = String[]
    cat_power = String[]
    cat_distinct = 0
    for nm in cat_names
        F = load_apn_function(nm)
        if algebraic_degree(F) == 2
            push!(cat_quadratic, nm)
            apn_ea_mugshot(F) != mug_new && (cat_distinct += 1)
        else
            push!(cat_power, nm)
        end
    end
    all_cat_inequiv = cat_distinct == length(cat_quadratic)

    all_inequiv = all_known_inequiv && all_cat_inequiv
    # Non-vacuity: there must actually be something to compare against.
    nonvacuous = length(known) == 7 && length(cat_quadratic) ≥ 5

    print_section(io, "Section VII-B — n=9: CCZ-inequivalence of the new APN")
    print_kv(io, "Table I known classes compared (rows 1–7)", length(known))
    print_kv(io, "  mugshot-distinct from the new function", known_distinct)
    print_kv(io, "quadratic n=9 catalog entries compared", length(cat_quadratic))
    print_kv(io, "  mugshot-distinct from the new function", cat_distinct)
    print_kv(io, "non-quadratic n=9 catalog entries (power maps, excluded)",
        length(cat_power))
    print_check(io, "new function ≠ all 7 known Table I classes (mugshot)",
        all_known_inequiv)
    print_check(io, "new function ≠ all quadratic n=9 catalog entries (mugshot)",
        all_cat_inequiv)
    print_check(io, "comparison set is non-empty (7 known rows, ≥5 catalog quadratics)",
        nonvacuous)

    (; all_inequiv, all_known_inequiv, all_cat_inequiv, nonvacuous,
       known_checked = length(known), known_distinct,
       catalog_quadratic = cat_quadratic, catalog_power = cat_power, cat_distinct)
end

# ── Section VII-A: n=8 reference function ────────────────────────────────────

"""
    section7_check_n8_reference(; io) -> NamedTuple

Verify that x⁹ + Tr(x³) over GF(2^8) is APN.

SCOPE: this verifies the 2006 function only.  The paper's own n=8 claim — that
this map arises as an isotopic shift G_{3,L} with k=4, m=2 — is **not**
reproduced: the paper does not publish the L, so reproducing it means re-running
the search over 4-term F₄-polynomials rather than transcribing it (README R8).
"""
function section7_check_n8_reference(; io::IO = devnull)
    F = section7_build_x9_tr_x3()
    du = differential_uniformity(F)
    is_apn = (du == 2)

    print_section(io, "Section VII-A — n=8 reference: x⁹ + Tr(x³) over GF(2^8)")
    print_kv(io, "differential uniformity", du)
    print_check(io, "x⁹ + Tr(x³) is APN", is_apn)
    print_kv(io, "not reproduced",
        "the paper's claim that this map is an isotopic shift G_{3,L} (k=4, m=2); " *
        "the L is not published (README R8)")

    (; is_apn, du)
end

# ── n=6: EA-classes reachable from 1-term shifts of G_1 ──────────────────────

"""
    section7_check_n6_1term_shift_classes(; io) -> NamedTuple

Scan all 1-term isotopic shifts G_{1,L}(x), L(x) = u·x^{2^j}, over GF(2⁶) and
collect the distinct EA-classes obtained (by `apn_ea_mugshot`).

This tests **Lemma VI.6(i)** — the Gold class is reachable from a 1-term shift —
and finds exactly **1** EA-class, as Lemma VI.6 predicts (a 1-term L can only
give a function EA-equivalent to a Gold map; the paper needs a 2-term L to reach
the non-Gold quadratic APN classes over GF(2⁶)).

It is **not** a test of Section VII-D.  Section VII-D claims that *every*
quadratic APN over GF(2⁶) is EA-equivalent to an isotopic shift of x³, which
needs a search over general linear L (GL(6,2) ∪ 2-to-1 maps, ~2³⁶ maps) modulo
the Proposition VI.1 normalisation — the bounded discovery and exact finite coverage witnesses are now implemented in section7d.jl. Exhausting all linear maps is not required for the named existential claim.
"""
function section7_check_n6_1term_shift_classes(; io::IO = devnull)
    n  = 6
    mod = primitive_polynomial(n)
    G1  = gold_apn(n, 1; modulus = mod).lut

    apn_mugshots = Dict{Any, String}()
    for j in 0:n-1
        for log_u in 0:(1<<n)-2
            u = gf_pow(2, log_u, n; modulus = mod)
            L  = terms_to_lut([(u, 1 << j)], n, mod)
            GL = SBox{n}(isotopic_shift_lut(G1, L))
            differential_uniformity(GL) == 2 || continue
            mug = apn_ea_mugshot(GL)
            haskey(apn_mugshots, mug) || (apn_mugshots[mug] = "j=$j,log_u=$log_u")
        end
    end

    nclasses = length(apn_mugshots)
    G1_mug = apn_ea_mugshot(gold_apn(6, 1; modulus = mod))
    gold_reachable = haskey(apn_mugshots, G1_mug)
    only_gold = nclasses == 1

    print_section(io, "Section VI — n=6: EA-classes from 1-term shifts of G_1 (Lemma VI.6(i))")
    print_kv(io, "distinct EA-classes found (1-term L)",  nclasses)
    print_check(io, "Gold class reachable from a 1-term monomial shift (Lemma VI.6(i))",
        gold_reachable)
    print_check(io, "exactly 1 EA-class — 1-term L reaches nothing but Gold",
        only_gold)
    print_kv(io, "note",
        "NOT Section VII-D: that claim (every quadratic APN over GF(2⁶) is an " *
        "isotopic shift of x³) needs general linear L (~2³⁶) + Prop. VI.1 " *
        "normalisation; see section7d.jl for26exactEAcoveragewitnesses")

    (; nclasses, gold_reachable, only_gold)
end

include(joinpath(@__DIR__,"section7d.jl"))

function section7_report(io::IO = stdout)
    print_section(io, "Section VII: Computational Results")
    section7_check_n8_reference(; io)
    section7_check_n9_inequivalence(; io)
    section7_check_n6_1term_shift_classes(; io)
    section7d_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    section7_report()
end
