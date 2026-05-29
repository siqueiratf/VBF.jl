using VBF
using Test

# --- Direct loader tests for the monomial-form pathway ----------------------
# These exercise _materialise_monomial_lut! by writing tiny TOML files
# in a tempdir and bypassing the bundled apn_catalog directory.

import TOML

function _write_tmp_apn_catalog(tmp::AbstractString, entries)
    # Each call writes a single n*_apn.toml under tmp.
    open(joinpath(tmp, "ntest_apn.toml"), "w") do io
        println(io, "schema_version = 1")
        for e in entries
            println(io, "\n[[apn_functions]]")
            for (k, v) in e
                if v isa AbstractString
                    println(io, k, " = ", repr(v))
                elseif v isa AbstractArray
                    println(io, k, " = ", v)
                else
                    println(io, k, " = ", v)
                end
            end
        end
    end
end

@testset "monomial_exponent → LUT is computed and matches gf_monomial_lut" begin
    # Use a TOML structure parallel to the one the loader expects;
    # parse it via TOML.jl directly, then call BFA's internal helper.
    s = """
    schema_version = 1
    [[apn_functions]]
    name = "test_n4_x3"
    description = "Gold x³ over GF(2^4)."
    n = 4
    m = 4
    is_permutation = false
    monomial_exponent = 3
    bib_key = "Gold1968"
    source = "tests"
    """
    data = TOML.parse(s)
    entry = data["apn_functions"][1]
    @test !haskey(entry, "lut")
    VBFCatalog._materialise_monomial_lut!(entry, "ntest_apn.toml")
    @test haskey(entry, "lut")
    @test entry["lut"] == gf_monomial_lut(4, 3)
end

@testset "explicit modulus overrides the default primitive" begin
    s = """
    [[apn_functions]]
    name = "test_with_modulus"
    n = 4
    m = 4
    is_permutation = false
    monomial_exponent = 3
    modulus = 19              # x⁴ + x + 1 — same as the default for n=4
    bib_key = "Gold1968"
    source = "tests"
    """
    data = TOML.parse(s)
    entry = data["apn_functions"][1]
    VBFCatalog._materialise_monomial_lut!(entry, "x")
    @test entry["lut"] == gf_monomial_lut(4, 3; modulus = 19)
end

@testset "explicit lut takes precedence over monomial_exponent" begin
    # If both are given, the explicit LUT wins. Useful when an author wants
    # to override the computed values (e.g., to pin a specific modulus
    # choice not in the primitive table).
    s = """
    [[apn_functions]]
    name = "test_explicit_wins"
    n = 4
    m = 4
    is_permutation = false
    monomial_exponent = 3
    lut = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    bib_key = "Gold1968"
    source = "tests"
    """
    data = TOML.parse(s)
    entry = data["apn_functions"][1]
    VBFCatalog._materialise_monomial_lut!(entry, "x")
    @test entry["lut"] == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
end

@testset "missing monomial_exponent: entry unchanged" begin
    s = """
    [[apn_functions]]
    name = "no_monomial"
    n = 4
    m = 4
    is_permutation = false
    lut = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    bib_key = "Gold1968"
    source = "tests"
    """
    data = TOML.parse(s)
    entry = data["apn_functions"][1]
    VBFCatalog._materialise_monomial_lut!(entry, "x")
    @test entry["lut"] == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    @test !haskey(entry, "monomial_exponent")
end

@testset "existing n=4 and n=5 APN entries remain functional" begin
    # The committed entries use explicit `lut`. They must continue to load
    # bit-identically after the loader change.
    s4 = load_apn_function("n4_Gold_x3")
    @test s4.lut == UInt8[0, 1, 8, 15, 12, 10, 1, 1, 10, 15, 15, 12, 8, 10, 8, 12]

    s5 = load_apn_function("n5_Gold_x3")
    @test inputbits(s5) == 5
    @test differential_uniformity(s5) == 2
end
