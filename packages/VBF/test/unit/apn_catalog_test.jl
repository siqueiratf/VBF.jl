@testitem "apn_catalog" begin
using VBFCatalog
using VBF
using Test

@testset "apn_catalog_names" begin
    names = apn_catalog_names()
    @test "n4_Gold_x3" in names
    @test "n5_Gold_x3" in names
    @test "n5_Gold_x5" in names
    @test "n5_Kasami_x15" in names
end

@testset "apn_catalog_metadata: required fields" begin
    for name in apn_catalog_names()
        meta = apn_catalog_metadata(name)
        @test haskey(meta, "n")
        @test haskey(meta, "m")
        @test haskey(meta, "lut")
        @test haskey(meta, "bib_key")
        @test haskey(meta, "source")
        @test haskey(meta, "is_permutation")
        @test haskey(meta, "description")
        @test length(meta["lut"]) == 1 << meta["n"]
    end
end

@testset "load_apn_function: APN-ness is verified" begin
    for name in apn_catalog_names()
        s = load_apn_function(name)
        @test differential_uniformity(s) == 2
    end
end

@testset "load_apn_function: n4_Gold_x3 specifics" begin
    s = load_apn_function("n4_Gold_x3")
    @test inputbits(s) == 4
    @test storage_type(s) === UInt8
    @test !is_permutation(s)              # x^3 is 3-to-1 in GF(2^4), not bijective
    @test differential_uniformity(s) == 2
    @test algebraic_degree(s) == 2        # Gold functions are quadratic
    # Hand-checked: F(0) = 0, F(1) = 1.
    @test s(0) == 0
    @test s(1) == 1
    @test s(2) == 8                       # 2^3 in GF(2^4)
end

@testset "load_apn_function: rejects unknown name" begin
    @test_throws ArgumentError load_apn_function("does_not_exist")
end

@testset "n=5 Gold/Kasami: permutation + APN" begin
    # Algebraic degree of a monomial x^d equals popcount(d):
    #   x^3  → popcount(3)  = 2 (Gold, quadratic)
    #   x^5  → popcount(5)  = 2 (Gold, quadratic)
    #   x^15 → popcount(15) = 4 (Kasami, not quadratic)
    expected = Dict("n5_Gold_x3" => 2, "n5_Gold_x5" => 2, "n5_Kasami_x15" => 4)
    for (name, deg) in expected
        s = load_apn_function(name)
        @test inputbits(s) == 5
        @test is_permutation(s)
        @test differential_uniformity(s) == 2
        @test algebraic_degree(s) == deg
        @test s(0) == 0           # x^d sends 0 ↦ 0
        @test s(1) == 1           # x^d sends 1 ↦ 1
    end
end

@testset "n=5 Gold/Kasami: pairwise distinct LUTs" begin
    s3   = load_apn_function("n5_Gold_x3")
    s5   = load_apn_function("n5_Gold_x5")
    s15  = load_apn_function("n5_Kasami_x15")
    @test length(Set([s3, s5, s15])) == 3
end

end
