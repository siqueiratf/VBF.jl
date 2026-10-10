@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    include(joinpath(@__DIR__, "..", "table1.jl"))

    # Fast test: limit=3 per dimension, n=5 and n=6 only
    r = table1_report(; ns = [5, 6], limit = 3, io = devnull)
    @test r.all_ok
    @test length(r.all_rows) > 0
    # Every row has non-negative S1, S2 and fails the Theorem 17 condition
    for row in r.all_rows
        @test row.s1 >= 0
        @test row.s2 >= 0
        @test row.condition_fails
    end

    # README R4: with Observation 7's input map A₂ in place, the S1 ≠ S2 asymmetry
    # that defines the paper's Table 1 ("the two values may differ in the general
    # case") is finally reachable. Without A₂ every representative gave S1 == S2.
    @test r.n_reps > length(r.all_rows)
    @test r.n_asym > 0

    # README R3: no function is discarded. n=6 has one catalog APN with F(0)=F(1);
    # it is normalised at its first genuine pair instead of being skipped.
    r6 = table1_report(; ns = [6], rep_samples = 0, io = devnull)
    @test length(r6.all_rows) == length(load_catalog_apn_for_n(6))
    @test all(row -> row.condition_fails, r6.all_rows)
    degenerate = filter(row -> (row.u1, row.u2) != (0, 1), r6.all_rows)
    @test length(degenerate) == 1                       # the F(0)=F(1) one
    @test all(row -> row.s1 + row.s2 > 12, r6.all_rows) # Observation 18's premise

    # Normalize is idempotent: power functions unchanged; normalize(normalize(F)) == normalize(F)
    using VBFCatalog
    s = load_apn_function("n5_Gold_x3")
    sn = normalize_apn(s)
    @test normalize_apn(sn).lut == sn.lut
end
