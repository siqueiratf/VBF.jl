@testset "exhaustive source comparison" begin
    mktempdir() do dir
        sources = joinpath(dir, "sources"); mkpath(sources)
        path = joinpath(sources, "fixture.txt")
        f = UInt8.(polynomial_to_lut("X^3", 8, conway_polynomial(8)))
        h = VBF.sigma_hash(SBox{8}(f))
        open(io -> println(io, "[", join(f, ','), "]"), path, "w")
        open(io -> TOML.print(io, Dict("files"=>Dict("fixture.txt"=>Dict("sha256"=>filehash(path))))),
            joinpath(sources, "provenance.toml"), "w")
        original = (; name="raw_fixture", kind=:stream, paths=[path], expected=1,
                    corpus="fixture", modulus=0, url="fixture", descriptor_sha="")
        stored = (; original..., name="stored_fixture")
        rebuild(stored, dir); rebuild(original, dir)
        oldpath = joinpath(dir, "old.sqlite")
        db = SQL.DB(oldpath)
        try
            SQL.execute(db, "CREATE TABLE ccz_sigma_index(sigma_hash TEXT,n INTEGER,source TEXT,member_idx INTEGER)")
            DBI.execute(db, "INSERT INTO ccz_sigma_index VALUES(?,8,'fixture',1)", ("0"^64,))
        finally
            close(db)
        end
        report = compare(dir; stored=[stored], raw=[original], old_index_path=oldpath)
        @test report["provenance_complete"]
        @test report["stored_original_lut_sets_match"]
        @test !report["old_index_exact_rows_match"]
        @test report["sources"]["stored_fixture"]["missing_or_changed_index_rows"] == 1
        @test report["sources"]["stored_fixture"]["orphan_or_changed_index_rows"] == 1
        @test report["fresh_union_distinct_signatures"] == 1
        db = SQL.DB(joinpath(dir, "raw_fixture.sqlite"))
        try
            SQL.execute(db, "UPDATE metadata SET value='false' WHERE key='complete'")
        finally
            close(db)
        end
        @test_throws ErrorException compare(dir; stored=[stored], raw=[original], old_index_path=oldpath)
        @test filehash(joinpath(dir, "fresh_union.sqlite")) == report["fresh_union_sha256"]
    end
end
