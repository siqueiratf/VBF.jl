@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    r = theorem4_run()

    for res in r.results
        @test res.n   == 256
        @test res.du  == 2
        @test res.deg == 2
    end

    # Non-permutation: classes A-D should not be permutations
    for res in r.results[1:4]
        @test !res.perm
    end

    # V_A membership per Theorem 4
    name_to_va = Dict(
        :class_a => true, :class_b => false,
        :class_c => false, :class_d => false,
        :class_e => true,  :class_f => true,
    )
    for res in r.results
        @test res.va == name_to_va[res.name]
    end
end
