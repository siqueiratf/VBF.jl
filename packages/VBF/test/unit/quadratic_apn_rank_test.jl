@testitem "quadratic_apn_rank" begin
    using VBF
    using Test
    using Random

    # Random function of algebraic degree <= 2:
    # F(x) = xor of c_{jk}*(x_j & x_k) over j<k, xor of l_j*x_j, xor constant.
    function rand_quadratic_sbox(rng, n)
        cq = Dict{Tuple{Int,Int},Int}()
        for j = 0:(n-1), k = (j+1):(n-1)
            cq[(j, k)] = rand(rng, 0:(1<<n)-1)
        end
        cl = [rand(rng, 0:(1<<n)-1) for _ = 1:n]
        c0 = rand(rng, 0:(1<<n)-1)
        lut = Vector{Int}(undef, 1 << n)
        for x = 0:(1<<n)-1
            v = c0
            for j = 1:n
                (x >> (j - 1)) & 1 == 1 && (v ⊻= cl[j])
            end
            for ((j, k), cjk) in cq
                ((x >> j) & 1 == 1 && (x >> k) & 1 == 1) && (v ⊻= cjk)
            end
            lut[x+1] = v
        end
        SBox{n}(lut)
    end

    @testset "known positives" begin
        for n in 3:8, k in 1:(n-1)
            gcd(k, n) == 1 || continue
            @test is_quadratic_apn_rank(gold_apn(n, k))
        end
        @test is_quadratic_apn_rank(kim_apn())
        @test is_quadratic_apn_rank(taniguchi_apn(4, 1, 1, 1))
    end

    @testset "known negatives (degree <= 2, not APN)" begin
        for n in 3:8
            # identity (degree 1): B_a == 0, rank 0
            @test !is_quadratic_apn_rank(SBox{n}(collect(0:(1<<n)-1)))
            # constant zero
            @test !is_quadratic_apn_rank(SBox{n}(zeros(Int, 1 << n)))
            # x^{2^k+1} with gcd(k, n) > 1 is quadratic but not APN
            if iseven(n)
                lut = [Int(gf_pow(x, (1 << 2) + 1, n)) for x = 0:(1<<n)-1]
                @test !is_quadratic_apn_rank(SBox{n}(lut))
            end
        end
    end

    @testset "parity with DDT check on random degree-<=2 inputs" begin
        rng = MersenneTwister(0xAB12)
        for n in 3:8, _ in 1:40
            F = rand_quadratic_sbox(rng, n)
            @test algebraic_degree(F) <= 2
            @test is_quadratic_apn_rank(F) == (differential_uniformity(F) == 2)
        end
    end

    @testset "parity with is_quadratic_apn on quadratic inputs" begin
        rng = MersenneTwister(0xCD34)
        for n in 3:6, _ in 1:10
            F = rand_quadratic_sbox(rng, n)
            # is_quadratic_apn == (quadratic APN); on degree-<=2 inputs the rank
            # check must agree whenever F is genuinely quadratic (degree == 2)
            if algebraic_degree(F) == 2
                @test is_quadratic_apn_rank(F) == is_quadratic_apn(F)
            end
        end
    end
end
