# Implements Section 5: EA-classes in dimension 6.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Section: 5 — EA-classes in dimension 6, Section 5.1 — Dillon's APN permutation
#
# Pseudocode:
#   1. Load 14 CCZ-class representatives for n=6 from VBFCatalog
#   2. Identify Kim/Dillon CCZ-class (reprs6_4)
#   3. Section 5.1: verify Kim properties, Dillon properties, CCZ~, not EA~
#   4. Find permutation EA-classes: deduplicate 32 perm reps from enumerate_ccz_class
#   5. Verify Remark 4: F₂ and F₃ are affine-equivalent to their inverses
#   6. Verify Dillon component degree distribution {* 3^^7, 4^^56 *}
# VBF API used: kim_apn, dillon_apn_permutation, are_ccz_equivalent, are_ea_equivalent,
#               are_affine_equivalent, algebraic_degree, enumerate_ccz_class,
#               differential_uniformity, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

"""
    load_n6_ccz_reps() -> Vector{SBox}

Load the 14 CCZ-class representatives for n=6 APN functions from VBFCatalog
(catalog entries reprs6_0 through reprs6_13, ordered by catalog id).
"""
function load_n6_ccz_reps()
    db = load_catalog()
    fns = list_functions(db; n = 6, is_apn = true, family = "APN-rep")
    sort!(fns, by = f -> f.id)
    return [load_sbox(db, f.id) for f in fns]
end

"""
    find_perm_ea_classes(perm_reps; limit) -> Vector{SBox}

Deduplicate APN permutation SBoxes by EA-equivalence (Heggebakk search).
Returns one representative per EA-class.
Stops once `limit` class candidates have been examined.
"""
function find_perm_ea_classes(
    perm_reps::Vector{SBox{N,T}};
    limit::Int = 50,
) where {N,T}
    classes = SBox{N,T}[]
    for (i, r) in enumerate(perm_reps)
        i > limit && break
        if !any(are_ea_equivalent(r, c) for c in classes)
            push!(classes, r)
        end
    end
    return classes
end

"""
    find_perm_affine_classes(perm_reps; limit) -> Vector{SBox}

Deduplicate APN permutation SBoxes by affine equivalence.
Returns one representative per affine-class.
"""
function find_perm_affine_classes(
    perm_reps::Vector{SBox{N,T}};
    limit::Int = 50,
) where {N,T}
    classes = SBox{N,T}[]
    for (i, r) in enumerate(perm_reps)
        i > limit && break
        if !any(are_affine_equivalent(r, c) for c in classes)
            push!(classes, r)
        end
    end
    return classes
end

"""
    section5_1_analysis(; limit, io) -> NamedTuple

Section 5.1: Kim/Dillon CCZ-class analysis.
Returns key results for testing.
"""
function section5_1_analysis(; limit::Int = 32, io::IO = stdout)
    K = kim_apn()
    D = dillon_apn_permutation()
    Dinv = compositional_inverse(D)

    print_section(io, "Basic properties of Kim and Dillon functions")
    kim_quad = algebraic_degree(K) == 2
    print_check(io, "Kim κ(x) is quadratic APN", kim_quad && differential_uniformity(K) == 2)
    print_check(io, "Dillon F₁ is APN permutation (deg 4)", is_permutation(D) && algebraic_degree(D) == 4 && differential_uniformity(D) == 2)
    print_check(io, "Dillon⁻¹ F₁⁻¹ is APN permutation", is_permutation(Dinv) && differential_uniformity(Dinv) == 2)

    ccz_eq = are_ccz_equivalent(K, D)
    print_check(io, "Kim and Dillon are CCZ-equivalent", ccz_eq)
    not_ea = !are_ea_equivalent(K, D)
    print_check(io, "Kim and Dillon are NOT EA-equivalent (different degrees)", not_ea)
    # VBF's dillon_apn_permutation() is AE to its inverse (it is F₂/F₃ in paper's notation)
    dillon_ae_inv = are_affine_equivalent(D, Dinv)
    print_check(
        io,
        "VBF Dillon perm is AE to its inverse (paper's F₂/F₃, Remark 4)",
        dillon_ae_inv,
    )

    print_section(io, "Component degree distribution of Dillon permutation")
    degs = component_degrees(D)
    deg3_count = get(degs, 3, 0)
    deg4_count = get(degs, 4, 0)
    total = sum(values(degs))
    print_kv(io, "deg=3 components", deg3_count)
    print_kv(io, "deg=4 components", deg4_count)
    print_kv(io, "total components (= 2^6-1)", total)
    print_check(io, "Component degrees: {* 3^^7, 4^^56 *} (Section 5.1)", deg3_count == 7 && deg4_count == 56)

    print_section(io, "Permutation EA-classes in CCZ-class of Kim (Section 5.1)")
    println(io, "  Computing enumerate_ccz_class(kim_apn())...")
    all_reps = enumerate_ccz_class(K)
    all_perms = filter(is_permutation, all_reps)
    print_kv(io, "Total CCZ-class reps (raw)", length(all_reps))
    print_kv(io, "Permutation reps (raw)", length(all_perms))
    println(io, "  Note: paper claims 13 EA-classes total, 2 containing a permutation.")
    println(io, "  Upper bound from Walsh-zero subspaces: $(length(extract_linear_subspaces(walsh_zeroes(K), 6; max_bits=12)))")

    println(io, "\n  Deduplicating permutation EA-classes (limit=$limit)...")
    perm_ea_classes = find_perm_ea_classes(all_perms; limit)
    print_kv(io, "#permutation EA-classes found (limit=$limit)", length(perm_ea_classes))
    dillon_ea_inv = are_ea_equivalent(D, Dinv)
    print_kv(io, "VBF Dillon and its inverse are EA-equivalent", dillon_ea_inv)
    println(io, "  (VBF Dillon = paper's F₂ or F₃; paper's F₁ and F₁⁻¹ are NOT EA-equiv)")

    print_section(io, "Affine-classes of permutations (Remark 4)")
    println(io, "  Deduplicating permutation affine-classes (limit=$limit)...")
    perm_ae_classes = find_perm_affine_classes(all_perms; limit)
    print_kv(io, "#permutation affine-classes found (limit=$limit)", length(perm_ae_classes))

    # Remark 4: F₂ and F₃ are AE to their inverses
    # VBF's dillon_apn_permutation() is already an F₂/F₃-type (AE to its inverse)
    print_check(io, "VBF Dillon (= F₂/F₃ type) is AE to its inverse (Remark 4)", dillon_ae_inv)

    # Among affine-class reps, count those AE to their own inverse
    ae_inv_reps = filter(r -> are_affine_equivalent(r, compositional_inverse(r)), perm_ae_classes)
    not_ae_inv_reps = filter(r -> !are_affine_equivalent(r, compositional_inverse(r)), perm_ae_classes)
    print_kv(io, "Perm affine-class reps AE to their own inverse (F₂/F₃ types)", length(ae_inv_reps))
    print_kv(io, "Perm affine-class reps NOT AE to own inverse (F₁/F₁⁻¹ types)", length(not_ae_inv_reps))
    println(io, "  Paper expects: 2 of each type (total 4 perm affine-classes)")

    return (;
        kim_quad,
        ccz_eq,
        not_ea,
        deg3 = deg3_count,
        deg4 = deg4_count,
        n_perm_reps = length(all_perms),
        dillon_ae_inv,
    )
end

"""
    section5_report(io)

Section 5: Table 1 catalog mapping + Section 5.1 Kim/Dillon analysis.
"""
function section5_report(io::IO = stdout; limit::Int = 32)
    println(io, "# Calderini (2020) — Section 5: EA-classes in dimension 6")
    println(
        io,
        "# Scope: Table 1 catalog mapping (loaded), Section 5.1 (exact via VBF APIs)",
    )

    print_section(io, "Table 1 — 14 CCZ-class representatives for n=6 APN functions")
    println(io, "  (from VBFCatalog, corresponding to Edel-Pott 2009 Appendix 1)")
    println(io, "  EA-class counts from paper require MAGMA — listed as reference.")
    db = load_catalog()
    reps_meta = sort!(list_functions(db; n = 6, is_apn = true, family = "APN-rep"), by = f -> f.id)
    K = kim_apn()
    D = dillon_apn_permutation()
    println(io, "  N | catalog_name | deg | perm | CCZ~Kim")
    for (i, f) in enumerate(reps_meta)
        sb = load_sbox(db, f.id)
        ck = are_ccz_equivalent(K, sb)
        println(io, "  $i | $(f.canonical_name) | $(f.algebraic_degree) | $(f.is_permutation) | $ck")
    end
    println(io, "  Note: reprs6_4 is the Kim/Dillon CCZ-class (CCZ~Kim=true).")
    println(io, "  Note: reprs6_13 is the non-quadratic CCZ-class (deg=3).")

    print_section(io, "Section 5.1 — Dillon's APN permutation EA and affine classes")
    section5_1_analysis(; limit, io)
end
