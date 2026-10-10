@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # m=1 has no valid μ: norm_exp = 2^2+2^1+1 = 7 = |F*_{2^3}|, so μ^7=1 for all μ
    μ1, found1 = find_valid_mu(1, 1)
    @test !found1
    @test μ1 == -1

    # m=3, s=1: valid μ must exist (Bartoli et al.; Remark 1 in paper)
    μ3, found3 = find_valid_mu(3, 1)
    @test found3
    @test μ3 > 0

    # f(0) = 0: zero maps to zero
    for m in [2, 3]
        μ, found = find_valid_mu(m, 1)
        found || continue
        F = theorem3_sbox(m, 1, μ, 1)
        @test F.lut[1] == 0
    end

    # Theorem 3 APN: differential uniformity = 2 for m=2,3
    for m in [2, 3]
        μ, found = find_valid_mu(m, 1)
        found || continue
        F  = theorem3_sbox(m, 1, μ, 1)
        du = differential_uniformity(F)
        @test du == 2
        @test algebraic_degree(F) <= 2
    end
    # Table V row 12: u^5=32, u^73=336 with u a root of x^9+x^4+1.
    # SHA was recomputed using independent polynomial-bit field arithmetic.
    using SHA
    table = theorem3_sbox(3,1,32,336;modulus=529)
    bytes = reduce(vcat, ([UInt8(Int(x)&255),UInt8(Int(x)>>8)] for x in table.lut))
    @test bytes2hex(sha256(bytes)) == "9e39a50900690f69a950d794b2974c0cbd286a24c5cf8f67a40fa3ea8d402ff4"
    @test differential_uniformity(table) == 2
    @test algebraic_degree(table) == 2
    @test Dict(sorted_pairs(differential_spectrum(ortho_derivative(table)))) ==
        Dict(0=>170667,2=>66297,4=>15911,6=>5705,8=>1974,10=>385,12=>140,14=>84,16=>168,18=>147,20=>63,22=>63,24=>21,26=>7)
    @test_throws ArgumentError theorem3_sbox(3,1,32,2;modulus=529) # outside embedded GF(8)
    @test_throws ArgumentError theorem3_sbox(3,1,32,0;modulus=529)
    @test_throws ArgumentError theorem3_sbox(3,1,1,1;modulus=529) # norm=1
    @test_throws ArgumentError find_valid_mu(3,3)
    # All seven nonzero embedded subfield scalars meet the theorem hypothesis.
    scalars = [v for v in 1:511 if gf_pow(v,8,9;modulus=529)==v]
    @test length(scalars) == 7
    @test all(differential_uniformity(theorem3_sbox(3,1,32,v;modulus=529))==2 for v in scalars)

    @test find_valid_mu(2,1) == (-1,false)

end
