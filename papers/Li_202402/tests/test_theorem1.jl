@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    # m=2, i=1: k=1, q=2, n=6; m/k=2 even → not guaranteed permutation
    let m = 2, i = 1
        k = gcd(i, m)
        lut = family1_lut(m, i)
        @test length(lut) == 1 << (3m)
        @test differential_uniformity(SBox(lut)) == 1 << k
        # Round-trip: F maps 0 -> 0 (since F(0,0,0) = (0,0,0))
        @test lut[1] == 0
    end

    # m=3, i=1: k=1, q=2, n=9; m/k=3 odd → permutation (Theorem 3)
    let m = 3, i = 1
        k = gcd(i, m)
        lut = family1_lut(m, i)
        @test length(lut) == 1 << (3m)
        @test differential_uniformity(SBox(lut)) == 1 << k   # APN (Theorem 1)
        @test is_permutation(SBox(lut))                       # Theorem 3
    end

    # m=3, i=2: k=gcd(2,3)=1, q=4; m/k=3 odd → permutation
    let m = 3, i = 2
        k = gcd(i, m)
        lut = family1_lut(m, i)
        @test differential_uniformity(SBox(lut)) == 1 << k
        @test is_permutation(SBox(lut))
    end

    # Univariate root conditions hold for m=3, i=1
    let (c1, c2, c3) = theorem1_root_conditions(3, 1)
        @test c1 && c2 && c3
    end

    # m=4, i=2: k=gcd(2,4)=2, du=4 (differentially 4-uniform)
    let m = 4, i = 2
        k = gcd(i, m)
        lut = family1_lut(m, i)
        @test differential_uniformity(SBox(lut)) == 1 << k   # = 4
    end
end
