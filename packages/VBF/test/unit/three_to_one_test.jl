@testitem "three_to_one" begin
using VBF
using VBFCatalog
using Test
using Random

gold(n) = SBox{n}(gf_monomial_lut(n, 3))

@testset "is_3_to_1" begin
    @test is_3_to_1(gold(4))                              # x³ over GF(2⁴): 3-to-1
    @test !is_3_to_1(gold(5))                             # x³ over GF(2⁵): a permutation
    @test !is_3_to_1(random_permutation_sbox(MersenneTwister(1), Val(4)))
    @test !is_3_to_1(gold(3))                             # odd n: cannot be 3-to-1
end

@testset "triplicate adjoint / EA-equivalence to triplicate" begin
    F = gold(4)
    L = triplicate_adjoint(F)
    @test L !== nothing
    @test is_equivalent_to_triplicate(F)
    # self-consistency: the returned L satisfies W_F(L(b), b) ≡ 1 (mod 3) ∀ b
    W = lat(F)
    @test all(mod(W[L(b) + 1, b + 1], 3) == 1 for b in 0:15)
    @test !isempty(triplicate_adjoints(F))
    # triplicate-equivalence is preserved under linear equivalence
    rng = MersenneTwister(7)
    G = random_invertible_linear_map(rng, Val(4)) ∘ F ∘ random_invertible_linear_map(rng, Val(4))
    @test is_equivalent_to_triplicate(G)
end
end
