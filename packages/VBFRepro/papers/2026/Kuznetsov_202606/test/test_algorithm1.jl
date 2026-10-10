@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # Small budget: 20 samples, deterministic seed
    r = algorithm1_run(; sample_size = 20, seed = 42)

    @test !r.exhaustive
    @test r.sampling == :with_replacement
    @test_throws ArgumentError algorithm1_run(; sample_size = 0)
    @test r.sample_size == 20
    @test 0 <= r.n_apn <= 20
    @test 0.0 <= r.density <= 1.0

    # Pipeline correctness: every returned function is in V_A
    A     = build_A_matrix()
    A_lut = build_A_lut(A)
    param = fc22_sol22(A)
    n_free = length(param.free_cols)

    import Random
    rng = Random.MersenneTwister(42)
    for _ in 1:5
        b   = rand(rng, Bool, n_free)
        c   = apply_fc22_sol22(b, param.pivot_cols, param.free_cols, param.S)
        lut = quadratic_lut(c)
        @test in_va(lut, A_lut, A)
    end
end
