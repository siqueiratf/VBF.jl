@testitem "catalog_content" begin
using VBFCatalog
using VBF
using Test
import DBInterface

# Tests against the committed BFA_catalog.sqlite. Regenerate with:     julia --project=. data-build/build_catalog.jl

@testset "committed catalog is present" begin
    @test is_catalog_built()
end

@testset "open + verify default catalog" begin
    db = load_catalog()
    @test db !== nothing

    meta = first(DBInterface.execute(db, "SELECT * FROM schema_meta LIMIT 1"))
    @test meta.schema_version == SCHEMA_VERSION
end

@testset "catalog: family partition is internally consistent" begin
    db = load_catalog()
    lit_8bit = 0
    for r in DBInterface.execute(db, "SELECT COUNT(*) AS c FROM functions WHERE family='Literature' AND n=8")
        lit_8bit = r.c
    end
    @test lit_8bit == 2     # AES + AES_inv

    apn_count = 0
    for r in DBInterface.execute(db, "SELECT COUNT(*) AS c FROM functions WHERE family='APN'")
        apn_count = r.c
    end
    @test apn_count == length(apn_catalog_names())
end

@testset "literature catalog: AES row matches load_literature_sbox" begin
    db = load_catalog()
    found = false
    for r in DBInterface.execute(db, "SELECT * FROM functions WHERE canonical_name='AES'")
        found = true
        @test r.n == 8
        @test r.m == 8
        @test r.is_permutation == 1
        @test r.is_apn == 0
        @test r.is_quadratic == 0
        @test r.differential_uniformity == 4
        @test r.linearity == 32
        @test r.algebraic_degree == 7
        @test r.boomerang_uniformity == 6
        @test r.bib_key == "FIPS197"
        @test occursin("AES", r.notes)

        # LUT round-trip
        s = load_literature_sbox("AES")
        @test r.lut_sha256 == lut_sha256_hex(s)
        @test Vector{UInt8}(r.lut_blob) == canonical_lut_bytes(s)
    end
    @test found
end

@testset "bibliography table covers every function's bib_key" begin
    db = load_catalog()
    orphan_bib_keys = String[]
    for r in DBInterface.execute(
            db,
            "SELECT DISTINCT bib_key FROM functions WHERE bib_key NOT IN (SELECT bib_key FROM bibliography)")
        push!(orphan_bib_keys, r.bib_key)
    end
    @test isempty(orphan_bib_keys)
end

@testset "BU is NULL exactly for non-permutations" begin
    db = load_catalog()
    rows = 0
    nonnull_bu = 0
    perms = 0
    for r in DBInterface.execute(db, "SELECT boomerang_uniformity, is_permutation FROM functions")
        rows += 1
        r.boomerang_uniformity === missing || (nonnull_bu += 1)
        r.is_permutation == 1 && (perms += 1)
    end
    @test rows > 0
    @test nonnull_bu == perms     # BU populated iff is_permutation
end

@testset "n=4 APN: n4_Gold_x3 round-trip via catalog" begin
    db = load_catalog()
    r = find_function(db; canonical_name = "n4_Gold_x3")
    @test r !== nothing
    @test r.family == "APN"
    @test r.is_apn
    @test !r.is_permutation
    @test r.is_quadratic
    @test r.differential_uniformity == 2
    @test r.algebraic_degree == 2
    @test r.boomerang_uniformity === nothing
    @test r.algebraic_form !== nothing
    @test occursin("x^3", r.algebraic_form)

    s = load_sbox(db, "n4_Gold_x3")
    @test s == load_apn_function("n4_Gold_x3")
end

end
