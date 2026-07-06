@testset "section4_3 (Kim mapping CCZ-class)" begin
    include(joinpath(@__DIR__, "..", "section4_3.jl"))

    κ = kim_apn()

    # cheap structural checks
    Z = walsh_zeroes(κ)
    bases = extract_linear_subspaces(Z, 6; max_bits = 12)
    @test length(bases) == 222
    @test counts(thickness_spectrum(κ)) == [0 => 1, 1 => 63, 2 => 126, 3 => 32]
    @test count(b -> VBF.thickness(b, 6) == 3, bases) == 32
    @test is_ccz_equivalent_to_permutation(κ)

    # butterflies: APN involutions of degree 4, EA-inequivalent (Remark 41)
    mod3 = primitive_polynomial(3)
    α = first(a for a in 1:7 if gf_trace(a, 3; modulus = mod3) == 0)
    β = gf_pow(α, 3, 3; modulus = mod3) ⊻ gf_inv(α, 3; modulus = mod3)
    H1 = open_butterfly(α, 1)
    H2 = open_butterfly(α, β)
    for H in (H1, H2)
        @test is_permutation(H)
        @test all(H(H(v)) == v for v in 0:63)
        @test differential_uniformity(H) == 2
        @test algebraic_degree(H) == 4
    end
    @test !are_ea_equivalent(H1, H2)

    # full Section 4.3 reproduction (≈ 5–10 min: 222 thickness-spectrum
    # extractions + affine partition of 512 permutations). Set
    # CANTEAUT_202205_FAST=1 to skip; `make report` also covers it.
    if get(ENV, "CANTEAUT_202205_FAST", "0") != "1"
        r = section4_3_report(io = devnull)
        @test r.n_spaces == 222
        @test r.n_reps == 222
        @test r.n_thickness_spectra == 8
        @test r.n_affine_classes == 4
        @test r.n_perm_ea_classes == 2
        @test r.perm_thickness == [0 => 1, 1 => 7, 2 => 14, 3 => 58, 4 => 42, 5 => 84, 6 => 16]
        @test r.all_ok
    end
end
