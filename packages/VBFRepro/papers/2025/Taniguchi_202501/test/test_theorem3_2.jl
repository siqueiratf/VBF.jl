@testset "theorem3_2_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_2.jl"))

    # Example 3.3: n=4 → 448 valid L mappings
    @test count_valid_L(4; mod=paper_modulus(4)) == 448

    @test count_valid_L(5; mod=paper_modulus(5)) == 4608
    bounded = count_valid_L_bounded(6; max_evaluations = 100)
    @test bounded.status == :budget_hit
    @test bounded.evaluated == bounded.next_index == 100
    @test !bounded.exhaustive
    @test bounded.total == 1 << 30
    @test_throws ArgumentError count_valid_L(6)
    # Interval continuation has explicit boundaries, without repeating indices.
    first = count_valid_L_bounded(4; max_evaluations = 100)
    rest = count_valid_L_bounded(4; start_index = first.next_index, max_evaluations = typemax(Int))
    @test first.count + rest.count == 448
    @test !rest.exhaustive
    @test rest.interval_exhausted
    # Theorem 3.2: L=0 always valid (G = x^3 is APN)
    for n in [4, 5]
        mod = paper_modulus(n)
        T0 = trace_zero_elements(n, mod)
        e0 = trace_one_element(n, mod)
        @test theorem3_2_check(zeros(Int, n), n, mod, T0, e0)
    end
end
