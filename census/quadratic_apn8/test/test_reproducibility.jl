# RNG scheme: sample i uses Xoshiro(seed * 100003 + th), th = ((i-1) mod T) + 1,
# T = number of RNG streams (default: number of threads).
@testset "reproducibility" begin
    a = sample_chunk(60, 3; n = 6, m = 6)
    b = sample_chunk(60, 3; n = 6, m = 6)
    @test a == b
    # One stream equals the corresponding lines of a T-thread chunk.
    T = 4
    res = fill("", 60)
    for th in 1:T
        sample_stream!(res, 3, th, T, 6, 6)
    end
    if nthreads() == T
        @test res == a
    end
    @test all(!isempty, res)
    # T streams on any number of threads give the same chunk.
    @test sample_chunk(60, 3; n = 6, m = 6, streams = T) == res
    @test sample_chunk(60, 3; n = 6, m = 6, streams = 1) != res

    # Committed compact data: thread 2 of 12, seed 1 reaches the s1.tsv hit at line 2810
    # (about 20 s). Works in a fresh clone.
    hp = joinpath(DATA_DIR, "legacy_hits.tsv")
    @test isfile(hp)
    h1 = read_hit_rows(hp)["s1.tsv"]
    x = only(filter(r -> r.i == 2810, h1))
    r2 = fill("", 2810)
    sample_stream!(r2, 1, 2, 12, 8, 8)
    @test r2[2810] == join((x.i, x.logw, x.e, x.coeffs), '\t')

    ref = joinpath(LEGACY_DIR, "s1.tsv")
    if isfile(ref)
        lines = readlines(ref)
        # Thread 1 of 12, seed 1: lines 1, 13, 25, 37, 49.
        r1 = fill("", 49)
        sample_stream!(r1, 1, 1, 12, 8, 8)
        @test all(r1[i] == lines[i] for i in 1:12:49)
        @test r2[2810] == lines[2810]
    else
        @info "legacy s1.tsv not found; skipping byte-level reproduction test" ref
    end
end
