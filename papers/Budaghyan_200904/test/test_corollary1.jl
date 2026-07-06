@testset "corollary1_test" begin
    include(joinpath(@__DIR__, "..", "corollary1.jl"))

    # Small budget: n up to 6 (report does 3:8).
    r = corollary1_report(devnull; n_max = 6)
    @test r.all_apn                 # APN for every n in range
    @test r.all_deg2                # algebraic degree 2 for every n
    @test all(row.du == 2 for row in r.rows)
end
