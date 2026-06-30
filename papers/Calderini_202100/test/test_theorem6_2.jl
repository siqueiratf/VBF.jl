@testset "theorem6_2_test" begin
    include(joinpath(@__DIR__, "..", "theorem6_2.jl"))

    mod4 = primitive_polynomial(4)
    m, i = 4, 1

    # Find one valid pair quickly
    found = false
    for b in 0:15, c in 0:15
        theorem6_2_condition(m, i, b, c; modulus = mod4) || continue
        F  = theorem6_2_sbox(m, i, b, c; modulus = mod4)
        @test differential_uniformity(F) == 2
        @test algebraic_degree(F) == 2
        found = true
        break
    end
    @test found

    # Find one invalid pair (c=0 b=0 gives inner=1, 1^5+x^5=0 when x^5=1 => has zeros)
    @test !theorem6_2_condition(m, i, 0, 0; modulus = mod4)
    F0 = theorem6_2_sbox(m, i, 0, 0; modulus = mod4)
    @test differential_uniformity(F0) != 2

    # Full exhaustive check
    r = theorem6_2_report(devnull; m = m, i = i)
    @test r.all_ok
    @test r.fail_count == 0
end
