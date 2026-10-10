@testset "algorithm2_test" begin
    include(joinpath(@__DIR__, "..", "algorithm2.jl"))

    # Algorithm 2: outer permutation enumeration.
    # Gold x^3 n=6 |K| = 1008 (Table 1, row 1.1 in paper).
    F6 = gold_x3(6)
    auts6 = partition_automorphisms(F6, 4)
    @test length(auts6) == 1008

    # Each automorphism is a linear bijection (all images distinct).
    for L_lut in auts6[1:min(3, end)]
        @test length(unique(L_lut)) == 64
    end

    # For Gold x^3 n=5: trivial partition (2 buckets, sizes [1,31]) →
    # essentially all of GL(5,F₂) preserves it → large automorphism group.
    F5 = gold_x3(5)
    auts5 = partition_automorphisms(F5, 4)
    @test length(auts5) ≥ 1000   # very large for trivial partition

    # For G = EA-equivalent to F6, outer_permutations_all finds 1008 candidates
    # (same partition signature, identity bucket map).
    G6_lut = UInt8[UInt8(xor(Int(F6.lut[xor(x, 1) + 1]), 2)) for x = 0:63]
    G6 = SBox{6,UInt8}(G6_lut)
    result = outer_permutations_all(F6, G6; k = 4)
    total_candidates = sum(length(ls) for ls in result.Ls_per_sigma; init = 0)
    @test total_candidates == 1008
end
