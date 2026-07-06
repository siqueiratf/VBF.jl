@testset "section3_2 (Proposition 16)" begin
    include(joinpath(@__DIR__, "..", "section3_2.jl"))

    N = 5
    F = gold_apn(N)
    T = storage_type(F)
    A0, B0 = _demo_maps(N, T)
    @test verify_proposition16(F, A0, B0)

    # Identity maps satisfy the relation trivially
    Id = identity_linear_map(N, T)
    @test verify_proposition16(F, Id, Id)

    # Non-APN multirank quadratic
    Q = pseudo_random_multirank_quadratic(6)
    A0q, B0q = _demo_maps(6, storage_type(Q))
    @test verify_proposition16(Q, A0q, B0q)

    # Jac_lin at 0 is always zero
    G = SBox{N,T}(T[A0(F.lut[B0(x)+1]) for x in 0:(1<<N)-1])
    @test all(c == 0 for c in jac_lin_cols(G, 0))
end
