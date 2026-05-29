@testitem "three_to_one_equivalence" begin
using VBF
using Test
using Random

N = 4
mono(e) = SBox{N}(gf_monomial_lut(N, e))
check(L1, L2, A, B) = all(L1(A(L2(x))) == B(x) for x in 0:(1 << N) - 1)
idcols = [UInt8(1) << j for j in 0:N - 1]

@testset "canonical triplicate detection" begin
    @test canonical_triplicate(mono(3)) !== nothing      # x³ over GF(2⁴)
    @test canonical_triplicate(mono(6)) !== nothing      # x⁶ = (x³)²
    @test canonical_triplicate(SBox(UInt8[0, 1, 2, 3])) === nothing  # identity: not 3-to-1
end

@testset "linear equivalence of canonical 3-to-1 functions" begin
    C1 = mono(3)
    C2 = mono(6)                                          # = squaring ∘ x³, linear-equiv
    r = are_3to1_linear_equivalent(C1, C2)
    @test r !== nothing
    @test check(r[1], r[2], C1, C2)                       # returned (L1, L2) is valid
    # equivalent to itself
    s = are_3to1_linear_equivalent(C1, C1)
    @test s !== nothing && check(s[1], s[2], C1, C1)
    # guard: a non-canonical-triplicate input (n=4 identity permutation) → nothing
    @test are_3to1_linear_equivalent(SBox{N}(collect(UInt8, 0:15)), C1) === nothing
end

@testset "linear self-equivalences" begin
    C = mono(3)
    sols = self_3to1_linear_equivalences(C)
    @test !isempty(sols)
    @test all(check(L1, L2, C, C) for (L1, L2) in sols)   # every pair is a self-equivalence
    @test any(L1.cols == idcols && L2.cols == idcols for (L1, L2) in sols)  # identity present
    # the found pairs are distinct
    @test length(unique((L1.cols, L2.cols) for (L1, L2) in sols)) == length(sols)
end

@testset "canonical representative of a 3-to-1 function (alg2)" begin
    rng = MersenneTwister(0xA12)
    Lin = random_invertible_linear_map(rng, Val(N))
    T = SBox{N}([gf_pow(Lin(x), 3, N) for x in 0:(1 << N) - 1])   # x³∘L: zero-sum 3-to-1, non-canonical
    @test is_3_to_1(T)
    @test canonical_triplicate(T) === nothing                    # not canonical as given
    r = canonical_3to1_representative(T)
    @test r !== nothing
    C, L2 = r
    @test all(C(x) == T(L2(x)) for x in 0:(1 << N) - 1)          # C = T ∘ L2
    @test canonical_triplicate(C) !== nothing                    # C is canonical
    @test is_3_to_1(C)
    # an already-canonical input still canonicalizes consistently
    C0, L0 = canonical_3to1_representative(mono(3))
    @test canonical_triplicate(C0) !== nothing && all(C0(x) == mono(3)(L0(x)) for x in 0:(1 << N) - 1)
end
end
