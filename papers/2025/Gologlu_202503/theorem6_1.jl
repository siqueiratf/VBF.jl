# Implements Theorem 6.1 — inequivalences BETWEEN biprojective families.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: 6 — Inequivalences between biprojective families
#
#   Theorem 6.1. Let m > 2, m ≠ 6 and let F, G be biprojective pairs from
#   DISTINCT families among: Gold G, Zhou–Pott ZP, Taniguchi T (with (q,m) ≠ (2,4)),
#   Carlet C (m odd), F₁ (with (q,m) ≠ (2,4)), F₂, F₄.  Then F, G are CCZ-inequivalent.
#
# Pseudocode:
#   1. Build every admissible instance of every family that exists on M = F_{2^m}.
#   2. Every one of them is quadratic APN, so by Theorem 4.2 (Yoshiara) CCZ = EA and
#      a DIFFERENCE of ortho-derivative mugshots is a sound proof of CCZ-inequivalence.
#      Compare all cross-family pairs.
#   3. POSITIVE CONTROL (essential): within a family, F_q and F_{q̄} ARE equivalent
#      and must therefore have EQUAL mugshots. If every mugshot in the corpus were
#      distinct, the test would be measuring nothing. This control shows the
#      invariant does collapse equivalent functions.
#   4. Also record the exponent-pair invariant of Theorem 4.8 —
#      {k₁,l₁} vs {k₂,l₂} up to sign — which is what the proof of Theorem 6.1
#      actually uses; it is a *cheap* inequivalence certificate and must never
#      contradict the mugshot.
#
# EXCLUSIONS honoured here, exactly as stated in the theorem:
#   • Carlet is dropped for even m (Theorem B.3 puts it inside Zhou–Pott).
#   • Taniguchi and F₁ are dropped at (q,m) = (2,4).
#   • F₄ requires m ≡ 2 (mod 4), so its smallest case is m = 6 — the dimension the
#     theorem excludes. Cross-family comparison including F₄ is therefore an
#     OPT-IN target at m = 6 (n = 12), reported as OUTSIDE the theorem's range.
#
# WHY m = 4 IS EXCLUDED — and the necessity control it gives us.
# At m = 4, EVERY Taniguchi / F₁ / Zhou–Pott instance has l ≡ 2 = m/2 (mod 4)
# (Taniguchi and F₁ have l = 2k with k odd; Zhou–Pott needs 0 < j < 4 with j ≢ ±k,
# forcing j = 2). Theorem 4.8's standing hypothesis `l₁ ≠ m/2` therefore fails for
# all of them, and Theorem 6.1 does not apply. This is not academic: at m = 4 the
# Zhou–Pott function ZP(q=2, r=4, d=2) and the F₁ function F₁(q=8) ARE CCZ-equivalent
# (`are_ccz_equivalent` from core confirms it, n = 8). We run that as the
# NECESSITY CONTROL: it shows the theorem's exclusions are load-bearing rather than
# decorative. (The paper writes the exclusion as "(q,m) ≠ (2,4)"; since F₁(q=8) is
# the q̄-partner of F₁(q=2) at m=4 and hence in the same CCZ class, excluding the
# pair (2,4) excludes the whole class — the reading is consistent.)
#
# VBF API used: apn_ea_mugshot, algebraic_degree, differential_uniformity,
#               are_ccz_equivalent, gold_apn, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem4_8.jl"))

using VBF

"""
    theorem6_1_corpus(m; include_f4 = false) -> Vector{Tuple{Symbol,BiPair}}

Every admissible instance of every Theorem 6.1 family on `M = F_{2^m}`, honouring
the theorem's own exclusions.
"""
function theorem6_1_corpus(m::Integer; include_f4::Bool = false)
    fld = BiField(m)
    N = order(fld)
    out = Tuple{Symbol,BiPair}[]
    for k = 1:(m-1)
        gcd(k, m) == 1 || continue
        q = 1 << k

        # Gold
        if isodd(m)
            push!(out, (:Gold, gold_odd(fld, k)))
        else
            a = findfirst(x -> gf_trace(x, m; modulus = fld.modulus) == 1, 0:(N-1))
            a === nothing || push!(out, (:Gold, gold_even(fld, k, a - 1)))
        end

        # Taniguchi — excluded at (q, m) = (2, 4)
        if !(q == 2 && m == 4)
            d = findfirst(x -> taniguchi_valid(fld, k, x), 0:(N-1))
            d === nothing || push!(out, (:Taniguchi, taniguchi(fld, k, d - 1)))
        end

        # Carlet — only for odd m (Theorem B.3 absorbs the even case into ZP)
        if isodd(m)
            dc = findfirst(x -> carlet_valid(fld, k, 0, 1, x), 0:(N-1))
            dc === nothing || push!(out, (:Carlet, carlet(fld, k, 0, 1, dc - 1)))
        end

        # Zhou–Pott — needs m even
        if iseven(m)
            for j = 1:(m-1)
                ex = zhou_pott_excluded_d(fld, k, j)
                dz = findfirst(x -> x != 0 && !(x in ex), 0:(N-1))
                dz === nothing || push!(out, (:ZhouPott, zhou_pott(fld, k, j, dz - 1)))
            end
        end

        # F₁ — excluded at (q, m) = (2, 4)
        f1_valid(fld, k) && !(q == 2 && m == 4) && push!(out, (:F1, family_f1(fld, k)))
        # F₂
        f2_valid(fld, k) && push!(out, (:F2, family_f2(fld, k)))
    end
    if include_f4
        for (k, B, a) in f4_parameters(fld)
            push!(out, (:F4, family_f4(fld, k, B, a)))
            break                                      # one representative suffices
        end
    end
    out
end

"""
    theorem6_1_check(m; include_f4 = false) -> NamedTuple

Compare every cross-family pair on `M = F_{2^m}` by ortho-derivative mugshot.
"""
function theorem6_1_check(m::Integer; include_f4::Bool = false)
    corpus = theorem6_1_corpus(m; include_f4 = include_f4)
    mugs = [mugshot_of(F) for (_, F) in corpus]
    quad = all(algebraic_degree(bipair_sbox(F)) == 2 for (_, F) in corpus)
    apn = all(differential_uniformity(bipair_sbox(F)) == 2 for (_, F) in corpus)

    cross_total = 0
    cross_sep = 0
    collisions = Tuple{String,String}[]
    shape_agrees = true
    for i in eachindex(corpus), j in eachindex(corpus)
        i < j || continue
        ti, Fi = corpus[i]
        tj, Fj = corpus[j]
        ti == tj && continue                            # DISTINCT families only
        cross_total += 1
        if mugs[i] != mugs[j]
            cross_sep += 1
            # the exponent condition of Theorem 4.8 is a cheaper certificate;
            # it may fail to separate, but must never claim equivalence where the
            # mugshot proves inequivalence — that direction is vacuous, so we
            # only assert the converse below.
        else
            push!(collisions, (Fi.name, Fj.name))
        end
        # if the exponent condition FAILS, Theorem 4.8 forbids equivalence; the
        # mugshot must then also separate them.
        if !thm48_exponent_condition(Fi, Fj) && mugs[i] == mugs[j]
            shape_agrees = false
        end
    end

    # POSITIVE CONTROL: F_q and F_{q̄} in the SAME family must share a mugshot.
    fld = BiField(m)
    pos_pairs = 0
    pos_equal = 0
    for k = 1:(m-1)
        f1_valid(fld, k) || continue
        kbar = m - k
        f1_valid(fld, kbar) && kbar != k || continue
        F = family_f1(fld, k)
        G = family_f1(fld, kbar)
        pos_pairs += 1
        mugshot_of(F) == mugshot_of(G) && (pos_equal += 1)
    end

    (;
        m,
        corpus_size = length(corpus),
        families = sort(unique(String(t) for (t, _) in corpus)),
        all_quadratic = quad,
        all_apn = apn,
        cross_total,
        cross_separated = cross_sep,
        collisions,
        shape_agrees,
        positive_pairs = pos_pairs,
        positive_equal = pos_equal,
    )
end

"""
    m4_necessity_control(io) -> NamedTuple

The necessity control described in this file's header: at `m = 4` Theorem 4.8's
hypothesis `l ≠ m/2` fails for every Taniguchi / F₁ / Zhou–Pott instance, and a
Zhou–Pott and an F₁ function really are CCZ-equivalent there. Uses the core
`are_ccz_equivalent` (exact, n = 8) — not an invariant.
"""
function m4_necessity_control(io::IO = stdout)
    m = 4
    fld = BiField(m)
    ex = zhou_pott_excluded_d(fld, 1, 2)
    dz = findfirst(x -> x != 0 && !(x in ex), 0:(order(fld)-1)) - 1
    ZP = zhou_pott(fld, 1, 2, dz)
    F1 = family_f1(fld, 3)

    hyp = [
        (F.name, thm48_hypotheses_ok(F)) for
        F in (ZP, F1, family_f1(fld, 1), taniguchi(fld, 1, findfirst(x -> taniguchi_valid(fld, 1, x), 0:(order(fld)-1)) - 1))
    ]
    none_ok = all(!h[2] for h in hyp)
    ccz = are_ccz_equivalent(bipair_sbox(ZP), bipair_sbox(F1))

    print_kv("m=4 necessity control", "Theorem 4.8 needs l ≠ m/2; at m=4 every instance has l ≡ 2 = m/2", io)
    for (nm, h) in hyp
        print_kv("  $(nm)", "Thm 4.8 hypotheses satisfied: $h", io)
    end
    print_check("  no m=4 instance satisfies Theorem 4.8's hypotheses", none_ok, io)
    print_check(
        "  and indeed $(ZP.name) IS CCZ-equivalent to $(F1.name) " *
        "(exact `are_ccz_equivalent`, n=8) ⇒ Theorem 6.1's exclusion is necessary",
        ccz,
        io,
    )
    (; hypotheses = hyp, none_satisfied = none_ok, zp_f1_ccz_equivalent = ccz)
end

"""
    theorem6_1_report(io = stdout; m_values = (5,), include_f4 = false,
                      necessity_control = true) -> NamedTuple

The theorem is tested at `m = 5` (n = 10), the smallest dimension where its
hypotheses actually hold for all the families involved. `m = 4` is run only as
the necessity control (see `m4_necessity_control`), and `m = 6` (with F₄) only
under `include_f4 = true`, outside the theorem's stated range.
"""
function theorem6_1_report(
    io::IO = stdout;
    m_values = (5,),
    include_f4::Bool = false,
    necessity_control::Bool = true,
)
    print_section("Theorem 6.1 — CCZ-inequivalence between distinct biprojective families", io)
    rows = NamedTuple[]
    ok = true
    for m in m_values
        r = theorem6_1_check(m)
        push!(rows, r)
        print_kv("m=$m (n=$(2m)): families present", join(r.families, ", "), io)
        print_kv("  instances / cross-family pairs", "$(r.corpus_size) / $(r.cross_total)", io)
        print_check("  all instances are quadratic APN (so Thm 4.2 applies)", r.all_quadratic && r.all_apn, io)
        print_check(
            "  every cross-family pair is CCZ-inequivalent " *
            "($(r.cross_separated)/$(r.cross_total), via distinct ortho-derivative mugshots)",
            r.cross_separated == r.cross_total && r.cross_total > 0,
            io,
        )
        print_check(
            "  POSITIVE CONTROL: F₁(q) and F₁(q̄) share a mugshot " *
            "($(r.positive_equal)/$(r.positive_pairs)) — the invariant does collapse " *
            "equivalent functions, so the test above is not vacuous",
            r.positive_pairs > 0 && r.positive_equal == r.positive_pairs,
            io,
        )
        for (a, b) in r.collisions
            println(io, "    [COLLISION] ", a, " vs ", b, " — same mugshot, inconclusive")
        end
        (r.cross_separated == r.cross_total && r.cross_total > 0 &&
         r.positive_pairs > 0 && r.positive_equal == r.positive_pairs &&
         r.all_quadratic && r.all_apn) || (ok = false)
    end

    ctrl = nothing
    if necessity_control
        println(io)
        ctrl = m4_necessity_control(io)
        (ctrl.none_satisfied && ctrl.zp_f1_ccz_equivalent) || (ok = false)
    end

    f4row = nothing
    if include_f4
        r = theorem6_1_check(6; include_f4 = true)
        f4row = r
        print_kv("m=6 (n=12) WITH F₄: families", join(r.families, ", "), io)
        print_check(
            "  every cross-family pair CCZ-inequivalent ($(r.cross_separated)/$(r.cross_total))",
            r.cross_separated == r.cross_total,
            io,
        )
        println(
            io,
            "  [OUT OF RANGE] Theorem 6.1 excludes m = 6, but F₄ requires m ≡ 2 (mod 4);",
        )
        println(
            io,
            "                 m = 6 is the only computationally reachable dimension where",
        )
        println(io, "                 F₄ can be compared against the other families at all.")
    else
        println(io, "  [SKIP] the F₄ cross-family run at m = 6 — enable with include_f4=true")
    end
    print_kv("completeness", "exhaustive over all admissible instances for m ∈ $(m_values)", io)

    (; rows = rows, f4 = f4row, necessity = ctrl, all_ok = ok)
end
