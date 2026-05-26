using BFA
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

@testset "committed reconciliation table reflects sboxU import" begin
    # After the Phase-4 import, the committed catalog carries thousands
    # of reconciliation rows: every n=8 APN in sboxU that does NOT share
    # a LUT-SHA with BFA (which is all of them, because sboxU uses a
    # different primitive polynomial / field representation).
    db = load_catalog()
    total = count_reconciliation_disagreements(db)
    @test total > 1000

    # Every row should be "only_in_some" and tagged with an sboxu source.
    @test count_reconciliation_disagreements(db; kind = "only_in_some") == total
    @test count_reconciliation_disagreements(db; present_in = "sboxu") == total
    @test count_reconciliation_disagreements(db; absent_from = "bfa") == total

    # Summary should expose a single (n=8, "only_in_some") row totalling everything.
    summary = reconciliation_summary(db)
    @test length(summary) == 1
    @test summary[1].n == 8
    @test summary[1].kind == "only_in_some"
    @test summary[1].count == total
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
