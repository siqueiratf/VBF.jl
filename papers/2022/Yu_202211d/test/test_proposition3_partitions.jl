using Test

@testset "Proposition 3: spanning subspace dimensions" begin
    @test rank_f2(UInt.(prop3_V_basis()); nbits = 8) == 5   # dim V = 5
    @test rank_f2(UInt.(prop3_U_basis()); nbits = 8) == 5   # dim U = 5
end

@testset "Proposition 3: candidate-set cardinalities (7, 112, 3, 96)" begin
    card = prop3_cardinalities()
    @test card.A == 7
    @test card.B == 2^7 - 2^4      # 112
    @test card.c == 3
    @test card.G == 2^7 - 2^5      # 96
    # the dependent sets must hold for every choice of x_13 / x_12
    for x13 in prop3_candidates_x13()
        @test length(prop3_candidates_x7(x13)) == 3
    end
end

@testset "Proposition 3 / Theorem 2: reducing x_13 into A" begin
    r = reduce_x13_into_A()
    @test r.ok
    @test r.reduced_in_A
    @test r.symmetric
    @test r.same_qam
    @test r.ea_equiv
end
