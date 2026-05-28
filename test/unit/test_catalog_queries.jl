using BFA
using Test

@testset "list_functions / count_functions: filters" begin
    db = load_catalog()

    # The catalog holds three function families: Literature, the declarative
    # APN catalog, and the imported sboxU quadratic-APN reps (APN-rep).
    # Rep contributions are read back from the catalog so these assertions
    # verify the filters partition consistently as the rep lists evolve.
    reps        = list_functions(db; family = "APN-rep")
    n_reps      = length(reps)
    reps_n8     = count(r -> r.n == 8, reps)
    reps_n4     = count(r -> r.n == 4, reps)
    reps_perm   = count(r -> r.is_permutation == 1, reps)

    # No filter: Literature + declarative APN + sboxU reps
    total_expected = length(literature_sbox_names()) + length(apn_catalog_names()) + n_reps
    all_rows = list_functions(db)
    @test length(all_rows) == count_functions(db)
    @test length(all_rows) == total_expected

    # By family
    lits = list_functions(db; family = "Literature")
    @test length(lits) == length(literature_sbox_names())
    @test count_functions(db; family = "Literature") == length(literature_sbox_names())
    @test count_functions(db; family = "APN") == length(apn_catalog_names())
    @test count_functions(db; family = "APN-rep") == n_reps

    # By n=8: 2 literature (AES, AES_inv) + every n=8 APN catalog entry + n=8 reps.
    n8_lit = count(name -> literature_sbox_metadata(name)["n"] == 8, literature_sbox_names())
    n8_apn = count(name -> apn_catalog_metadata(name)["n"] == 8, apn_catalog_names())
    eight = list_functions(db; n = 8)
    @test length(eight) == n8_lit + n8_apn + reps_n8
    @test all(r.n == 8 for r in eight)
    @test Set(["AES", "AES_inv"]) ⊆ Set([r.canonical_name for r in eight])

    # Functions are derived per dimension from the loader caches so the
    # counts don't desync when entries are added to either catalog.
    n4_lit = count(n -> literature_sbox_metadata(n)["n"] == 4, literature_sbox_names())
    n4_apn = count(n -> apn_catalog_metadata(n)["n"] == 4, apn_catalog_names())
    four = list_functions(db; n = 4)
    @test length(four) == n4_lit + n4_apn + reps_n4

    # By is_apn: all reps are APN (and all literature is non-APN)
    @test count_functions(db; is_apn = true) == length(apn_catalog_names()) + n_reps
    @test count_functions(db; is_apn = false) == length(literature_sbox_names())

    # By is_permutation
    perm_apn = count(n -> apn_catalog_metadata(n)["is_permutation"], apn_catalog_names())
    perm_lit = count(n -> literature_sbox_metadata(n)["is_permutation"], literature_sbox_names())
    @test count_functions(db; is_permutation = true) == perm_lit + perm_apn + reps_perm
    @test count_functions(db; is_permutation = false) == length(literature_sbox_names()) +
                                                          length(apn_catalog_names()) + n_reps -
                                                          (perm_lit + perm_apn + reps_perm)

    # By bib_key
    serpents = list_functions(db; bib_key = "AndersonBihamKnudsen1998Serpent")
    @test length(serpents) == 8
end

@testset "list_functions: limit + offset" begin
    db = load_catalog()
    page1 = list_functions(db; limit = 5, offset = 0)
    page2 = list_functions(db; limit = 5, offset = 5)
    @test length(page1) == 5
    @test length(page2) == 5
    @test [r.id for r in page1] != [r.id for r in page2]
end

@testset "find_function" begin
    db = load_catalog()

    # by canonical_name
    aes = find_function(db; canonical_name = "AES")
    @test aes !== nothing
    @test aes.canonical_name == "AES"
    @test aes.n == 8
    @test aes.bib_key == "FIPS197"

    # by id
    by_id = find_function(db; id = aes.id)
    @test by_id !== nothing
    @test by_id.canonical_name == "AES"

    # by lut_sha256
    by_hash = find_function(db; lut_sha256 = aes.lut_sha256)
    @test by_hash !== nothing
    @test by_hash.canonical_name == "AES"

    # Not found
    @test find_function(db; canonical_name = "NoSuchSbox") === nothing

    # Validation: zero or multiple keys
    @test_throws ArgumentError find_function(db)
    @test_throws ArgumentError find_function(db; id = 1, canonical_name = "AES")
end

@testset "load_sbox: round-trip from catalog" begin
    db = load_catalog()

    # By name
    s = load_sbox(db, "AES")
    @test s isa SBox{8}
    @test s == load_literature_sbox("AES")

    # By id
    aes_row = find_function(db; canonical_name = "AES")
    s_by_id = load_sbox(db, aes_row.id)
    @test s_by_id == s

    # All 14 4-bit S-boxes round-trip
    for name in literature_sbox_names()
        s_from_catalog = load_sbox(db, name)
        @test s_from_catalog == load_literature_sbox(name)
    end

    # Not found
    @test_throws ArgumentError load_sbox(db, "NoSuchSbox")
    @test_throws ArgumentError load_sbox(db, 99999)
end

@testset "load_sbox: SBox loaded from catalog has same statistics" begin
    db = load_catalog()
    for name in literature_sbox_names()
        s = load_sbox(db, name)
        row = find_function(db; canonical_name = name)
        @test differential_uniformity(s) == row.differential_uniformity
        @test linearity(s)               == row.linearity
        @test algebraic_degree(s)        == row.algebraic_degree
        if row.is_permutation
            @test boomerang_uniformity(s) == row.boomerang_uniformity
        end
    end
end
