@testset "algorithm1" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    N = 5
    T = UInt8
    F = gold_apn(N)
    n_size = 1 << N

    # Build a known EA triple (same as algorithm1_report)
    A0_cols = UInt8[2, 1, 4, 8, 16]
    A0 = F2LinearMap{N,T}(A0_cols)
    B0_cols = UInt8[T(1) << ((j+1) % N) for j in 0:(N-1)]
    B0 = F2LinearMap{N,T}(B0_cols)
    C0_cols = UInt8[T(1) << (N-1-j) for j in 0:(N-1)]
    C0 = F2LinearMap{N,T}(C0_cols)
    a_const = T(3)

    G_lut = UInt8[A0(F.lut[B0(x)+1]) ⊻ C0(T(x)) ⊻ a_const for x in 0:(n_size-1)]
    G = SBox{N,T}(G_lut)

    # Algorithm 1 must find a valid EA triple
    triple = ea_recovery_quadratic(F, G; max_guesses=1 << (3*N))
    @test triple !== nothing

    if triple !== nothing
        A0_r, B0_r, C0_r, a_r = triple.A0, triple.B0, triple.C0, triple.a_const
        # Verify the recovered triple
        @test all(
            G.lut[x+1] == A0_r(F.lut[B0_r(x)+1]) ⊻ C0_r(T(x)) ⊻ a_r
            for x in 0:(n_size-1)
        )
    end

    # Identity EA triple: G = F (A0=I, B0=I, C0=0, a=0)
    triple_id = ea_recovery_quadratic(F, F; max_guesses=1 << (3*N))
    @test triple_id !== nothing
    if triple_id !== nothing
        A0_r, B0_r, C0_r, a_r = triple_id.A0, triple_id.B0, triple_id.C0, triple_id.a_const
        @test all(
            F.lut[x+1] == A0_r(F.lut[B0_r(x)+1]) ⊻ C0_r(T(x)) ⊻ a_r
            for x in 0:(n_size-1)
        )
    end
end
