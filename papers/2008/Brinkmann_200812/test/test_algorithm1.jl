@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # Algorithm 1's stateful filter re-derives the exact Table 4 entries that are
    # reachable by leaf enumeration — without ever computing a DDT.
    @test count_apn_backtrack(1) == 4
    @test count_apn_backtrack(2) == 192
    @test count_apn_backtrack(3) == 688128

    # The filter is exactly Lemma 1's criterion: on n = 2 the surviving leaves are
    # precisely the differentially-2-uniform LUTs.
    brute = 0
    for lut in Iterators.product(0:3, 0:3, 0:3, 0:3)
        differential_uniformity(SBox{2}(collect(lut))) == 2 && (brute += 1)
    end
    @test brute == count_apn_backtrack(2)

    # Note 9's generators, de-mangled from the OCR cycle notation (Paper Issue 5).
    gens = note9_generators()
    @test length(gens) == 3
    s = Int.(table3_luts()[1].lut)
    for h in gens
        @test sort(h) == collect(0:31)
        @test is_affine_perm(h, 5)
        @test is_ea_self_equivalence(s, h, 5)
    end

    # h₃ is x ↦ x ⊕ 1.
    @test gens[3] == [x ⊻ 1 for x in 0:31]

    # The generated group has the paper's first n=5 stabiliser order.
    @test permutation_group_order(gens, 5) == 4960

    # Non-members are rejected. |H| = 4960 out of |AGL(5,2)| = 3.2·10⁸, so almost
    # every affine bijection is outside H — e.g. the 1-bit rotation.
    rotl1 = [((x << 1) | (x >> 4)) & 31 for x in 0:31]
    @test is_affine_perm(rotl1, 5)
    @test !is_ea_self_equivalence(s, rotl1, 5)
    # A non-affine permutation is rejected outright (H ⊆ AGL(5,2)).
    @test !is_affine_perm(Int.(gold_apn(5, 1).lut), 5)
    @test !is_ea_self_equivalence(s, Int.(gold_apn(5, 1).lut), 5)
    # H does contain the full translation group (h₃ = x ⊕ 1 generates it with the
    # other two), so x ↦ x ⊕ 2 is a member.
    @test is_ea_self_equivalence(s, [x ⊻ 2 for x in 0:31], 5)
end
