@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    r = section4_run(; seed = 42)

    @test r.A5_is_I
    @test r.A1_not_I
    @test r.A2_not_I
    @test r.A3_not_I
    @test r.A4_not_I

    @test r.n_free  == 40
    @test r.n_pivot == 184

    @test r.va_zero
    @test r.va_rand
end
