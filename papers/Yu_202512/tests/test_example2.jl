@testset "example2_test" begin
    include(joinpath(@__DIR__, "..", "example2.jl"))

    # Paper Example 2: n=5 cyclic representatives and index array
    cr = get_cyclic_reps(5)
    id = get_indices(5, cr)

    @test cr == [1, 3, 5, 7, 11, 15, 31]
    @test length(cr) == 7
    @test id[1, :] == [0, 1, 1, 2, 2, 4, 6]
    @test id[2, :] == [1, 2, 3, 3, 4, 4, 5]

    # Reconstruction: CR[t] = CR[ID[1,t]] + 2^{ID[2,t]-1} for t=2..K
    for t in 2:length(cr)
        pred          = id[1, t] == 0 ? 0 : cr[id[1, t]]
        reconstructed = pred + (1 << (id[2, t] - 1))
        @test reconstructed == cr[t]
    end
end
