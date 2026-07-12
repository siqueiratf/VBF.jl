@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))

    F = gold_x3(5)

    # K=1: single point modification — sample check
    for (u, v) in [(3, 1), (7, 2), (0, 5), (15, 3), (31, 1), (10, 7)]
        G = apply_modifications(F, [u], [v])
        cond = check_apn_conditions(F, [u], [v])
        direct = differential_uniformity(G) == 2
        @test cond == direct
    end

    # K=2: two-point modification — sample check
    seeds = [(3, 7, 1, 2), (0, 15, 3, 5), (5, 10, 7, 1), (1, 30, 2, 4)]
    for (u1, u2, v1, v2) in seeds
        u1 == u2 && continue
        G = apply_modifications(F, [u1, u2], [v1, v2])
        cond = check_apn_conditions(F, [u1, u2], [v1, v2])
        direct = differential_uniformity(G) == 2
        @test cond == direct
    end

    # K=1 with APN F known: any v ∈ domain should give valid G (not always APN)
    # Check that conditions match direct test on all 31 nonzero shifts for u=5
    u = 5
    for v = 1:31
        G = apply_modifications(F, [u], [v])
        cond = check_apn_conditions(F, [u], [v])
        direct = differential_uniformity(G) == 2
        @test cond == direct
    end
end
