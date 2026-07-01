@testset "proposition3_2_test" begin
    include(joinpath(@__DIR__, "..", "proposition3_2.jl"))

    r = proposition3_2_build()
    # Paper (Remark 3.2) reports N_1=86, N_2=340, N_3=4.
    # Our N_1=85 = |S(F)\{0}|; paper's 86 = |S(F)| (convention differs by 1).
    # N_2 and N_3 are the key discriminators; they match exactly.
    @test r.N1 == 85    # |S(F) \ {0}|; paper writes 86 (counts 0 too)
    @test r.N2 == 340
    @test r.N3 == 4
    @test r.S_size == 86  # |S(F)| matches paper's N_1=86
end
