include(joinpath(@__DIR__, "..", "theorem6.jl"))
@testset "missing reference is inconclusive" begin
    rows = theorem6_run(; index_path = joinpath(mktempdir(), "absent.sqlite"))
    @test length(rows) == 4
    @test all(ismissing(r.in_beierle2025) && ismissing(r.in_bbl_file) && ismissing(r.in_edelpott) for r in rows)
    @test all(c.status == :inconclusive for c in values(first(rows).coverage))
    io = IOBuffer()
    theorem6_report(io; index_path = joinpath(mktempdir(), "absent.sqlite"))
    @test occursin("inconclusive", String(take!(io)))
end

@testset "named-source completeness checks all member indices" begin
    path = joinpath(mktempdir(), "small_reference_index.sqlite")
    idx = VBFCatalog.SQLite.DB(path)
    cat = VBFCatalog.SQLite.DB(VBFCatalog.catalog_path())
    try
        VBFCatalog.SQLite.execute(idx, "CREATE TABLE sigma_coverage (source TEXT, n INTEGER, indexed INTEGER)")
        VBFCatalog.SQLite.execute(idx, "CREATE TABLE ccz_sigma_index (sigma_hash TEXT, n INTEGER, source TEXT, member_idx INTEGER)")
        DBI.execute(idx, "INSERT INTO sigma_coverage VALUES (?,8,1)", (DB_EDELPOTT,))
        expected = VBFCatalog.corpus_length(cat, DB_EDELPOTT)
        for i in 1:expected
            F = VBFCatalog.corpus_function(cat, DB_EDELPOTT, i)
            DBI.execute(idx, "INSERT INTO ccz_sigma_index VALUES (?,8,?,?)", (VBFCatalog.sigma_hash(F), DB_EDELPOTT, i))
        end
        @test source_coverage(idx, cat, DB_EDELPOTT).status == :covered
        rows = theorem6_run(; index_path = path)
        @test all(r.in_edelpott === true for r in rows)
        @test all(ismissing(r.in_beierle2025) for r in rows)
        DBI.execute(idx, "DELETE FROM ccz_sigma_index WHERE member_idx = ?", (expected,))
        @test source_coverage(idx, cat, DB_EDELPOTT).status == :inconclusive
        @test all(ismissing(r.in_edelpott) for r in theorem6_run(; index_path = path))
    finally
        VBFCatalog.SQLite.close(idx)
        VBFCatalog.SQLite.close(cat)
    end
end
