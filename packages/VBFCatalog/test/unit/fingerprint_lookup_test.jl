@testitem "fingerprint_lookup" begin
    using VBF, VBFCatalog, SQLite, DBInterface, Test

    F = dillon_apn_permutation()
    G = kim_apn()
    # Distinct LUTs can be CCZ-equivalent; the query only reports the fingerprint.
    @test F.lut != G.lut
    @test ccz_fingerprint_hash(F) == ccz_fingerprint_hash(G)
    idx = SQLite.DB()
    try
        DBInterface.execute(idx, "CREATE TABLE ccz_fingerprint_index(fp_hash TEXT, source TEXT, member_idx INTEGER)")
        DBInterface.execute(idx, "INSERT INTO ccz_fingerprint_index VALUES(?, 'functions', 17)",
            (ccz_fingerprint_hash(F),))
        @test classify_ccz_fingerprint(G; index=idx) == (:fingerprint_match, "functions", 17)
        @test !is_novel_fingerprint(G; index=idx)
        @test classify_ccz_fingerprint(gold_apn(5, 1); index=idx) == (:new, nothing, nothing)
        @test is_novel_fingerprint(gold_apn(5, 1); index=idx)
        # An explicit index remains caller-owned and usable after the query.
        @test only([Int(r.c) for r in DBInterface.execute(idx, "SELECT COUNT(*) c FROM ccz_fingerprint_index")]) == 1
    finally
        SQLite.close(idx)
    end
end
