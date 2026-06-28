@testset "table2_test" begin
    include(joinpath(@__DIR__, "..", "table2.jl"))

    r = table2_run()

    @test r.all_distinct
    @test r.e_eq_gold3
    @test r.f_eq_gold9

    # Sanity: each σ is a pair of non-empty spectrum representations
    for (_, sig) in r.sigs
        @test !isempty(sig[1])   # diff-spectrum pairs non-empty
        @test !isempty(sig[2])   # Walsh-spectrum pairs non-empty
    end
end
