@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))

    r3 = proposition2_build(3, 1)
    @test r3.ok
    @test sum(r3.case_counts) == r3.n_pairs == 64
    # U=V=0 once; 4-sol case: 7 U × 3 nonzero trace-0 values of 1+V/U; rest 2-sol
    @test r3.case_counts == [1, 21, 42]

    r5 = proposition2_build(5, 1)
    @test r5.ok
    @test sum(r5.case_counts) == r5.n_pairs == 1024
    @test r5.case_counts == [1, 465, 558]   # 31 U × 15 nonzero trace-0 values

    # all remaining i with gcd(i,5)=1
    for i in (2, 3, 4)
        @test proposition2_build(5, i).ok
    end
end
