@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    # For n=6: U_max has 14 elements (paper states this explicitly)
    u_max = build_u_max(6)
    @test length(u_max) == 14

    # 7 pairs -> 2^7-1 = 127 non-empty valid U sets
    pairs = u_max_pairs(u_max)
    @test length(pairs) == 7

    # Exactly 22 distinct (nl, D0, D2, D4) fingerprints
    classes = table3_classes(; n = 6)
    @test length(classes) == 22

    # Each fingerprint: D0+D2+D4 = (2^6-1)*2^6 = 4032 (all DDT entries with a!=0)
    for c in classes
        @test c.d0 + c.d2 + c.d4 == (2^6 - 1) * 2^6
    end

    # Total U-sets across all classes = 127
    @test sum(c.u_set_count for c in classes) == 127
end
