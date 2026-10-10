@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))

    # Test all 4 rows (sn=4, 6, 8, 8)
    for (s, n, exp_nl, exp_ds, _) in TABLE1_EXPECTED
        r = table1_compute(s, n)
        @test r.nl == exp_nl
        @test r.du == 4
        @test r.deg == r.N - 1
        ds_dict = Dict(v => c for (v, c) in sorted_pairs(r.ds))
        @test ds_dict == exp_ds
    end
end
