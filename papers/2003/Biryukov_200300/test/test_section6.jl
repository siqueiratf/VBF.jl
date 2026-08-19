@testset "section6_generalized_even_mansour" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    # A concrete key recovery: build the cipher, then break it with AE alone.
    rng = MersenneTwister(20030504)
    N = 5
    F = random_permutation_sbox(rng, Val(N))
    T = storage_type(F)
    mask = T((1 << N) - 1)
    A1 = F2AffineMap{N,T}(random_invertible_linear_map(rng, Val(N), T), rand(rng, T) & mask)
    A2 = F2AffineMap{N,T}(random_invertible_linear_map(rng, Val(N), T), rand(rng, T) & mask)
    S = even_mansour_cipher(F, A1, A2)

    key = recover_even_mansour_key(F, S)
    @test key !== nothing
    @test even_mansour_cipher(F, key.A1, key.A2).lut == S.lut

    # The anchored map fixes 0, which is what lets LE be applied.
    @test anchor_at(S, 3).lut[1] == 0
    @test anchor_at(F, 0).lut[1] == 0

    # A cipher built from an unrelated F is not recoverable from this F.
    G = random_permutation_sbox(rng, Val(N))
    if !are_affine_equivalent(F, G)
        @test recover_even_mansour_key(F, even_mansour_cipher(G, A1, A2)) === nothing
    end

    # Sect. 6: n^3·2^{2n} beats exhaustive 2^{n^2} for every n ≥ 4.
    @test all(attack_log2_cost(n) < exhaustive_log2_cost(n) for n in (4, 8, 16, 32))

    # Full report passes.
    @test section6_report(devnull)
end
