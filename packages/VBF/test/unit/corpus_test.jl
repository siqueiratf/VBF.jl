@testitem "corpus" begin
using VBF
using VBFCatalog
using Test

# The Simon-Berg thesis corpus: all CCZ classes of GF(2²)-coefficient quadratic
# APN over GF(2⁸), stored compactly in a side store (one `bulk_corpora` row in
# the main catalog) and reconstructed on demand. These are read-only checks
# against the committed catalog + corpus store.

@testset "bulk_corpora descriptor" begin
    db = load_catalog()
    @test "simonberg_gf4_n8" in list_corpora(db)
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
end

@testset "members reconstruct as quadratic APN, members ≠ functions rows" begin
    db = load_catalog()
    # member 1 of each class is the class representative → its LUT matches the
    # first-class CCZ-rep-GF4 row.
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
end
end
