@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    K = kim_apn()
    D = dillon_apn_permutation()

    # Basic properties
    @test algebraic_degree(K) == 2
    @test differential_uniformity(K) == 2
    @test !is_permutation(K)
    @test is_permutation(D)
    @test algebraic_degree(D) == 4
    @test differential_uniformity(D) == 2

    # CCZ-equivalent but not EA-equivalent (degree is an EA-invariant)
    @test are_ccz_equivalent(K, D)
    @test algebraic_degree(K) != algebraic_degree(D)

    # Explicit representatives F₁, F₂, F₃ from the paper's polynomials
    F1 = calderini_f1()
    F2 = calderini_f2()
    F3 = calderini_f3()
    F1inv = compositional_inverse(F1)
    for F in (F1, F2, F3)
        @test is_permutation(F)
        @test differential_uniformity(F) == 2
        @test algebraic_degree(F) == 4
    end
    @test are_ccz_equivalent(K, F1)

    # Remark 4: F₂, F₃ AE to their inverses; F₁ is NOT
    @test !are_affine_equivalent(F1, F1inv)
    @test are_affine_equivalent(F2, compositional_inverse(F2))
    @test are_affine_equivalent(F3, compositional_inverse(F3))

    # VBF's Dillon permutation is an F₂-type representative (AE to F₂ — not F₁/F₃)
    @test are_affine_equivalent(D, F2)
    @test !are_affine_equivalent(D, F1)
    @test !are_affine_equivalent(D, F3)
    @test are_affine_equivalent(D, compositional_inverse(D))

    # 4 affine classes of permutations: pairwise NOT affine-equivalent
    perms = (F1, F1inv, F2, F3)
    for i = 1:4, j = (i + 1):4
        @test !are_affine_equivalent(perms[i], perms[j])
    end

    # Section 5.1 headline: 13 EA-classes, 2 containing a permutation
    r = ea_class_orbits(K)
    @test r.nspaces == 222                    # Corollary-1 bound for the class
    @test length(r.orbits) == 13
    reps = enumerate_ccz_class(K)
    @test length(reps) == 222
    @test count(o -> any(is_permutation(reps[i]) for i in o), r.orbits) == 2
    degs = sort([minimum(algebraic_degree(reps[i]) for i in o) for o in r.orbits])
    @test degs == [2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4]   # Table 1 row 5 degrees

    # Component degrees {*3^^7, 4^^56*} for all APN permutations checked
    # (core component_degree_spectrum — the EA-invariant promoted from here)
    for F in (D, F1, F2, F3)
        cd = Dict(sorted_pairs(component_degree_spectrum(F)))
        @test get(cd, 3, 0) == 7
        @test get(cd, 4, 0) == 56
        @test sum(values(cd)) == 63
    end

    # Per-component Walsh-spectrum multiset (5 types; 21,21,7,7,7)
    expected = Dict(
        sort(collect(s); by = first) => c for (s, c) in DILLON_COMPONENT_SPECTRA
    )
    @test Dict(component_walsh_spectra(D)) == expected
    @test Dict(component_walsh_spectra(F1)) == expected

    # Table 1 rows 1-4 as a fast subset (full table in section5_report):
    for k = 1:4
        (label, terms, exp_count, exp_degs) = TABLE1_QUADRATIC[k]
        F = sbox_from_zeta_terms(6, terms)
        @test algebraic_degree(F) == 2
        @test differential_uniformity(F) == 2
        rr = ea_class_orbits(F)
        @test length(rr.orbits) == exp_count
    end

    # Row 14: non-quadratic Edel-Pott function, Corollary-1 bound = 25
    F14 = table1_row14()
    @test differential_uniformity(F14) == 2
    @test algebraic_degree(F14) == 3
    @test length(extract_linear_subspaces(walsh_zeroes(F14), 6; max_bits = 12)) == 25

    # Catalog: 14 n=6 APN CCZ-reps exist and are APN
    creps = load_n6_ccz_reps()
    @test length(creps) == 14
    @test all(differential_uniformity(r) == 2 for r in creps)
end