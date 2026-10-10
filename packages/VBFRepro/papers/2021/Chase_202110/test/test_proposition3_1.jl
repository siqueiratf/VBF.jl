@testset "proposition3_1_test" begin
    include(joinpath(@__DIR__, "..", "proposition3_1.jl"))

    for (n, i) in ((5, 1), (5, 2), (7, 1))
        r = proposition3_1_build(n, i)
        @test r.mismatches == 0
        @test r.zeros_match
        @test r.w11_match
    end

    # The predicate itself: (0, 0) is not a Walsh zero, (a, 0) with a != 0 is.
    @test !is_walsh_zero_gold(0, 0, 5, 1)
    @test is_walsh_zero_gold(3, 0, 5, 1)

    # gold_dual really is the inverse of x^{2^i+1} composed with inversion:
    # (b^{-1/(2^i+1)})^{2^i+1} == b^{-1}.
    n, i = 5, 1
    for b = 1:(1<<n)-1
        d = gold_dual(b, n, i)
        @test gf_pow(d, gold_exp(i), n) == gf_inv(b, n)
    end
end
