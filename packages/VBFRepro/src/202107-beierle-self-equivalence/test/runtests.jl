using Test
using LinearAlgebra: I
using Nemo
using VBF

include("../algorithm1.jl")
include("../corollary1_n6n7n8.jl")
include("../proposition4.jl")
include("../proposition5.jl")
include("test_proposition4.jl")
include("test_proposition5.jl")
include("test_APNSearch.jl")
include("test_algorithm1.jl")
include("test_lemma5_lemma6.jl")

@testset "Linearly self-equivalent APN permutation tuple experiment" begin
    F = GF(2)
    identity3 = identity_matrix(F, 3)

    @test check_order_space(identity3, 2) == 3.0
    @test is_permutation_tuple(identity3, identity3) == true
    @test length(gen_permutation_tuples(6)) == 17
    generated = generate_tuple_matrix_constants_file(6; output = joinpath(mktempdir(), "n6.toml"))
    @test generated.count == 17
    @test verify_generated_tuple_classes(6, generated.blocks)
    @test length(_load_tuple_matrix_blocks(generated.output)) == 17
    # These exact class-key runs now take less than a second each after startup.
    for (n, expected) in ((7, 27), (8, 32))
        generated = generate_tuple_matrix_constants_file(n; output = joinpath(mktempdir(), "n$n.toml"), full_search = true)
        @test generated.count == expected
        @test verify_generated_tuple_classes(n, generated.blocks)
    end
end
