@testset "proposition4_test" begin
    include(joinpath(@__DIR__, "..", "proposition4.jl"))

    # Proposition 4: i=1, q=2, gcd(m,7)=1
    # m=3: n=9, m odd → APN permutation (AB)
    let m = 3
        lut = proposition4_lut(m)
        @test length(lut) == 1 << (3m)
        @test lut[1] == 0                            # F(0,0,0) = (0,0,0)
        @test differential_uniformity(SBox(lut)) == 2
        @test is_permutation(SBox(lut))              # m=3 odd, Theorem 3

        c1, c2, c3 = proposition4_root_conditions(m)
        @test c1 && c2 && c3                         # all polys root-free in GF(8)
    end

    # m=5: gcd(5,7)=1 ✓; n=15, m odd → permutation
    let m = 5
        lut = proposition4_lut(m)
        @test differential_uniformity(SBox(lut)) == 2
        @test is_permutation(SBox(lut))
    end

    # gcd(m,7)=7 case must throw
    @test_throws ArgumentError proposition4_lut(7)
end
