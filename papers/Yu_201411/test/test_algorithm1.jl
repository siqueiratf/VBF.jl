include(joinpath(@__DIR__, "..", "algorithm1.jl"))

@testset "Yu_201411 - Algorithm 1 candidate sets" begin
    n = 5
    H = quadratic_apn_matrix(gold_apn(n, 1))
    S = algorithm1_initial_sets(H)

    @test length(S) == (1 << (n - 1)) - 1
    @test all(!isempty, values(S))
    @test all(v -> length(v) == 24, values(S))
end

@testset "Yu_201411 - Algorithm 1 emits validated QAMs" begin
    n = 5
    H = quadratic_apn_matrix(gold_apn(n, 1))
    r = generate_qam_algorithm1(H; limit = 1, max_nodes = 100_000, validate = true)

    @test r.generated == 1
    @test !isempty(r.matrices)
    @test is_qam(r.matrices[1])

    F = qam_to_sbox(r.matrices[1])
    @test differential_uniformity(F) == 2
    @test algebraic_degree(F) == 2
end

@testset "Yu_201411 - full search budget guard" begin
    @test isempty(search_qam_full(6; max_evaluations = 0))
end
