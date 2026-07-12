@testset "theorem5_test" begin
    include(joinpath(@__DIR__, "..", "theorem5.jl"))

    cases = theorem5_build()             # m = 3, 4 (n = 6, 8) — fast cases
    @test length(cases) == 5             # F1 x {(3,1),(4,1),(4,3)} + F2 x {3,4}

    for r in cases
        # Theorem 5 preconditions: quadratic APN with F(0) = 0
        @test r.apn
        @test r.zero_fixed
        # Paper Section 5: F1 members are 3-to-1, F2 members are not
        @test r.three_to_one == (r.fam == "F1")
        # Both families have Gold-like spectra {0, 2^{n/2}, 2^{n/2+1}}
        @test r.gold_like
    end
end
