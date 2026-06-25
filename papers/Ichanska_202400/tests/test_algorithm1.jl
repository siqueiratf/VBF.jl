@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # n=4, m=2: verify orbit partition is exhaustive
    classes4, reps4, perms4 = demo_algorithm1_n4_m2()
    @test sum(length(c) for c in classes4) == 15  # all 15 non-zero elements
    @test length(reps4) == length(classes4)        # one rep per class

    # Orbits are disjoint
    all_elems = vcat([collect(c) for c in classes4]...)
    @test length(Set(all_elems)) == 15

    # n=8, m=2: exactly 4 orbits with representatives {1, a, a^7, a^17}
    ok, reps8, reps_match, _ = verify_n8_m2_first_level()
    @test ok
    @test reps_match

    # equivset returns min-dlog representative for each orbit
    n = 4; mod_n = conway_polynomial(n)
    function _dlog4(x)
        d = Dict{Int,Int}(); c = 1
        for k in 0:(1<<n)-2; d[c] = k; c = gf_mul(c, 2, n; modulus=mod_n); end
        d[x]
    end
    reps4_set = Set(reps4)
    for cls in classes4
        min_elem = argmin(_dlog4, collect(cls))
        @test min_elem ∈ reps4_set
    end
end
