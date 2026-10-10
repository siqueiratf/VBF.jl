# Compact sample data (data/): lossless round trip, committed legacy files, verification.
@testset "compact sample data" begin
    dir = mktempdir()
    f1 = write_chunk(joinpath(dir, "c11.tsv"), sample_chunk(300, 11; n = 6, m = 6, streams = 3))
    f2 = write_chunk(joinpath(dir, "c12.tsv"), sample_chunk(200, 12; n = 6, m = 6, streams = 3))
    man = compact_samples([("c11.tsv", f1, 11), ("c12.tsv", f2, 12)],
                          joinpath(dir, "test_chunks.tsv"); io = devnull)
    @test is_manifest(man)
    @test !is_manifest(f1)
    @test isfile(hits_path(man))
    lw1, h1 = read_samples([f1, f2])
    lw2, h2 = read_samples([man])
    @test isequal(lw1, lw2)                       # bit for bit, -Inf rows included
    @test h1 == h2
    @test mass_estimate(lw1, 6, 6) == mass_estimate(lw2, 6, 6)
    @test sample_labels([man]) == ["c11.tsv", "c12.tsv"]
    rows = read_manifest(man)
    @test sum(r.samples for r in rows) == 500
    @test all(r.zero_e + r.hits == r.samples for r in rows)
    # Mixed input: manifest + full file.
    lw3, h3 = read_samples([man, f1])
    @test length(lw3) == 800 && length(h3) == length(h1) + count(isfinite, lw1[1:300])
    # Verification of a regenerated chunk.
    g = write_chunk(joinpath(dir, "regen", "c12.tsv"), sample_chunk(200, 12; n = 6, m = 6, streams = 3))
    @test verify_sample_file(g, man; seed = 12, io = devnull)
    g2 = write_chunk(joinpath(dir, "regen2", "c12.tsv"), sample_chunk(200, 12; n = 6, m = 6, streams = 2))
    @test !verify_sample_file(g2, man; seed = 12, io = devnull)
    # A hits file that disagrees with its manifest is an error.
    open(hits_path(man), "a") do io
        println(io, "c12.tsv\t12\t200\t1.0\t8\t", "00"^15)
    end
    @test_throws ErrorException read_samples([man])

    # Committed legacy data: 41 files, 4,012,000 samples, 1,661 hits.
    leg = joinpath(DATA_DIR, "legacy_chunks.tsv")
    rows = read_manifest(leg)
    @test length(rows) == 41
    @test sum(r.samples for r in rows) == 4_012_000
    @test sum(r.hits for r in rows) == 1661
    @test countlines(hits_path(leg)) == 1661
    lw, hits = read_samples([leg])
    @test length(lw) == PUBLISHED.samples
    @test length(hits) == PUBLISHED.hits
    @test round(mass_estimate(lw, 8, 8).mass, sigdigits = 4) == PUBLISHED.mass
    s77 = read_manifest(joinpath(DATA_DIR, "legacy_s77_chunks.tsv"))
    @test only(s77).samples == 200_000 && only(s77).seed == 7
end
