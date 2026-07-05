@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    r3 = proposition1_build(3, 1)
    @test r3.sizes_ok
    @test r3.trace_ok
    @test (r3.s0, r3.s1, r3.s3) == (3, 3, 1)   # (2^3+1)/3, 2^2-1, (2^2-1)/3

    r5 = proposition1_build(5, 1)
    @test r5.sizes_ok
    @test r5.trace_ok
    @test (r5.s0, r5.s1, r5.s3) == (11, 15, 5) # (2^5+1)/3, 2^4-1, (2^4-1)/3

    # all remaining i with gcd(i,5)=1
    for i in (2, 3, 4)
        r = proposition1_build(5, i)
        @test r.sizes_ok
        @test r.trace_ok
    end
end
