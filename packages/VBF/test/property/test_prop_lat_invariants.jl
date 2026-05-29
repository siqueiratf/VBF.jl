using VBF
using Test
using Random

const RNG = MersenneTwister(0xBFA02)

@testset "LAT invariants on 5 random functions per N ∈ {3,4,5,6}" begin
    for N in (3, 4, 5, 6)
        for _ in 1:5
            s = random_function_sbox(RNG, Val(N))
            L = lat(s)
            n = 1 << N

            # LAT[0, 0] = 2^N
            @test L[1, 1] == n
            # column b = 0 is zero everywhere except row 0
            @test all(==(0), view(L, 2:n, 1))

            # all entries are even (N ≥ 2)
            @test all(iseven, L)

            # Parseval per column: ∑_a LAT[a, b]² = 2^(2N)
            target = n * n
            for b in 1:n
                @test sum(view(L, :, b) .^ 2) == target
            end

            # linearity matches direct max
            lin_direct = 0
            for a in 1:n, b in 1:n
                a == 1 && b == 1 && continue
                v = abs(L[a, b])
                v > lin_direct && (lin_direct = v)
            end
            @test linearity(s) == lin_direct
        end
    end
end
