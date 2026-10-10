@testset "helpers_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))

    n = 6
    # Base function eq(6),a=1 == x³+trₙ(x⁹): APN, quadratic, round-trip via SBox.
    base = apn_eq6(n, 1)
    F = as_sbox(base, n)
    @test differential_uniformity(F) == 2
    @test algebraic_degree(F) == 2
    @test F.lut == base                       # SBox round-trip

    # eqs (4),(5) coincide with (7),(8) at a=1.
    @test apn_eq4(6) == apn_eq7(6, 1)
    @test apn_eq5(6) == apn_eq8(6, 1)

    # α = 2 is a primitive element of GF(2ⁿ)* (order 2ⁿ-1).
    α = primitive_element(n)
    ord = 1; p = α
    while p != 1
        p = gf_mul(p, α, n); ord += 1
    end
    @test ord == (1 << n) - 1

    # adjoint is an involution up to definition: (L*)* == L, and the trace-form
    # identity trₙ(x·L(y)) == trₙ(L*(x)·y) holds pointwise for L = trₙ.
    Llut = L_class_lut(:trace, n)
    Lstar = adjoint_lut(Llut, n)
    @test adjoint_lut(Lstar, n) == Llut
    for x = 0:5, y = 0:5
        lhs = gf_trace(gf_mul(x, apply_L(Llut, y), n), n)
        rhs = gf_trace(gf_mul(apply_L(Lstar, x), y, n), n)
        @test lhs == rhs
    end

    # ortho-derivative signature defined for the quadratic APN, distinguishes Gold.
    @test od_signature(base, n) !== nothing
end
