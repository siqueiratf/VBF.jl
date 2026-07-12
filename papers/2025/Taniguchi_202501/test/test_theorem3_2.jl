@testset "theorem3_2_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_2.jl"))

    # Example 3.3: n=4 → 448 valid L mappings
    @test count_valid_L(4; mod=paper_modulus(4)) == 448

    # Theorem 3.2: L=0 always valid (G = x^3 is APN)
    for n in [4, 5]
        mod = paper_modulus(n)
        T0 = trace_zero_elements(n, mod)
        e0 = trace_one_element(n, mod)
        @test theorem3_2_check(zeros(Int, n), n, mod, T0, e0)
    end
end
