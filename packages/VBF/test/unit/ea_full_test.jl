@testitem "ea_full" begin
using VBFCatalog
using VBF
using Test

@testset "ea_equivalences: empty for incompatible / non-permutations" begin
    s4 = load_literature_sbox("PRESENT")
    s5 = load_apn_function("n5_Gold_x3")
    @test isempty(ea_equivalences(s4, s5))   # different N
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    @test isempty(ea_equivalences(s4, c))
end

@testset "ea_equivalences: non-empty iff are_ea_equivalent" begin
    F = load_literature_sbox("PRESENT")
    H = load_literature_sbox("SKINNY_4")
    @test (!isempty(ea_equivalences(F, F))) == are_ea_equivalent(F, F; strategy = :heggebakk)
    @test (!isempty(ea_equivalences(F, H))) == are_ea_equivalent(F, H; strategy = :heggebakk)
end

@testset "ea_equivalences: every triple verifies G = L1∘F∘A2 ⊕ A_drift" begin
    F = load_literature_sbox("PRESENT")
    N, T = 4, UInt8
    eqs = ea_equivalences(F, F)
    @test !isempty(eqs)
    for e in eqs
        @test is_invertible(e.L1)
        @test is_invertible(e.A2)
        @test all(0:15) do x
            e.L1(F.lut[e.A2(T(x)) + 1]) ⊻ e.A_drift.lut[x + 1] == F.lut[x + 1]
        end
    end
end

@testset "ea_equivalences: degenerate monomial-APN partition short-circuits" begin
    # n5_Gold_x3 has signature [31, 1]; outer count = |GL(5,F₂)| ≫ default cap, so ea_equivalences returns empty (heggebakk limitation).
    F = load_apn_function("n5_Gold_x3")
    @test isempty(ea_equivalences(F, F))
end

@testset "partition_automorphisms: all bijective + preserve buckets" begin
    F = load_literature_sbox("PRESENT")
    N, T = 4, UInt8
    pa = partition_automorphisms(F)
    @test !isempty(pa)
    p = ea_partition(F, 4)
    for L in pa[1:min(end, 30)]
        @test sort(L) == collect(T, 0:15)        # bijective
        # linear: L(x ⊕ y) == L(x) ⊕ L(y)
        for x in 0:7, y in 0:7
            @test L[(x ⊻ y) + 1] == L[x + 1] ⊻ L[y + 1]
        end
        # bucket-preserving
        for x in 0:15
            @test p.bucket_sizes[p.position_of_value[x + 1]] ==
                  p.bucket_sizes[p.position_of_value[L[x + 1] + 1]]
        end
    end
end

@testset "permutation_order: cycle closure" begin
    F = load_literature_sbox("PRESENT")
    N, T = 4, UInt8
    ord = permutation_order(F)
    @test ord ≥ 1
    # F^ord == identity
    cur = copy(F.lut)
    for _ in 2:ord
        cur = T[F.lut[cur[x + 1] + 1] for x in 0:15]
    end
    @test cur == T[T(x) for x in 0:15]
    # identity has order 1
    @test permutation_order(SBox{N, T}(T[T(x) for x in 0:15])) == 1
    # non-permutation throws
    @test_throws ArgumentError permutation_order(
        SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]))
end

end
