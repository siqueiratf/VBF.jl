using VBF
using Test

# The curated quadratic-APN CCZ-class representatives imported from
# sboxU's apnDB (reprs6/7/8 + eightBitAPN) land in the catalog under the
# `APN-rep` family. These tests are written relationally (derived from the
# catalog) so they don't desync when the upstream rep lists change; the
# absolute count is pinned in `test_catalog_content.jl`.

@testset "APN-rep family: present and well-formed" begin
    db = load_catalog()
    reps = list_functions(db; family = "APN-rep")
    @test !isempty(reps)
    # every representative row records APN + n ∈ {6,7,8}
    @test all(r.is_apn == 1 || r.is_apn == true for r in reps)
    @test all(r.differential_uniformity == 2 for r in reps)
    @test all(r.n in (6, 7, 8) for r in reps)
    # all three dimensions are represented
    @test Set(r.n for r in reps) == Set((6, 7, 8))
end

@testset "APN-rep rows round-trip and recompute their stats" begin
    db = load_catalog()
    reps = list_functions(db; family = "APN-rep")
    # spot-check a sample across dimensions (recomputing stats for all
    # ~500 would be slow; sample deterministically)
    sample = reps[1:max(1, length(reps) ÷ 50):end]
    for r in sample
        s = load_sbox(db, r.id)
        @test inputbits(s) == r.n
        @test differential_uniformity(s) == 2
        @test differential_uniformity(s) == r.differential_uniformity
        @test algebraic_degree(s) == r.algebraic_degree
        @test (Int(is_permutation(s))) == r.is_permutation
    end
end

@testset "APN-rep: first reprs6 representative is the Gold function x³" begin
    db = load_catalog()
    # reprs6_0 == get_sbox(X**3) over GF(2^6)
    row = find_function(db; canonical_name = "reprs6_0")
    @test row !== nothing
    @test row.n == 6
    s = load_sbox(db, row.id)
    gold = SBox{6}([gf_pow(x, 3, 6; modulus = conway_polynomial(6)) for x in 0:63])
    @test s == gold
end
