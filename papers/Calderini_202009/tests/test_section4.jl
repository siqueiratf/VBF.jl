@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Code matrix dimensions for Gold x³ n=5
    F5 = load_apn_function("n5_Gold_x3")
    N = 5
    n_size = 1 << N

    C1 = ccz_matrix(F5)
    @test size(C1) == (2N + 1, n_size)          # (11, 32)

    C2 = ea_matrix(F5)
    @test size(C2) == (2N + 1, 2n_size - 1)     # (11, 63)

    C3 = c3_matrix(F5)
    @test size(C3) == (2N + 1, 2n_size - 1)     # (11, 63)

    # C₄ only for permutations — Gold x³ is not a permutation for n=5
    D = dillon_apn_permutation()
    C4 = c4_matrix(D)
    @test size(C4) == (2 * 6 + 1, 3 * 64 - 2)  # (13, 190)

    # C₄ throws for non-permutations
    @test_throws ArgumentError c4_matrix(kim_apn())

    # VBF's dillon_apn_permutation() is AE to its own inverse (it is F₂/F₃ in paper's notation)
    Dinv = perm_inverse(D)
    @test are_affine_equivalent(D, Dinv)   # Remark 4: F₂ (and F₃) are AE to their inverses
end
