@testset "theorem6_test" begin
    include(joinpath(@__DIR__, "..", "theorem6.jl"))

    # m=9 (n=8), i=1: source is AB permutation
    F_lut = budaghyan_lut(9, 1)
    F_src  = SBox{9}(F_lut)
    @test is_permutation(F_src)
    @test differential_uniformity(F_src) == 2   # APN

    # Theorem 6 construction: diff-4-uniform perm
    F_prime = theorem6_build(9, 1)
    @test is_permutation(F_prime)
    @test differential_uniformity(F_prime) == 4

    # Remark 2: d°(F'^{-1}) = 5 for m=9
    @test algebraic_degree(sbox_inverse(F_prime)) == 5
end
