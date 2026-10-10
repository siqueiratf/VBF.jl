@testset "remark3_test" begin
    include(joinpath(@__DIR__, "..", "remark3.jl"))

    # Gold: e(2,k) = 2^k + 1
    for k in 1:8
        @test e_exponent(2, k) == (1 << k) + 1
    end

    # Gold APN check: x^{e(2,k)} over GF(2^n) with gcd(k,n)=1
    for n in [5, 7, 9]
        for k in 1:n-1
            if gcd(k, n) == 1
                e = e_exponent(2, k)
                sbox = SBox(gf_monomial_lut(n, e))
                @test differential_uniformity(sbox) == 2
            end
        end
    end

    # Inverse: e(n-1,1) = 2^{n-1} - 1
    for n in 2:16
        @test e_exponent(n - 1, 1) == (1 << (n - 1)) - 1
    end

    # Inverse APN check for odd n
    for n in [3, 5, 7, 9, 11, 13]
        e = e_exponent(n - 1, 1)
        sbox = SBox(gf_monomial_lut(n, e))
        @test differential_uniformity(sbox) == 2
    end
end
