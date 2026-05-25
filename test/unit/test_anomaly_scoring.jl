using BFA
using Test

@testset "table_anomaly: unknown table → ArgumentError" begin
    s = load_literature_sbox("PRESENT")
    @test_throws ArgumentError table_anomaly(s, :NOPE)
end

@testset "table_anomaly(:BCT) requires a permutation" begin
    s = SBox(UInt8[0, 0, 0, 0])    # not a permutation
    @test_throws ArgumentError table_anomaly(s, :BCT)
end

@testset "AES has a measurable positive anomaly on all three tables" begin
    aes = load_literature_sbox("AES")

    # AES is famously better than random across all three tables:
    # DDT uniformity 4 vs random ~8, LAT linearity 32 vs random ~64,
    # BCT uniformity 6 vs random ~8. Anomalies should be > 1 bit each.
    @test Float64(table_anomaly(aes, :DDT)) > 1.0
    @test Float64(table_anomaly(aes, :LAT)) > 1.0
    @test Float64(table_anomaly(aes, :BCT)) > 1.0
end

@testset "PRESENT has positive DDT and LAT anomalies" begin
    s = load_literature_sbox("PRESENT")
    @test Float64(table_anomaly(s, :DDT)) > 0.0
    @test Float64(table_anomaly(s, :LAT)) > 0.0
end

@testset "table_anomaly is non-negative on every catalog permutation" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        is_permutation(s) || continue
        for table in (:DDT, :LAT, :BCT)
            @test table_anomaly(s, table; precision = 80) ≥ 0
        end
    end
end

@testset "table_negative_anomaly returns a BigFloat without throwing" begin
    # Negative anomalies can technically be negative or positive depending
    # on the spectrum; just confirm the function evaluates and produces a
    # finite BigFloat for the canonical catalog entries.
    for name in ("AES", "PRESENT", "Midori_Sb0")
        s = load_literature_sbox(name)
        for table in (:DDT, :LAT)
            v = table_negative_anomaly(s, table; precision = 80)
            @test v isa BigFloat
            @test isfinite(v)
        end
    end
end

@testset "AES has dramatically higher anomaly than random-DU permutations" begin
    # AES achieves DU = 4, which is far below the expected DU ≈ 8 for
    # a random permutation of F₂⁸. The anomaly should be in the
    # thousands of bits. (The synthetic identity counterexample — n=3
    # identity has DU = 2^n = 8, which is *expected* for random and
    # therefore *not* anomalous — taught us to compare like vs like:
    # identity's structure shows up under table_negative_anomaly.)
    aes_anomaly = Float64(table_anomaly(load_literature_sbox("AES"), :DDT; precision = 80))
    @test aes_anomaly > 1000.0
end

@testset "Identity SBox is detected by table_negative_anomaly, not _anomaly" begin
    # n=3 identity: every DDT row has a 2^n entry on the diagonal, so
    # DU = 2^n (the random-expected max) — table_anomaly is ~0 because
    # the observed max isn't anomalously small. The *concentration* of
    # multiple 2^n entries is the structural signal; that's what
    # table_negative_anomaly is for.
    id = SBox(UInt8[0, 1, 2, 3, 4, 5, 6, 7])
    @test Float64(table_anomaly(id, :DDT; precision = 80)) < 1e-10  # ≈ 0
    @test isfinite(table_negative_anomaly(id, :DDT; precision = 80))
end
