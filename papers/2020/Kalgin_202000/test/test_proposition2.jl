@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))

    # Round-trip: is_qam on Gold QAM returns true
    g3 = gold_apn(3)
    M3 = quadratic_apn_matrix(g3)
    @test is_qam(M3)

    # Extended QAM with all-zero alpha is NOT always APN (but some alpha work)
    n = 3
    M_base = quadratic_apn_matrix(g3)
    M_extra = zero_extra_qam(n)
    alpha_zero = zeros(Int, n)
    Q_zero = build_extended_qam(M_base, M_extra, alpha_zero, n)
    # is_qam(Q_zero) could be true or false — just check it runs
    @test Q_zero isa Matrix{Int}
    @test size(Q_zero) == (n + 1, n + 1)

    # Section 3 search: n=3 Gold → n=4 extensions exist
    fns = section3_search(g3, M_extra; limit = 50)
    @test length(fns) >= 1
    for f in fns
        @test differential_uniformity(f) == 2
        @test algebraic_degree(f) == 2
    end

    # Dedup: distinct CCZ-classes
    deduped = dedup_ea(fns)
    @test length(deduped) >= 1

    # Different g_{n+1} choices give different (possibly overlapping) CCZ-class sets.
    # Paper §3: getting ALL CCZ-classes requires scanning all g_{n+1} choices.
    all_null = dedup_ea(section3_search(g3, M_extra; limit = 2000))
    @test length(all_null) >= 1

    M_extra_q = allquad_extra_qam(n)
    all_allq = dedup_ea(section3_search(g3, M_extra_q; limit = 2000))
    @test length(all_allq) >= 1
end
