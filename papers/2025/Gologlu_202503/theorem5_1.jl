# Implements Theorem 5.1 (and Corollary 5.2) — inequivalences WITHIN biprojective families.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: 5 — Inequivalences within biprojective families
#
#   Theorem 5.1 (m > 2, m ≠ 6).
#   (a) F₁: F_q ≅ F_{q'} iff q' ∈ {q, q̄};  φ(m)/2 CCZ-classes.
#   (b) F₂: same.
#   (c) F₄: (i)   F_{q,B,a} is linear equivalent to F_{q̄,B,B^{Q+1}/a};
#           (ii)  for each B', B, a' there is an a with F_{q,B,a} ≅ F_{q,B',a'};
#           (iii) F_{q,B,a} ≅ F_{q,B,a'} for at most m choices of a';
#           (iv)  ≥ φ(m)(2^{m/2} − 2)/(2m) CCZ-inequivalent functions.
#   (d) Carlet (m odd): C(q;·) ≅ C(q';·) iff q' ∈ {q, q̄}, no matter the other
#       coefficients;  φ(m)/2 CCZ-classes.
#
#   Corollary 5.2.  φ(m)(2^{m/2}−2)/(2m) ≤ N(m) ≤ φ(m)(2^{m/2}−2)/2.
#
# Pseudocode:
#   1. EQUIVALENCES are established CONSTRUCTIVELY — the paper's own explicit
#      maps are evaluated pointwise on all 2ⁿ inputs with `el_identity_holds`.
#      (Equal invariants would NOT prove equivalence.)
#   2. INEQUIVALENCES are established by distinct ortho-derivative mugshots.
#      Every function here is quadratic APN, so Theorem 4.2 (Yoshiara) makes
#      CCZ = EA and a mugshot difference a sound inequivalence proof.
#   3. Class counts follow from (1) ∪ (2) and are compared with φ(m)/2.
#   4. F₄ classes at m = 6 are counted by orbit under the Theorem 4.8 restricted
#      shape (upper bound on #CCZ classes) and by distinct mugshots of the class
#      representatives (lower bound). When they meet, the count is exact.
#
# CAVEAT: F₄ needs m ≡ 2 (mod 4), so its smallest instance is m = 6 — exactly the
# dimension Theorem 5.1 and Corollary 5.2 exclude (no primitive prime divisor of
# 2⁶−1 exists). The m = 6 numbers below are therefore reported as OUTSIDE the
# theorem's stated range; they are consistent with the bounds, not a test of them.
#
# VBF API used: apn_ea_mugshot, algebraic_degree, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem4_8.jl"))
include(joinpath(@__DIR__, "lemmaB_2.jl"))

using VBF

"""
    f4_restricted_orbit(F, k) -> Set{NTuple{2,Int}}

All `(B', a')` such that `F` is linear equivalent to `F₄(k, B', a')` via the
matched-exponent shape of Theorem 4.8. Derived by pushing `F` through every
`(t, M)` and reading off the resulting coefficients; the target shape
`((1,0,0,B')_q, (0,1,a'/B',0)_r)` pins `B'` and `a'` uniquely.
"""
function f4_restricted_orbit(F::BiPair, k::Integer)
    fld = F.fld
    m = fld.m
    N = order(fld)
    out = Set{NTuple{2,Int}}()
    for t = 0:(m-1)
        ft = biproj_twist(fld, F.f, m - t)
        gt = biproj_twist(fld, F.g, m - t)
        for c1 = 0:(N-1), c2 = 0:(N-1), c3 = 0:(N-1), c4 = 0:(N-1)
            cs = (c1, c2, c3, c4)
            idx = findfirst(!=(0), cs)
            idx === nothing && continue
            cs[idx] == 1 || continue
            (gmul(fld, c1, c4) ⊻ gmul(fld, c2, c3)) == 0 && continue
            A, Bc, Cc, D = biproj_compose(fld, ft, c1, c2, c3, c4).c
            (Bc == 0 && Cc == 0 && A != 0 && D != 0) || continue
            A2, B2, C2, D2 = biproj_compose(fld, gt, c1, c2, c3, c4).c
            (A2 == 0 && D2 == 0 && B2 != 0 && C2 != 0) || continue
            Bp = gdiv(fld, D, A)                       # f ∘ M ∝ (1,0,0,B')
            ap = gmul(fld, Bp, gdiv(fld, C2, B2))      # g ∘ M ∝ (0,1,a'/B',0)
            f4_valid(fld, k, Bp, ap) && push!(out, (Bp, ap))
        end
    end
    out
end

"""
    family_classes(Fs) -> (classes, mugshots)

Partition a vector of quadratic-APN biprojective pairs by ortho-derivative
mugshot. Distinct mugshot ⇒ CCZ-inequivalent (Theorem 4.2), so the number of
distinct mugshots is a LOWER bound on the number of CCZ classes.
"""
function family_classes(Fs::Vector{BiPair})
    mugs = [mugshot_of(F) for F in Fs]
    uniq = unique(mugs)
    classes = [[Fs[i] for i in eachindex(Fs) if mugs[i] == u] for u in uniq]
    (classes, mugs)
end

"""
    theorem5_1_ab(io; m) -> NamedTuple

(a) and (b): F₁ and F₂ have `φ(m)/2` CCZ classes, with `F_q ≅ F_{q̄}`.
"""
function theorem5_1_ab(io::IO = stdout; m::Int = 5)
    fld = BiField(m)
    φ = count(k -> gcd(k, m) == 1, 1:m)
    out = NamedTuple[]
    # PAPER BUG (proof of Theorem 5.1(a),(b)). With M₂ = M₃ = x^{q̄}, L₁ = x, the
    # paper prints L₄ = x^{q̄} for F₁ and L₄ = x^{q} for F₂. Neither identity holds.
    # Matching the monomial degrees of  f₂(y^{q̄}, x^{q̄})  against  L₄(g₂(x,y)):
    #   F₁ (g₂ has exponent q²):  y^{q+q̄} + x^{q̄}y^{q} + x^{q+q̄} = [g₂']^{q}   ⇒ L₄ = x^{q}
    #   F₂ (g₂ has exponent q³):  x^{q̄}y^{q²} + x^{q²}y^{q̄}     = [g₂']^{q²}  ⇒ L₄ = x^{q²}
    # Both corrected maps are verified pointwise below; the theorem's CONCLUSION
    # (F_q ≅ F_{q̄}) is unaffected — only the printed witness is wrong.
    for (tag, valid, ctor, l4_paper, l4_fixed) in (
        (:F1, f1_valid, family_f1, k -> m - k, k -> k),       # printed x^{q̄}  → x^{q}
        (:F2, f2_valid, family_f2, k -> k, k -> 2k),          # printed x^{q}  → x^{q²}
    )
        ks = [k for k = 1:(m-1) if valid(fld, k)]
        isempty(ks) && continue
        Fs = BiPair[ctor(fld, k) for k in ks]

        paper_ok = true
        fixed_ok = true
        for k in ks
            kbar = m - k
            kbar in ks || continue
            F = ctor(fld, k)
            G = ctor(fld, kbar)
            M = BlockMap(zero_mono(), MonoMap(1, kbar), MonoMap(1, kbar), zero_mono())
            Lp = BlockMap(MonoMap(1, 0), zero_mono(), zero_mono(), MonoMap(1, l4_paper(k)))
            Lf = BlockMap(MonoMap(1, 0), zero_mono(), zero_mono(), MonoMap(1, l4_fixed(k)))
            el_identity_holds(F, M, Lp, G) || (paper_ok = false)
            el_identity_holds(F, M, Lf, G) || (fixed_ok = false)
        end

        classes, _ = family_classes(Fs)
        nclasses = length(classes)
        expected = φ ÷ 2
        print_kv(
            "$(tag) on M=F_2^$m: k ∈ $(ks)",
            "$(nclasses) CCZ classes (mugshot lower bound), φ(m)/2 = $expected",
            io,
        )
        print_check(
            "  $(tag): CORRECTED map F_q ∘ M = L ∘ F_{q̄} holds pointwise " *
            "(L₄ = x^{2^$(l4_fixed(first(ks)))} at k=$(first(ks)))",
            fixed_ok,
            io,
        )
        print_check(
            "  $(tag): PAPER BUG CONFIRMED — the L₄ printed in the Theorem 5.1 proof " *
            "does NOT satisfy the identity",
            !paper_ok,
            io,
        )
        print_check("  $(tag): class count = φ(m)/2 = $expected", nclasses == expected, io)
        push!(
            out,
            (;
                tag,
                m,
                ks,
                classes = nclasses,
                expected,
                constructive = fixed_ok,
                paper_map_holds = paper_ok,
            ),
        )
    end
    out
end

"""
    theorem5_1_c(io; m = 6) -> NamedTuple

(c) and Corollary 5.2 for F₄, at the smallest realisable dimension `m = 6`.
"""
function theorem5_1_c(io::IO = stdout; m::Int = 6)
    fld = BiField(m)
    Q = Qof(fld)
    k = 1
    kbar = m - k

    # ── (c)(i): F_{q,B,a} ∘ M = L ∘ F_{q̄, B, B^{Q+1}/a} ────────────────────
    #
    # PAPER BUG (proof of Theorem 5.1(c)). The paper sets M₁ = M₄ = x^{q̄}, L₁ = x,
    # L₄ = (B^Q/a)·x^Q — the target a' = B^{Q+1}/a, the M, the L₁ and the DEGREE of
    # L₄ are all correct, but its COEFFICIENT is not. Matching coefficients in
    #   g(x^{q̄}, y^{q̄}) = x^Q y^{q̄} + (a/B) x^{q̄} y^Q
    #   L₄(g'(x,y))     = c·x^{q̄} y^Q + c·(a'/B)^Q x^Q y^{q̄}      (using Q² ≡ 1)
    # gives c = a/B (and then (a'/B)^Q = B/a, i.e. a' = B^{Q+1}/a^Q = B^{Q+1}/a
    # since a ∈ K^×). So the correct map is L₄ = (a/B)·x^Q, not (B^Q/a)·x^Q.
    ci_ok = true
    ci_paper_ok = true
    ci_tested = 0
    for (kk, B, a) in f4_parameters(fld)
        kk == k || continue
        aprime = gdiv(fld, gmul(fld, frob(fld, B, m ÷ 2), B), a)     # a' = B^{Q+1}/a
        f4_valid(fld, kbar, B, aprime) || (ci_ok = false; continue)
        F = family_f4(fld, k, B, a)
        G = family_f4(fld, kbar, B, aprime)
        M = BlockMap(MonoMap(1, kbar), zero_mono(), zero_mono(), MonoMap(1, kbar))
        Lfix = BlockMap(
            MonoMap(1, 0),
            zero_mono(),
            zero_mono(),
            MonoMap(gdiv(fld, a, B), m ÷ 2),                          # (a/B)·x^Q  ← corrected
        )
        Lpaper = BlockMap(
            MonoMap(1, 0),
            zero_mono(),
            zero_mono(),
            MonoMap(gdiv(fld, frob(fld, B, m ÷ 2), a), m ÷ 2),        # (B^Q/a)·x^Q ← as printed
        )
        el_identity_holds(F, M, Lfix, G) || (ci_ok = false)
        el_identity_holds(F, M, Lpaper, G) || (ci_paper_ok = false)
        ci_tested += 1
        ci_tested ≥ 8 && break
    end
    print_check(
        "(c)(i) CORRECTED map (L₄ = (a/B)·x^Q): F_{q,B,a} ∘ M = L ∘ F_{q̄,B,B^{Q+1}/a}, " *
        "verified pointwise ($ci_tested instances)",
        ci_ok && ci_tested > 0,
        io,
    )
    print_check(
        "(c)(i) PAPER BUG CONFIRMED — the printed L₄ = (B^Q/a)·x^Q does NOT satisfy " *
        "the identity",
        !ci_paper_ok,
        io,
    )

    # ── (c)(ii)/(iii)/(iv): equivalence classes among F₄(k=1, ·, ·) ─────────
    insts = [(B, a) for (kk, B, a) in f4_parameters(fld) if kk == k]
    unseen = Set(insts)
    classes = Vector{Vector{NTuple{2,Int}}}()
    while !isempty(unseen)
        (B, a) = first(unseen)
        orb = f4_restricted_orbit(family_f4(fld, k, B, a), k)
        push!(orb, (B, a))
        push!(classes, [p for p in insts if p in orb])
        setdiff!(unseen, orb)
    end
    reps = [family_f4(fld, k, cls[1]...) for cls in classes]
    n_mug = length(unique(mugshot_of(F) for F in reps))

    # (c)(ii): B is not an invariant — every B' occurs in the class of a fixed F
    Bs_in_class = Set(p[1] for p in classes[1])
    all_B = Set(p[1] for p in insts)
    cii = Bs_in_class == all_B

    # (c)(iii): at most m choices of a' for a fixed B
    max_aprime = maximum(
        count(p -> p[1] == B, cls) for cls in classes for B in Set(p[1] for p in cls)
    )

    lower = ((count(j -> gcd(j, m) == 1, 1:m)) * (Q - 2)) ÷ (2m)
    upper = ((count(j -> gcd(j, m) == 1, 1:m)) * (Q - 2)) ÷ 2

    print_kv("F₄ at m=$m: admissible (B,a) for k=$k", length(insts), io)
    print_kv(
        "classes under the Thm 4.8 restricted shape (upper bound on #CCZ)",
        length(classes),
        io,
    )
    print_kv("distinct mugshots of class reps (lower bound on #CCZ)", n_mug, io)
    print_check(
        "bounds meet ⇒ exact CCZ-class count for F₄ at m=$m is $(length(classes))",
        length(classes) == n_mug,
        io,
    )
    print_check(
        "(c)(ii) every B' occurs in the class of a fixed F_{q,B,a} (B is not an invariant)",
        cii,
        io,
    )
    print_check(
        "(c)(iii) at most m = $m choices of a' per B (observed max $max_aprime)",
        max_aprime ≤ m,
        io,
    )
    print_kv("Corollary 5.2 bounds at m=$m", "$lower ≤ N($m) ≤ $upper", io)
    print_check(
        "(c)(iv)/Cor 5.2: the observed count $(length(classes)) lies in [$lower, $upper]",
        lower ≤ length(classes) ≤ upper,
        io,
    )
    println(
        io,
        "  [OUT OF RANGE] Theorem 5.1 and Corollary 5.2 require m ≠ 6, but F₄ needs",
    )
    println(
        io,
        "                 m ≡ 2 (mod 4), so m = 6 is the smallest realisable case and no",
    )
    println(
        io,
        "                 in-range instance is computationally reachable (m = 10 ⇒ n = 20).",
    )
    println(
        io,
        "                 The numbers above are CONSISTENT with the bounds, not a test of them.",
    )
    print_kv("completeness", "exhaustive over all $(length(insts)) admissible (B,a) at k=$k", io)

    (;
        m,
        k,
        instances = length(insts),
        classes = length(classes),
        mugshot_classes = n_mug,
        exact = length(classes) == n_mug,
        ci_ok,
        ci_paper_ok,
        cii,
        max_aprime,
        bounds = (lower, upper),
        in_bounds = lower ≤ length(classes) ≤ upper,
    )
end

"""
    theorem5_1_d(io; m = 5) -> NamedTuple

(d) Carlet, `m` odd: all Carlet functions with the same `q` are EL-equivalent
(constructively, via the transitive `G`-action of Lemma B.2), and different
`q`-classes are CCZ-inequivalent ⇒ `φ(m)/2` classes.
"""
function theorem5_1_d(io::IO = stdout; m::Int = 5)
    isodd(m) || error("theorem5_1_d: (d) is stated for odd m")
    fld = BiField(m)
    N = order(fld)
    φ = count(k -> gcd(k, m) == 1, 1:m)

    # all Carlet functions with a fixed q are EL-equivalent: Lemma B.2 says the
    # G-orbit of (1,β,γ,δ)_q is the whole root-free set, so a single orbit BFS
    # exhibits the M for every pair.
    k = 1
    rootfree_p1_1 = [
        (p2, p3, p4) for p2 = 0:(N-1), p3 = 0:(N-1), p4 = 0:(N-1) if
        projective_rootfree(fld, BiProj(k, (1, p2, p3, p4)))
    ]
    base = BiProj(k, (1, first(rootfree_p1_1)...))
    orb = g_orbit(fld, base)
    covers = all((1, p...) in orb for p in rootfree_p1_1)

    # same-q Carlet functions have equal mugshots (necessary), and the G-action
    # gives the explicit M — the constructive half.
    sample = [
        carlet(fld, k, p[1], p[2], p[3]) for p in rootfree_p1_1[1:min(6, length(rootfree_p1_1))]
    ]
    same_mug = length(unique(mugshot_of(C) for C in sample)) == 1

    # different q: k and k̄ agree, others differ
    Cs = BiPair[]
    for kk = 1:(m-1)
        gcd(kk, m) == 1 || continue
        d = findfirst(x -> carlet_valid(fld, kk, 0, 1, x), 0:(N-1))
        d === nothing || push!(Cs, carlet(fld, kk, 0, 1, d - 1))
    end
    classes, _ = family_classes(Cs)
    expected = φ ÷ 2

    print_kv("Carlet on M=F_2^$m (m odd): coefficient triples with p₁=1, root-free", length(rootfree_p1_1), io)
    print_check(
        "Lemma B.2's G-orbit covers every same-q Carlet coefficient tuple " *
        "(⇒ all same-q Carlet functions are EL-equivalent, constructively)",
        covers,
        io,
    )
    print_check("same-q Carlet functions share a mugshot (necessary condition)", same_mug, io)
    print_kv("Carlet CCZ classes over k", "$(length(classes)), φ(m)/2 = $expected", io)
    print_check("(d)(ii) Carlet class count = φ(m)/2 = $expected", length(classes) == expected, io)
    print_kv("completeness", "exhaustive over the root-free tuples with p₁ = 1 at k=$k", io)

    (;
        m,
        rootfree = length(rootfree_p1_1),
        orbit_covers = covers,
        same_mugshot = same_mug,
        classes = length(classes),
        expected,
        all_ok = covers && same_mug && length(classes) == expected,
    )
end

"""
    theorem5_1_report(io = stdout; m_ab = 5, m_c = 6, m_d = 5) -> NamedTuple
"""
function theorem5_1_report(io::IO = stdout; m_ab::Int = 5, m_c::Int = 6, m_d::Int = 5)
    print_section("Theorem 5.1 / Corollary 5.2 — inequivalences within families", io)
    ab = theorem5_1_ab(io; m = m_ab)
    println(io)
    c = theorem5_1_c(io; m = m_c)
    println(io)
    d = theorem5_1_d(io; m = m_d)
    # `all_ok` demands the CORRECTED maps hold and the PRINTED ones do not —
    # the printed-map failures are the paper bug, not a reproduction failure.
    ok =
        all(r -> r.constructive && !r.paper_map_holds && r.classes == r.expected, ab) &&
        c.ci_ok &&
        !c.ci_paper_ok &&
        c.exact &&
        c.cii &&
        c.max_aprime ≤ m_c &&
        c.in_bounds &&
        d.all_ok
    (; ab = ab, c = c, d = d, all_ok = ok)
end
