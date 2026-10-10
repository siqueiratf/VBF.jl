@testset "proposition8_test" begin
    include(joinpath(@__DIR__, "..", "proposition8.jl"))

    # m=3: n=9, m odd → APN permutation (AB)
    let m = 3
        lut = proposition8_lut(m)
        @test length(lut) == 1 << (3m)
        @test lut[1] == 0
        @test differential_uniformity(SBox(lut)) == 2
        @test is_permutation(SBox(lut))

        c1, c2, c3 = proposition8_root_conditions(m)
        @test c1 && c2 && c3
    end

    # m=5: gcd(5,7)=1 ✓; n=15, m odd → permutation
    let m = 5
        lut = proposition8_lut(m)
        @test differential_uniformity(SBox(lut)) == 2
        @test is_permutation(SBox(lut))
    end

    # Proposition 4 and 8 give different functions at m=3
    @test proposition4_lut(3) != proposition8_lut(3)

    # gcd(m,7)=7 case must throw
    @test_throws ArgumentError proposition8_lut(7)
end
