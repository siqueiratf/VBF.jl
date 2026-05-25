using BFA
using Test

@testset "apn_catalog_names" begin
    names = apn_catalog_names()
    @test "n4_Gold_x3" in names
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
