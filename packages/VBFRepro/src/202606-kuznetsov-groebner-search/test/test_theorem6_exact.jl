include(joinpath(@__DIR__, "..", "theorem6_exact.jl"))
@testset "Theorem 6 exact EA witnesses" begin
    rows = theorem6_exact_run()
    @test length(rows) == 4
    @test [r.nm for r in rows] == [:class_a, :class_b, :class_c, :class_d]
    @test [r.member for r in rows] == [18, 5, 3, 4]
    for r in rows
        @test r.equivalent === true
        @test r.status == :verified_witness
    end
    # A corrupted graph map cannot support the same conclusion.
    row = TOML.parsefile(EXACT_WITNESSES)["class_a"]
    bad = copy(row["columns"]); bad[1] = bad[2]
    @test !GraphWitnesses.verify_ea_witness(row["candidate_lut"], row["reference_lut"], bad, row["constant"])
    undecided = theorem6_exact_run(; recover = true, timeout_seconds = 0)
    @test all(ismissing(r.equivalent) && r.status == :inconclusive for r in undecided)
    recovered = theorem6_exact_run(; recover = true, timeout_seconds = 10)
    @test all(r.equivalent === true && r.status == :verified_witness for r in recovered)
end
