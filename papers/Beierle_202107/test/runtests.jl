using Test
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

@testset "Linearly self-equivalent APN permutation tuple experiment" begin
    F = GF(2)
    identity3 = identity_matrix(F, 3)

    @test check_order_space(identity3, 2) == 3.0
    @test is_permutation_tuple(identity3, identity3) == true
    @test length(gen_permutation_tuples(6)) == 17
    #@test length(gen_permutation_tuples(7)) == 27
    #@test length(gen_permutation_tupl8)) == 32
end
