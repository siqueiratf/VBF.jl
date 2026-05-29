@testitem "reconciliation" begin
using VBFCatalog
using VBF
using Test
import DBInterface
import SQLite

# Helper: build a fresh in-memory catalog with a couple of seed functions
# and a handful of reconciliation rows.
function _fresh_recon_db()
    path = tempname() * ".sqlite"
    db = create_catalog(path; bfa_version = "test", git_sha = "deadbeef")
    # one function row so function_id references have something to point at
    SQLite.execute(db, string(
        "INSERT INTO functions ",
        "(family, n, m, lut_sha256, lut_blob, is_apn, is_permutation, is_quadratic, ",
        " source_repo, contributor, added_date) VALUES (",
        "'APN', 4, 4, 'abc', X'00010203', 1, 0, 1, 'bfa@x', 'test', '2026-05-25Z')"))
    db, path
end

@testset "committed reconciliation table reflects upstream imports" begin
    db = load_catalog()
    total = count_reconciliation_disagreements(db)

    # The sboxU import (Phase 4 part 2) dominates the table with its
    # ~21k n=8 APN LUTs; the Xanadu import adds dozens more across
    # n ∈ {6, 7, 8, 9, 10}.
    @test total > 1000

    # All rows are tagged 'only_in_some' (no other kinds populated yet).
    @test count_reconciliation_disagreements(db; kind = "only_in_some") == total

    # All three importers contribute: sboxU dominates by sheer volume,
    # Xanadu adds a small handful, APN-Repository adds the polynomial-form
    # n=8 corpus. Each source is present in at least one row.
    sboxu_rows   = count_reconciliation_disagreements(db; present_in = "sboxu")
    xanadu_rows  = count_reconciliation_disagreements(db; present_in = "xanadu")
    apnrepo_rows = count_reconciliation_disagreements(db; present_in = "apnrepo")
    @test sboxu_rows  > 10_000
    @test xanadu_rows ≥ 1
    @test apnrepo_rows ≥ 1
    # Every row must mention at least one upstream — none should be entirely
    # untagged (that would indicate a bug in record_disagreement! / merge).
    @test sboxu_rows + xanadu_rows + apnrepo_rows ≥ total   # may double-count cross-source rows

    # All rows should be missing from BFA (since BFA's evaluation uses a
    # different primitive polynomial / no polynomial-form support yet
    # for the matched cases — those land in functions.source_repo).
    @test count_reconciliation_disagreements(db; absent_from = "bfa") == total

    # Summary now contains entries for several n.
    summary = reconciliation_summary(db)
    n_values = Set(s.n for s in summary)
    @test 8 in n_values
    @test all(s -> s.kind == "only_in_some", summary)
end

@testset "record_disagreement!: round-trip" begin
    db, path = _fresh_recon_db()
    try
        id = record_disagreement!(db;
            n = 8,
            present_in = "sboxu@828b8ba",
            absent_from = "bfa@x",
            kind = "only_in_some")
        @test id > 0

        rows = list_reconciliation_disagreements(db)
        @test length(rows) == 1
        @test rows[1].n == 8
        @test rows[1].kind == "only_in_some"
        @test rows[1].present_in == "sboxu@828b8ba"
        @test rows[1].absent_from == "bfa@x"
        @test rows[1].resolution === nothing
        @test rows[1].resolver === nothing
        @test rows[1].resolved_date === nothing
    finally
        close(db); rm(path; force = true)
    end
end

@testset "record_disagreement! with resolution metadata" begin
    db, path = _fresh_recon_db()
    try
        record_disagreement!(db;
            n = 6, present_in = "sboxu@x", absent_from = "bfa",
            kind = "only_in_some",
            resolution = "expected: sboxu has more n=6 APNs",
            resolver = "BFA maintainer",
            resolved_date = "2026-05-25Z")
        row = first(list_reconciliation_disagreements(db; resolved = true))
        @test row.resolution !== nothing
        @test row.resolver == "BFA maintainer"
        @test count_reconciliation_disagreements(db; resolved = true) == 1
        @test count_reconciliation_disagreements(db; resolved = false) == 0
    finally
        close(db); rm(path; force = true)
    end
end

@testset "list filters: n, kind, present_in substring" begin
    db, path = _fresh_recon_db()
    try
        record_disagreement!(db; n = 6, present_in = "sboxu@x", absent_from = "bfa",
                             kind = "only_in_some")
        record_disagreement!(db; n = 8, present_in = "sboxu@x|xanadu@y",
                             absent_from = "bfa", kind = "only_in_some")
        record_disagreement!(db; n = 8, present_in = "xanadu@y", absent_from = "bfa|sboxu@x",
                             kind = "only_in_some")

        @test count_reconciliation_disagreements(db) == 3
        @test count_reconciliation_disagreements(db; n = 6) == 1
        @test count_reconciliation_disagreements(db; n = 8) == 2
        @test count_reconciliation_disagreements(db; present_in = "sboxu") == 2
        @test count_reconciliation_disagreements(db; present_in = "xanadu") == 2
        @test count_reconciliation_disagreements(db; absent_from = "sboxu") == 1
    finally
        close(db); rm(path; force = true)
    end
end

@testset "reconciliation_summary: groups by (n, kind)" begin
    db, path = _fresh_recon_db()
    try
        record_disagreement!(db; n = 6, present_in = "a", absent_from = "b",
                             kind = "only_in_some")
        record_disagreement!(db; n = 8, present_in = "a", absent_from = "b",
                             kind = "only_in_some")
        record_disagreement!(db; n = 8, present_in = "a", absent_from = "b",
                             kind = "only_in_some")
        record_disagreement!(db; n = 8, present_in = "a", absent_from = "b",
                             kind = "differential_uniformity_disagree")
        summary = reconciliation_summary(db)
        @test (n = 6, kind = "only_in_some", count = 1) in summary
        @test (n = 8, kind = "only_in_some", count = 2) in summary
        @test (n = 8, kind = "differential_uniformity_disagree", count = 1) in summary
    finally
        close(db); rm(path; force = true)
    end
end

@testset "merge_source_repo!: appends and dedupes" begin
    db, path = _fresh_recon_db()
    try
        fid = 0
        for r in DBInterface.execute(db, "SELECT id FROM functions LIMIT 1")
            fid = Int(r.id)
        end

        # initial state from the test seed
        cur = ""
        for r in DBInterface.execute(db, "SELECT source_repo FROM functions WHERE id = $fid")
            cur = String(r.source_repo)
        end
        @test cur == "bfa@x"

        # appending a new source
        new = merge_source_repo!(db, fid, "sboxu@828b8ba")
        @test new == "bfa@x|sboxu@828b8ba"

        # already present → no-op
        same = merge_source_repo!(db, fid, "sboxu@828b8ba")
        @test same == "bfa@x|sboxu@828b8ba"
    finally
        close(db); rm(path; force = true)
    end
end

@testset "reconciliation_by_source / functions_by_source totals" begin
    db = load_catalog()
    rs = reconciliation_by_source(db)
    @test Set(r.source for r in rs) == Set(["bfa", "sboxu", "xanadu", "apnrepo"])

    by = Dict(r.source => r.count for r in rs)
    @test by["sboxu"]   > 10_000
    @test by["apnrepo"] > 10_000
    @test by["xanadu"]  ≥ 1
    # no reconciliation row should be tagged 'bfa' in present_in (those
    # land in functions.source_repo instead).
    @test by["bfa"] == 0

    fs = Dict(r.source => r.count for r in functions_by_source(db))
    @test fs["bfa"] > 0                # every catalog row is tagged bfa
    @test fs["xanadu"]  ≥ 1            # at least the 10 xanadu cross-matches
    @test fs["apnrepo"] ≥ 1            # at least the 12 apnrepo cross-matches
end

@testset "cross_source_matches reflects upstream agreements" begin
    db = load_catalog()
    pairs = cross_source_matches(db; min_sources = 2)
    @test !isempty(pairs)
    # Strongest matches first: sources_count is monotone-decreasing.
    @test issorted([-p.sources_count for p in pairs])

    # Every row really does mention ≥ 2 distinct sources.
    for p in pairs
        sources = unique([split(s, '@')[1] for s in split(p.present_in, '|')])
        @test length(sources) ≥ 2
        @test p.sources_count == length(sources)
    end
end

@testset "multi_source_functions reflects in-catalog cross-matches" begin
    db = load_catalog()
    ms = multi_source_functions(db; min_sources = 2)
    @test !isempty(ms)
    for row in ms
        sources = unique([split(s, '@')[1] for s in split(row.source_repo, '|')])
        @test "bfa" in sources    # in-catalog matches always include BFA
        @test row.sources_count == length(sources)
    end
end

end
