@testitem "corpus" begin
using VBF
using VBFCatalog
using Test

@testset "bulk_corpora descriptor" begin
    db = load_catalog()
    if "simonberg_gf4_n8" in list_corpora(db)
        info = corpus_info(db, "simonberg_gf4_n8")
        @test info !== nothing
        @test info.n == 8
        @test info.m == 8
        @test info.degree == 2
        @test info.member_count == 196863
        @test info.encoding == "quadratic-coeffs-v1"
        @test info.bytes_per_member == 37          # 1 const + 8 linear + 28 quadratic GF(2⁸) bytes
        @test info.modulus == conway_polynomial(8)
        @test corpus_length(db, "simonberg_gf4_n8") == 196863
        # the committed side store exists and is the descriptor's content hash
        @test isfile(corpus_store_path("simonberg_gf4_n8"))
    else
        @test_skip "optional SimonBerg GF4 corpus is not registered in this catalog"
    end
end

@testset "members reconstruct as quadratic APN, members ≠ functions rows" begin
    db = load_catalog()
    if "simonberg_gf4_n8" in list_corpora(db)
        # member 1 of each class is the class representative → its LUT matches the first-class CCZ-rep-GF4 row.
        s1 = corpus_function(db, "simonberg_gf4_n8", 1)
        @test inputbits(s1) == 8
        @test differential_uniformity(s1) == 2     # APN
        @test algebraic_degree(s1) == 2            # quadratic
        rep = find_function(db; canonical_name = "SimonBerg_GF4_n8_class_1")
        @test rep !== nothing
        @test lut_sha256_hex(s1) == rep.lut_sha256

        # a deep member also reconstructs to a quadratic APN
        for i in (2, 1000, 100_000, 196_863)
            s = corpus_function(db, "simonberg_gf4_n8", i)
            @test differential_uniformity(s) == 2
            @test algebraic_degree(s) == 2
        end

        # the 196k members are NOT first-class rows — the catalog stays small
        @test count_functions(db; family = "CCZ-rep-GF4") == 27
    else
        @test_skip "optional SimonBerg GF4 corpus is not registered in this catalog"
    end
end

@testset "the seven 8-bit quadratic-APN literature corpora" begin
    db = load_catalog()
    # bib_key => member_count, the quadratic-APN families forming the pre-3.4 GB landscape (firstQAM stores 8179: its single non-quadratic member is excluded)
    expected = Dict(
        "edelpott2009_n8"             => ("EdelPott2009", 22),
        "wengtangong2013_n8"          => ("WengTanGong2013", 10),
        "yuwangli2014_qam_n8"         => ("YuWangLi2014QAM", 8179),
        "taniguchi2019_n8"            => ("Taniguchi2019", 2),
        "beierleleander2022_n8"       => ("BeierleLeander2022", 12923),
        "yuperrin2022_qam_n8"         => ("YuPerrin2022QAM", 5412),
        "beierleleanderperrin2022_n8" => ("BeierleLeanderPerrin2022Trims", 6368),
    )
    corpora = list_corpora(db)
    total = 0
    for (name, (bib, count)) in expected
        @test name in corpora
        info = corpus_info(db, name)
        @test info.n == 8 && info.degree == 2
        @test info.encoding == "quadratic-coeffs-v1"
        @test info.bib_key == bib
        @test info.member_count == count
        @test corpus_length(db, name) == count
        @test isfile(corpus_store_path(name))
        total += count
        # a sampled member reconstructs to a genuine quadratic APN function
        s = corpus_function(db, name, count)        # the last member
        @test inputbits(s) == 8
        @test differential_uniformity(s) == 2
        @test algebraic_degree(s) == 2
    end
    @test total == 32916                            # 22+10+8179+2+12923+5412+6368

    # Taniguchi's two corpus members match the constructor's two new classes
    t1 = corpus_function(db, "taniguchi2019_n8", 1)
    t2 = corpus_function(db, "taniguchi2019_n8", 2)
    newreps = [r.sbox for r in taniguchi_apn_representatives(4) if r.new]
    @test Set([apn_ea_mugshot(t1), apn_ea_mugshot(t2)]) ==
          Set(apn_ea_mugshot(s) for s in newreps)
end
end
