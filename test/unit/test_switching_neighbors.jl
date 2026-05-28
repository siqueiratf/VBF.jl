using BFA
using Test

@testset "switching_neighbors: every neighbour is APN and of switching form" begin
    for name in ("n4_Gold_x3", "n5_Gold_x3")
        F = load_apn_function(name)
        sn = switching_neighbors(F)
        @test length(sn) == (1 << inputbits(F)) - 1
        total = 0
        for u in eachindex(sn)        # u is the field element (1-based == value)
            for G in sn[u]
                total += 1
                # APN
                @test differential_uniformity(G) ≤ 2
                # genuine u-switching neighbour: G ⊕ F takes values in {0, u}
                @test all((G.lut[x + 1] ⊻ F.lut[x + 1]) ∈ (0, u) for x in 0:length(F) - 1)
                # non-trivial: actually differs from F
                @test G != F
            end
        end
        @test total > 0
    end
end

@testset "switching_neighbors: deterministic" begin
    F = load_apn_function("n4_Gold_x3")
    a = switching_neighbors(F)
    b = switching_neighbors(F)
    @test length.(a) == length.(b)
    @test all(a[u] == b[u] for u in eachindex(a))
end

@testset "switching_neighbors: rejects non-APN input" begin
    @test_throws ArgumentError switching_neighbors(load_literature_sbox("PRESENT"))  # DU = 4
end

@testset "switching_neighbors: neighbours are distinct within each u" begin
    F = load_apn_function("n4_Gold_x3")
    sn = switching_neighbors(F)
    for u in eachindex(sn)
        luts = [G.lut for G in sn[u]]
        @test length(luts) == length(unique(luts))
    end
end
