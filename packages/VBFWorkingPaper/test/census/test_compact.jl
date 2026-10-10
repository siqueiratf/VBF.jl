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
    # A hits file that disagrees with its manifest is an error.
    open(hits_path(man), "a") do io
        println(io, "c12.tsv\t12\t200\t1.0\t8\t", "00"^15)
    end
    @test_throws ErrorException read_samples([man])

end
