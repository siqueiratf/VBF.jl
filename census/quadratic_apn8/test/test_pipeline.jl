# Sampler pipeline: (5,5) mass, coefficient strings, APN leaves, TSV semantics.
@testset "pipeline (5,5) mass" begin
    lines = sample_chunk(2000, 5; n = 5, m = 5)
    path = write_chunk(joinpath(mktempdir(), "c5.tsv"), lines)
    lw, hits = read_samples([path])
    r = mass_estimate(lw, 5, 5)
    # Two classes (Gold x^3, x^5), |Stab| = 31 * 5 = 155 each.
    @test EXACT_MASS[(5, 5)] == 2 // 155
    @test abs(r.mass - 2 / 155) <= 5r.se
    @test abs(r.mass - 2 / 155) / (2 / 155) < 0.05
    @test r.samples == 2000
    @test length(hits) == r.hits
end

@testset "coefficient strings and LUT" begin
    rng = Xoshiro(7)
    for n in 3:8
        C = zeros(UInt16, n, n)
        for a in 1:n, b in a + 1:n
            C[a, b] = C[b, a] = rand(rng, UInt16(0):UInt16((1 << n) - 1))
        end
        s = encode_coeffs(C, n)
        @test length(s) == n * (n - 1)
        @test decode_coeffs(s, n) == C
        lut = QK.lut(C, n)
        @test lut[1] == 0
        # Quadratic form: F(x+y) + F(x) + F(y) = B(x,y); check on unit vectors.
        for i in 1:n, j in i + 1:n
            @test lut[(1 << (i - 1)) + (1 << (j - 1)) + 1] == C[i, j]
        end
        @test sbox_from_coeffs(s, n) == SBox{n}(UInt8.(lut))
    end
    @test_throws ArgumentError decode_coeffs("abc", 8)
end

@testset "sampled leaves are APN; TSV rows" begin
    for (n, m, N) in [(6, 6, 300), (7, 7, 200)]
        lines = sample_chunk(N, 99; n, m)
        path = write_chunk(joinpath(mktempdir(), "c99.tsv"), lines)
        @test countlines(path) == N
        lw, hits = read_samples([path])
        @test length(lw) == N                      # -Inf / e = 0 rows stay in the denominator
        @test !isempty(hits)
        for (k, line) in enumerate(lines)
            p = split(line, '\t')
            @test length(p) == 4
            @test parse(Int, p[1]) == k
            e = parse(Int, p[3])
            @test (e == 0) == isempty(p[4])
            p[2] == "-Inf" && @test e == 0
        end
        for (t, coeffs) in first(hits, 10)
            F = sbox_from_coeffs(coeffs, n)
            @test differential_uniformity(F) == 2
            @test is_quadratic_apn(F)
            # Recount e from the (n-1)-variable restriction.
            C = decode_coeffs(coeffs, n)
            e = parse(Int, split(lines[t], '\t')[3])
            @test FL3.count_completions(C[1:n - 1, 1:n - 1], n - 1, m)[1] == e
        end
    end
end
