@testset "theorem6_test" begin
    include(joinpath(@__DIR__, "..", "theorem6.jl"))

    # m=2, i=1: k=1, q=2, n=6
    let m = 2, i = 1
        k = gcd(i, m)
        lut = family2_lut(m, i)
        @test length(lut) == 1 << (3m)
        @test differential_uniformity(SBox(lut)) == 1 << k
        @test lut[1] == 0
    end

    # m=3, i=1: k=1, q=2, n=9; m/k=3 odd → permutation (Theorem 7)
    let m = 3, i = 1
        k = gcd(i, m)
        lut = family2_lut(m, i)
        @test length(lut) == 1 << (3m)
        @test differential_uniformity(SBox(lut)) == 1 << k   # APN (Theorem 6)
        @test is_permutation(SBox(lut))                       # Theorem 7
    end

    # m=3, i=2: k=1, q=4; m/k=3 odd → permutation
    let m = 3, i = 2
        k = gcd(i, m)
        lut = family2_lut(m, i)
        @test differential_uniformity(SBox(lut)) == 1 << k
        @test is_permutation(SBox(lut))
    end

    # Univariate root conditions hold for m=3, i=1
    let (c1, c2, c3) = theorem6_root_conditions(3, 1)
        @test c1 && c2 && c3
    end

    # Family 1 and Family 2 give distinct functions at m=3, i=1
    lut1 = family1_lut(3, 1)
    lut2 = family2_lut(3, 1)
    @test lut1 != lut2
end
