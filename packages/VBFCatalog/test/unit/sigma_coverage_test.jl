@testitem "sigma_coverage" begin
using VBF
using VBFCatalog
using SQLite
using Test

# A σ-ABSENCE certifies novelty only against the functions that were actually
# indexed, so an index built WITHOUT the n=8 corpora must refuse an n=8 lookup
# rather than answer `:new` — a partial index that answers silently is how a
# known function reads as new. The index is built in memory here: the real side
# store is a 682 MB artefact a test must never rebuild.
function coverage_index(; corpora_indexed::Bool)
    idx = SQLite.DB()
    SQLite.execute(idx, "CREATE TABLE ccz_sigma_index (sigma_hash TEXT NOT NULL, " *
                        "n INTEGER NOT NULL, source TEXT NOT NULL, member_idx INTEGER)")
    SQLite.execute(idx, "CREATE TABLE sigma_coverage (source TEXT NOT NULL, " *
                        "n INTEGER NOT NULL, indexed INTEGER NOT NULL)")
    SQLite.execute(idx, "INSERT INTO sigma_coverage VALUES ('functions', -1, 1)")
    SQLite.execute(idx, "INSERT INTO sigma_coverage VALUES ('a_corpus_n8', 8, " *
                        string(Int(corpora_indexed)) * ")")
    idx
end

@testset "an unindexed source refuses only its own dimension" begin
    idx = coverage_index(corpora_indexed = false)
    # the skipped corpus is n=8, so n=7 and n=9 are as complete as a full build
    @test classify_ccz(gold_apn(7, 1); index = idx)[1] === :new
    @test classify_ccz(gold_apn(9, 1); index = idx)[1] === :new
    # n=8 has an unindexed source: refuse rather than certify a false :new
    @test_throws ErrorException classify_ccz(gold_apn(8, 1); index = idx)
    @test_throws ErrorException is_novel(gold_apn(8, 1); index = idx)
end

@testset "full coverage answers at every dimension" begin
    idx = coverage_index(corpora_indexed = true)
    @test classify_ccz(gold_apn(8, 1); index = idx)[1] === :new
    @test is_novel(gold_apn(8, 1); index = idx)
end

@testset "a corpus registered since the last index build is a gap" begin
    idx = coverage_index(corpora_indexed = true)
    # A catalog that knows an n=8 corpus the index has never heard of. Without
    # the cross-check this reads as full coverage, and every member of that
    # corpus comes back `:new`.
    cat = SQLite.DB()
    SQLite.execute(cat, "CREATE TABLE bulk_corpora (name TEXT, n INTEGER, m INTEGER, " *
                        "member_count INTEGER, degree INTEGER, modulus INTEGER, " *
                        "encoding TEXT, bytes_per_member INTEGER, store_file TEXT, " *
                        "store_sha256 TEXT, family TEXT, bib_key TEXT, source_repo TEXT, " *
                        "contributor TEXT, added_date TEXT, notes TEXT)")
    SQLite.execute(cat, "INSERT INTO bulk_corpora (name, n, m, member_count, modulus) " *
                        "VALUES ('a_later_corpus_n8', 8, 8, 10, 285)")
    @test_throws ErrorException classify_ccz(gold_apn(8, 1); index = idx, catalog = cat)
    @test_throws ErrorException is_novel(gold_apn(8, 1); index = idx, catalog = cat)
    # an n=8 corpus says nothing about n=7
    @test classify_ccz(gold_apn(7, 1); index = idx, catalog = cat)[1] === :new
    # once the index records it, the dimension answers again
    SQLite.execute(idx, "INSERT INTO sigma_coverage VALUES ('a_later_corpus_n8', 8, 1)")
    @test classify_ccz(gold_apn(8, 1); index = idx, catalog = cat)[1] === :new
end

@testset "an explicit index with no catalog is taken as the whole world" begin
    # `index` alone must not reach for the real catalog: that is how every other
    # test here builds a world in memory.
    idx = coverage_index(corpora_indexed = true)
    @test classify_ccz(gold_apn(8, 1); index = idx)[1] === :new
end

@testset "an index without coverage evidence cannot establish absence" begin
    idx = SQLite.DB()
    SQLite.execute(idx, "CREATE TABLE ccz_sigma_index (sigma_hash TEXT NOT NULL, " *
                        "n INTEGER NOT NULL, source TEXT NOT NULL, member_idx INTEGER)")
    @test_throws ErrorException classify_ccz(gold_apn(8, 1); index = idx)
    @test_throws ErrorException is_novel(gold_apn(8, 1); index = idx)
end

@testset "a covered dimension still reports :sigma_match" begin
    idx = coverage_index(corpora_indexed = true)
    F = gold_apn(7, 1)
    SQLite.execute(idx, "INSERT INTO ccz_sigma_index VALUES ('" * sigma_hash(F) *
                        "', 7, 'functions', 1)")
    st, src, _ = classify_ccz(F; index = idx)
    @test st === :sigma_match
    @test src == "functions"
end
end
