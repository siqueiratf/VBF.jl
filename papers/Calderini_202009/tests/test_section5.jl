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

    # CCZ-equiv but not EA-equiv
    @test are_ccz_equivalent(K, D)
    @test !are_ea_equivalent(K, D)

    # perm_inverse round-trip
    Dinv = perm_inverse(D)
    @test is_permutation(Dinv)
    n_size = 64
    @test all(D.lut[Dinv.lut[y + 1] + 1] == y for y = 0:63)

    # VBF's dillon_apn_permutation() IS AE to its own inverse (it is F₂/F₃ in paper's notation)
    # Remark 4: F₂ and F₃ are affine-equivalent to their inverses
    @test are_affine_equivalent(D, Dinv)

    # Component degree distribution: {3 => 7, 4 => 56}
    degs = component_degrees(D)
    @test get(degs, 3, 0) == 7
    @test get(degs, 4, 0) == 56
    @test sum(values(degs)) == 63   # 2^6 - 1 components

    # Catalog: 14 n=6 APN CCZ-reps exist
    reps = load_n6_ccz_reps()
    @test length(reps) == 14
    @test all(differential_uniformity(r) == 2 for r in reps)

    # Kim CCZ-class is reprs6_4 (index 5 in 1-based sorted list)
    @test are_ccz_equivalent(K, reps[5])
end
