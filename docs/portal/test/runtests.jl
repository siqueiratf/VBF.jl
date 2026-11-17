using Test, SHA, TOML
using VBF, VBFCatalog, VBFPortal
using VBFCatalog: canonical_lut_bytes

const H = "f723b6e13a85a8c79c721ee8361b7b574ec3dbaa9da9e91048bf2ec25215374e"

@testset "function keys" begin
    k = FunctionKey(8, 8, uppercase(H))
    @test k.lut_sha256 == H                                     # stored lowercase
    @test key_string(k) == "8-8-$H"
    @test parse_key(key_string(k)) == k
    @test display_key(k) == "8-8-f723b6e13a85"
    @test_throws ArgumentError parse_key("8-8-f723b6e13a85")     # a short hash never resolves
    @test_throws ArgumentError FunctionKey(8, 8, H[1:63])
    @test_throws ArgumentError FunctionKey(0, 8, H)
    F = SBox{8}(gf_monomial_lut(8, 3))
    @test function_key(F, 8) == FunctionKey(8, 8, bytes2hex(sha256(canonical_lut_bytes(F))))
    @test function_key(F, 8) != function_key(SBox{8}(gf_monomial_lut(8, 5)), 8)
end

@testset "equivalence levels" begin
    a = FunctionKey(8, 8, H); b = FunctionKey(8, 8, "0"^64)
    m = EquivalenceRecord(a, b, :CCZ, :invariant_match; invariant = "sigma v1")
    @test !proves_equivalence(m) && !proves_inequivalence(m)     # a match is a filter only
    s = EquivalenceRecord(a, b, :CCZ, :invariant_separation; invariant = "sigma v1")
    @test proves_inequivalence(s) && !proves_equivalence(s)
    v = EquivalenceRecord(a, b, :EA, :verified; evidence = "certificate.toml")
    @test proves_equivalence(v)
    @test_throws ArgumentError EquivalenceRecord(a, b, :EA, :verified)            # needs a certificate
    @test_throws ArgumentError EquivalenceRecord(a, b, :CCZ, :invariant_match)    # needs the invariant
    @test_throws ArgumentError EquivalenceRecord(a, a, :CCZ, :candidate)          # never one key
    @test_throws ArgumentError EquivalenceRecord(a, b, :linear, :candidate)
end

@testset "member references and snapshots" begin
    d1 = "a"^64; d2 = "b"^64
    s = CatalogSnapshot("c"^64, "i", "m", Dict("demo_n8" => d1), nothing)
    @test resolve_member(MemberRef("demo_n8", d1, 7), s) == :current
    @test resolve_member(MemberRef("demo_n8", d2, 7), s) == :historical
    @test resolve_member(MemberRef("other", d1, 7), s) == :unknown
    @test current_member(s, "demo_n8", 7) == MemberRef("demo_n8", d1, 7)
    @test_throws ArgumentError MemberRef("demo_n8", d1[1:12], 7)
    @test_throws ArgumentError MemberRef("demo_n8", d1, 0)
end

if is_catalog_built()
    db = load_catalog()
    @testset "curated functions and the real catalog" begin
        cf = curated_functions(db)
        @test length(cf.by_key) == length(cf.by_name)               # every row has a unique name
        k = resolve_function(cf, "n8_Gold_x3")
        @test k isa FunctionKey && resolve_function(cf, key_string(k)) == k
        @test resolve_function(cf, "no_such_name") === nothing
        @test resolve_function(cf, display_key(k)) === nothing      # short form is display only
        # The catalog key is the hash of the concrete LUT that VBF builds.
        row = cf.by_key[k]
        lut = load_apn_function("n8_Gold_x3")
        @test function_key(lut, k.m) == k
        s = catalog_snapshot(db)
        @test occursin(r"^[0-9a-f]{64}$", s.prebuilt_key)
        @test all(d -> occursin(r"^[0-9a-f]{64}$", d), values(s.corpora))
    end
    @testset "cross-checks of paper.toml" begin
        ctx = CheckContext(db)
        errors, review = check_all(db)
        @test isempty(errors)
        @test "differential_uniformity" in ctx.vbf_names
    end
    close(db)
else
    @info "catalog not built: skipping the catalog tests (run make -C docs data)"
end
