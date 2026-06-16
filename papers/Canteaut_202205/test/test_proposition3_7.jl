@testset "proposition3_7" begin
    include(joinpath(@__DIR__, "..", "proposition3_7.jl"))

    N = 5
    T = UInt8
    F = gold_apn(N)

    # Swap e0 and e1
    A0_cols = UInt8[2, 1, 4, 8, 16]
    A0 = F2LinearMap{N,T}(A0_cols)

    # Cyclic shift
    B0_cols = UInt8[T(1) << ((j+1) % N) for j in 0:(N-1)]
    B0 = F2LinearMap{N,T}(B0_cols)

    @test verify_proposition3_7(F, A0, B0)

    # Identity maps should also satisfy the relation trivially
    Id = identity_linear_map(N, T)
    @test verify_proposition3_7(F, Id, Id)

    # Round-trip: Jac_lin (A0 ∘ F ∘ B0)(x) at x=0 should be zero
    G = SBox{N,T}(UInt8[A0(F.lut[B0(x)+1]) for x in 0:(1<<N)-1])
    cols_G0 = jac_lin_cols(G, 0)
    @test all(c == 0 for c in cols_G0)  # Jac_lin at 0 is always zero
end
