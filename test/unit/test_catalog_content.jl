using BFA
using Test
import DBInterface

# Tests against the committed BFA_catalog.sqlite. Regenerate with:
#     julia --project=. data-build/build_catalog.jl

@testset "committed catalog is present" begin
    @test is_catalog_built()
end

@testset "open + verify default catalog" begin
    db = load_catalog()
    @test db !== nothing

    meta = first(DBInterface.execute(db, "SELECT * FROM schema_meta LIMIT 1"))
    @test meta.schema_version == SCHEMA_VERSION
end

@testset "literature catalog: counts" begin
    db = load_catalog()
    total = 0
    for r in DBInterface.execute(db, "SELECT COUNT(*) AS c FROM functions")
        total = r.c
    end
    @test total == length(literature_sbox_names())     # currently 16

    lit_8bit = 0
    for r in DBInterface.execute(db, "SELECT COUNT(*) AS c FROM functions WHERE family='Literature' AND n=8")
        lit_8bit = r.c
    end
    @test lit_8bit == 2     # AES + AES_inv
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

@testset "BU is NULL only for non-permutations" begin
    db = load_catalog()
    # For non-permutations, boomerang_uniformity must be NULL.
    # All catalog entries are permutations (verified in literature tests),
    # so BU should be NOT NULL across the board.
    rows = 0
    nonnull_bu = 0
    for r in DBInterface.execute(db, "SELECT boomerang_uniformity FROM functions")
        rows += 1
        r.boomerang_uniformity === missing || (nonnull_bu += 1)
    end
    @test rows == length(literature_sbox_names())
    @test nonnull_bu == rows    # all are permutations
end
