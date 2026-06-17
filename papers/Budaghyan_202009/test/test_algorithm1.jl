@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # Gold n=5, K=1: domain size < 32 (filtering is non-trivial)
    F = gold_x3(5)
    sz = 32
    for u in [0, 5, 15, 31]
        domain_sizes, _ = algorithm1_filter(F, [u])
        @test domain_sizes[1] < sz
    end

    # If v_i ∈ D_i is necessary for APN G: check that APN shifts lie in domain
    # Use u=3, check all shifts v=1..31
    u = 3
    _, forbidden_sets = algorithm1_filter(F, [u])
    for v = 1:31
        G = apply_modifications(F, [u], [v])
        if differential_uniformity(G) == 2
            # v must be in domain (not in forbidden set)
            @test v ∉ forbidden_sets[1]
        end
    end

    # Gold n=6, K=1: filtering should reduce from 64 options
    F6 = gold_x3(6)
    domain_sizes6, _ = algorithm1_filter(F6, [7])
    @test domain_sizes6[1] < 64
end
