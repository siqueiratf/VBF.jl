@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    include(joinpath(@__DIR__, "..", "table1.jl"))

    # Fast test: limit=3 per dimension, n=5 and n=6 only
    r = table1_report(; ns = [5, 6], limit = 3, io = devnull)
    @test r.all_ok
    @test length(r.all_rows) > 0
    # Every row has non-negative S1, S2
    for row in r.all_rows
        @test row.s1 >= 0
        @test row.s2 >= 0
        @test row.condition_fails
    end

    # Normalize is idempotent: power functions unchanged; normalize(normalize(F)) == normalize(F)
    using VBFCatalog
    s = load_apn_function("n5_Gold_x3")
    sn = normalize_apn(s)
    @test normalize_apn(sn).lut == sn.lut
end
