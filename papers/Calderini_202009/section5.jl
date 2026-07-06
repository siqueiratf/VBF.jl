# Implements Section 5: EA-classes in dimension 6.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Section: 5 — EA-classes in dimension 6, Section 5.1 — Dillon's APN permutation
#
# Pseudocode:
#   1. Table 1: build all 14 CCZ-class representatives from the paper's
#      polynomials (Conway ζ). For the 13 quadratic rows, count the EA-classes
#      in each CCZ-class exactly as automorphism orbits of Walsh-zero subspaces
#      (helpers.jl `ea_class_orbits`), and compare count + per-class degree
#      multiset against the paper's columns. Row 14 (non-quadratic): Corollary-1
#      upper bound (= 25 = the paper's exact count; exactness needs MAGMA).
#   2. Section 5.1: exact counts for the Kim/Dillon class — 13 EA-classes,
#      2 containing a permutation; explicit F₁, F₂, F₃ (helpers.jl) give the
#      4 affine classes of permutations {F₁, F₁⁻¹, F₂, F₃} (pairwise non-AE by
#      the complete AE decision).
#   3. Remark 4: F₂, F₃ AE to their inverses; F₁ NOT AE to its inverse.
#      VBF's dillon_apn_permutation() is AE to F₂ (not F₁/F₃).
#   4. Component degrees {*3^^7, 4^^56*} and the per-component Walsh-spectrum
#      multiset (5 types, multiplicities 21,21,7,7,7) for the APN permutations.
# VBF API used: kim_apn, dillon_apn_permutation, are_ccz_equivalent,
#               are_affine_equivalent, algebraic_degree, enumerate_ccz_class,
#               differential_uniformity, is_permutation, ortho_derivative, lat, ddt

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

# Table 1 rows: (label, ζ-power terms, paper #EA-classes, paper degree multiset
# as degree => count). Row 14 is non-quadratic and built separately.
const TABLE1_QUADRATIC = [
    ("1: x³", Tuple{Int,Int}[(0, 3)], 3, Dict(2 => 1, 3 => 1, 4 => 1)),
    ("2: x³+ζ¹¹x⁶+ζx⁹", Tuple{Int,Int}[(0, 3), (11, 6), (1, 9)], 3, Dict(2 => 1, 3 => 1, 4 => 1)),
    ("3: ζx⁵+x⁹+ζ⁴x¹⁷+ζx¹⁸+ζ⁴x²⁰+ζx²⁴+ζ⁴x³⁴+ζx⁴⁰",
        Tuple{Int,Int}[(1, 5), (0, 9), (4, 17), (1, 18), (4, 20), (1, 24), (4, 34), (1, 40)],
        19, Dict(2 => 1, 3 => 15, 4 => 3)),
    ("4: ζ⁷x³+x⁵+ζ³x⁹+ζ⁴x¹⁰+x¹⁷+ζ⁶x¹⁸",
        Tuple{Int,Int}[(7, 3), (0, 5), (3, 9), (4, 10), (0, 17), (6, 18)],
        13, Dict(2 => 1, 3 => 9, 4 => 3)),
    ("5: x³+ζx²⁴+x¹⁰ (Kim)", Tuple{Int,Int}[(0, 3), (1, 24), (0, 10)],
        13, Dict(2 => 1, 3 => 5, 4 => 7)),
    ("6: x³+ζ¹⁷(x¹⁷+x¹⁸+x²⁰+x²⁴)",
        Tuple{Int,Int}[(0, 3), (17, 17), (17, 18), (17, 20), (17, 24)],
        91, Dict(2 => 1, 3 => 66, 4 => 24)),
    ("7: x³+ζ¹¹x⁵+ζ¹³x⁹+x¹⁷+ζ¹¹x³³+x⁴⁸",
        Tuple{Int,Int}[(0, 3), (11, 5), (13, 9), (0, 17), (11, 33), (0, 48)],
        19, Dict(2 => 1, 3 => 15, 4 => 3)),
    ("8: ζ²⁵x⁵+x⁹+ζ³⁸x¹²+ζ²⁵x¹⁸+ζ²⁵x³⁶",
        Tuple{Int,Int}[(25, 5), (0, 9), (38, 12), (25, 18), (25, 36)],
        85, Dict(2 => 1, 3 => 66, 4 => 18)),
    ("9: ζ⁴⁰x⁵+ζ¹⁰x⁶+ζ⁶²x²⁰+ζ³⁵x³³+ζ¹⁵x³⁴+ζ²⁹x⁴⁸",
        Tuple{Int,Int}[(40, 5), (10, 6), (62, 20), (35, 33), (15, 34), (29, 48)],
        91, Dict(2 => 1, 3 => 63, 4 => 27)),
    ("10: ζ³⁴x⁶+ζ⁵²x⁹+ζ⁴⁸x¹²+ζ⁶x²⁰+ζ⁹x³³+ζ²³x³⁴+ζ²⁵x⁴⁰",
        Tuple{Int,Int}[(34, 6), (52, 9), (48, 12), (6, 20), (9, 33), (23, 34), (25, 40)],
        91, Dict(2 => 1, 3 => 66, 4 => 24)),
    ("11: x⁹+ζ⁴(x¹⁰+x¹⁸)+ζ⁹(x¹²+x²⁰+x⁴⁰)",
        Tuple{Int,Int}[(0, 9), (4, 10), (4, 18), (9, 12), (9, 20), (9, 40)],
        86, Dict(2 => 1, 3 => 69, 4 => 16)),
    ("12: ζ⁵²x³+ζ⁴⁷x⁵+ζx⁶+ζ⁹x⁹+ζ⁴⁴x¹²+ζ⁴⁷x³³+ζ¹⁰x³⁴+ζ³³x⁴⁰",
        Tuple{Int,Int}[(52, 3), (47, 5), (1, 6), (9, 9), (44, 12), (47, 33), (10, 34), (33, 40)],
        92, Dict(2 => 1, 3 => 69, 4 => 22)),
    ("13: ζ(x⁶+x¹⁰+x²⁴+x³³)+x⁹+ζ⁴x¹⁷",
        Tuple{Int,Int}[(1, 6), (1, 10), (1, 24), (1, 33), (0, 9), (4, 17)],
        85, Dict(2 => 1, 3 => 66, 4 => 18)),
]

"""
    table1_row14() -> SBox{6}

Table 1 row 14 (the Edel-Pott non-quadratic CCZ-class):
x³+ζ¹⁷(x¹⁷+x¹⁸+x²⁰+x²⁴) + ζ¹⁴(Tr(ζ⁵²x³+ζ⁶x⁵+ζ¹⁹x⁷+ζ²⁸x¹¹+ζ²x¹³)
+ (ζ²x)⁹+(ζ²x)¹⁸+(ζ²x)³⁶ + x²¹+x⁴²).
"""
function table1_row14()
    mod6 = conway_polynomial(6)
    z(k) = gf_pow(2, k, 6; modulus = mod6)
    mul(a, b) = gf_mul(a, b, 6; modulus = mod6)
    p(x, e) = gf_pow(x, e, 6; modulus = mod6)
    f = function (x)
        acc = p(x, 3) ⊻ mul(z(17), p(x, 17) ⊻ p(x, 18) ⊻ p(x, 20) ⊻ p(x, 24))
        tr = gf_trace(
            mul(z(52), p(x, 3)) ⊻ mul(z(6), p(x, 5)) ⊻ mul(z(19), p(x, 7)) ⊻
            mul(z(28), p(x, 11)) ⊻ mul(z(2), p(x, 13)),
            6;
            modulus = mod6,
        )
        zx = mul(z(2), x)
        acc ⊻ mul(z(14), tr ⊻ p(zx, 9) ⊻ p(zx, 18) ⊻ p(zx, 36) ⊻ p(x, 21) ⊻ p(x, 42))
    end
    return SBox{6}([f(x) for x = 0:63])
end

"""
    load_n6_ccz_reps() -> Vector{SBox}

Load the 14 CCZ-class representatives for n=6 APN functions from VBFCatalog.
"""
function load_n6_ccz_reps()
    db = load_catalog()
    fns = list_functions(db; n = 6, is_apn = true, family = "APN-rep")
    sort!(fns, by = f -> f.id)
    return [load_sbox(db, f.id) for f in fns]
end

"""
    table1_check(io) -> Bool

Reproduce Table 1: per quadratic row, exact EA-class count and per-class
degree multiset via `ea_class_orbits`; row 14 upper bound. Also checks that
the 13 quadratic rows are pairwise CCZ-inequivalent (distinct ortho-derivative
Walsh/DDT spectra — an EA/CCZ invariant for quadratic APN).
"""
function table1_check(io::IO = stdout)
    ok = true
    println(io, "  row | spaces | #auts | EA-classes (paper) | degrees match")
    reps_for_dedup = SBox{6,UInt8}[]
    for (label, terms, expected, exp_degs) in TABLE1_QUADRATIC
        F = sbox_from_zeta_terms(6, terms)
        quad_apn = algebraic_degree(F) == 2 && differential_uniformity(F) == 2
        if !quad_apn
            print_check(io, "$label is quadratic APN", false)
            ok = false
            continue
        end
        push!(reps_for_dedup, F)
        r = ea_class_orbits(F)
        classes = enumerate_ccz_class(F)
        degs = Dict{Int,Int}()
        for orb in r.orbits
            d = minimum(algebraic_degree(classes[i]) for i in orb)
            degs[d] = get(degs, d, 0) + 1
        end
        count_ok = length(r.orbits) == expected
        degs_ok = degs == exp_degs
        println(
            io,
            "  $label | $(r.nspaces) | $(r.nauts) | $(length(r.orbits)) ($expected) | $degs_ok",
        )
        ok &= count_ok && degs_ok
    end
    print_check(io, "All 13 quadratic rows: EA-class counts and degrees match Table 1", ok)

    # Pairwise CCZ-inequivalence of the quadratic rows via OD spectra.
    sigs = [
        (sorted_pairs(m.fields.walsh), sorted_pairs(m.fields.ddt)) for
        m in (apn_ea_mugshot(F) for F in reps_for_dedup)
    ]
    distinct = length(unique(sigs)) == length(sigs)
    print_check(io, "13 quadratic rows pairwise CCZ-inequivalent (distinct OD spectra)", distinct)
    ok &= distinct

    F14 = table1_row14()
    apn14 = differential_uniformity(F14) == 2 && algebraic_degree(F14) == 3
    print_check(io, "Row 14: APN of degree 3", apn14)
    ok &= apn14
    if apn14
        Z = walsh_zeroes(F14)
        ub = length(extract_linear_subspaces(Z, 6; max_bits = 12))
        print_check(io, "Row 14: Corollary-1 upper bound = 25 (= paper's exact count)", ub == 25)
        println(io, "  Row 14 exact EA-class count (paper: 25) needs code equivalence (MAGMA):")
        println(io, "  the orbit method requires a quadratic member, and row 14's class has none.")
        ok &= ub == 25
    end
    return ok
end

# Paper's Section 5.1 component Walsh-spectrum multiset (5 types; the tex shows
# "16^^44" for the last type, an OCR artifact of 16^^4 — spectra sum to 64).
const DILLON_COMPONENT_SPECTRA = [
    [-8 => 24, 0 => 12, 8 => 24, 16 => 4] => 7,
    [-16 => 6, 0 => 48, 16 => 10] => 7,
    [-16 => 3, -8 => 18, 0 => 12, 8 => 30, 16 => 1] => 7,
    [-16 => 1, -8 => 22, 0 => 12, 8 => 26, 16 => 3] => 21,
    [-16 => 2, -8 => 20, 0 => 12, 8 => 28, 16 => 2] => 21,
]

"""
    section5_1_analysis(; io) -> NamedTuple

Section 5.1, exact: 13 EA-classes / 2 with a permutation (automorphism
orbits), 4 affine classes of permutations {F₁, F₁⁻¹, F₂, F₃}, Remark 4,
component degrees and Walsh spectra.
"""
function section5_1_analysis(; io::IO = stdout)
    K = kim_apn()
    D = dillon_apn_permutation()
    Dinv = compositional_inverse(D)
    F1 = calderini_f1()
    F2 = calderini_f2()
    F3 = calderini_f3()
    F1inv = compositional_inverse(F1)

    print_section(io, "Basic properties of Kim and Dillon functions")
    kim_quad = algebraic_degree(K) == 2 && differential_uniformity(K) == 2
    print_check(io, "Kim κ(x) is quadratic APN", kim_quad)
    print_check(
        io,
        "Dillon is APN permutation of degree 4",
        is_permutation(D) && algebraic_degree(D) == 4 && differential_uniformity(D) == 2,
    )
    ccz_eq = are_ccz_equivalent(K, D)
    print_check(io, "Kim and Dillon are CCZ-equivalent", ccz_eq)
    not_ea = algebraic_degree(K) != algebraic_degree(D)
    print_check(io, "Kim ≁EA Dillon (degrees 2 ≠ 4; degree is an EA-invariant)", not_ea)

    print_section(io, "Explicit representatives F₁, F₂, F₃ (paper polynomials, Conway ζ)")
    f_apn = all(
        is_permutation(F) && differential_uniformity(F) == 2 && algebraic_degree(F) == 4
        for F in (F1, F2, F3)
    )
    print_check(io, "F₁, F₂, F₃ are APN permutations of degree 4", f_apn)
    f1_ccz = are_ccz_equivalent(K, F1)
    print_check(io, "F₁ is CCZ-equivalent to Kim", f1_ccz)
    d_ae_f2 = are_affine_equivalent(D, F2)
    print_check(io, "VBF dillon_apn_permutation() is affine-equivalent to F₂", d_ae_f2)
    print_check(io, "  (so F₂ ∈ CCZ-class of Kim through D)", d_ae_f2 && ccz_eq)
    f3_ccz = are_ccz_equivalent(K, F3)
    print_check(io, "F₃ is CCZ-equivalent to Kim", f3_ccz)

    print_section(io, "Remark 4 — inverses")
    r4a = !are_affine_equivalent(F1, F1inv)
    r4b = are_affine_equivalent(F2, compositional_inverse(F2))
    r4c = are_affine_equivalent(F3, compositional_inverse(F3))
    print_check(io, "F₁ NOT affine-equivalent to F₁⁻¹", r4a)
    print_check(io, "F₂ affine-equivalent to F₂⁻¹ (Remark 4)", r4b)
    print_check(io, "F₃ affine-equivalent to F₃⁻¹ (Remark 4)", r4c)
    print_check(io, "Dillon AE to Dillon⁻¹ (D is an F₂-type representative)",
        are_affine_equivalent(D, Dinv))

    print_section(io, "13 EA-classes, 2 containing a permutation (automorphism orbits)")
    r = ea_class_orbits(K)
    reps = enumerate_ccz_class(K)
    print_kv(io, "#Walsh-zero 6-dim subspaces (Corollary-1 bound)", r.nspaces)
    print_kv(io, "#graph automorphisms (lifted from OD self-equivalences)", r.nauts)
    n_classes = length(r.orbits)
    print_check(io, "Exactly 13 EA-classes in the CCZ-class", n_classes == 13)
    n_perm_orbits = count(o -> any(is_permutation(reps[i]) for i in o), r.orbits)
    print_check(io, "Exactly 2 EA-classes contain a permutation", n_perm_orbits == 2)
    degs = sort([minimum(algebraic_degree(reps[i]) for i in o) for o in r.orbits])
    print_check(io, "Per-class degrees {*2, 3^^5, 4^^7*} (Table 1 row 5)",
        degs == [2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4])

    print_section(io, "4 affine classes of permutations: F₁, F₁⁻¹, F₂, F₃")
    perms = [("F₁", F1), ("F₁⁻¹", F1inv), ("F₂", F2), ("F₃", F3)]
    pairwise = true
    for i = 1:4, j = (i + 1):4
        pairwise &= !are_affine_equivalent(perms[i][2], perms[j][2])
    end
    print_check(io, "F₁, F₁⁻¹, F₂, F₃ pairwise NOT affine-equivalent (≥4 classes)", pairwise)
    println(io, "  Since only 2 EA-classes contain a permutation, F₂ and F₃ lie in the")
    println(io, "  EA-classes of F₁ / F₁⁻¹ (each is a permutation in the CCZ-class).")
    println(io, "  Exhaustiveness of the 4 (no 5th affine class) is the paper's MAGMA")
    println(io, "  code-equivalence computation; all permutation space-representatives")
    println(io, "  found by enumerate_ccz_class fall into the classes of F₁ / F₁⁻¹:")
    perm_reps = [reps[i] for i in eachindex(reps) if is_permutation(reps[i])]
    in4 = all(
        are_affine_equivalent(p, F1) || are_affine_equivalent(p, F1inv) ||
        are_affine_equivalent(p, F2) || are_affine_equivalent(p, F3) for p in perm_reps
    )
    print_check(io, "All $(length(perm_reps)) permutation reps ∈ {F₁,F₁⁻¹,F₂,F₃} classes", in4)

    print_section(io, "Component degrees and Walsh spectra of the APN permutations")
    cd_ok = all(
        sorted_pairs(component_degree_spectrum(F)) == [3 => 7, 4 => 56] for
        F in (F1, F1inv, F2, F3, D)
    )
    print_check(io, "Component degrees {*3^^7, 4^^56*} for F₁, F₁⁻¹, F₂, F₃, D", cd_ok)

    expected_spectra = Dict(
        sort(collect(s); by = first) => c for (s, c) in DILLON_COMPONENT_SPECTRA
    )
    sp_ok = all(Dict(component_walsh_spectra(F)) == expected_spectra for (_, F) in perms)
    print_check(io, "Per-component Walsh-spectrum multiset matches the paper (5 types)", sp_ok)

    return (;
        kim_quad,
        ccz_eq,
        not_ea,
        n_classes,
        n_perm_orbits,
        degs,
        pairwise_non_ae = pairwise,
        remark4 = r4a && r4b && r4c,
        d_ae_f2,
        components_ok = cd_ok,
        spectra_ok = sp_ok,
    )
end

"""
    section5_report(io)

Section 5: Table 1 (exact EA-class counts for the 13 quadratic rows, upper
bound for row 14) + Section 5.1 Kim/Dillon analysis, all exact.
"""
function section5_report(io::IO = stdout)
    println(io, "# Calderini (2020) — Section 5: EA-classes in dimension 6")
    println(io, "# Scope: Table 1 EA-class counts (exact, rows 1-13; row 14 upper bound),")
    println(io, "#        Section 5.1 (exact: 13 classes / 2 with permutation / 4 affine)")

    print_section(io, "Table 1 — EA-classes per CCZ-class (paper polynomials, Conway ζ)")
    table1_check(io)

    print_section(io, "Catalog cross-reference (VBFCatalog n=6 APN-rep entries)")
    db = load_catalog()
    reps_meta = sort!(list_functions(db; n = 6, is_apn = true, family = "APN-rep"), by = f -> f.id)
    print_check(io, "Catalog lists 14 CCZ-class representatives", length(reps_meta) == 14)
    for f in reps_meta
        println(io, "  $(f.id) | $(f.canonical_name) | deg $(f.algebraic_degree) | perm $(f.is_permutation)")
    end

    print_section(io, "Section 5.1 — Dillon's APN permutation")
    section5_1_analysis(; io)
end