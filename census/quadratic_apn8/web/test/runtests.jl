# Tests the request handler of the APN8 class check page directly (no socket).
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8)
#
# Pseudocode:
#   1. Include server.jl and build HTTP.Request values by hand.
#   2. Send each input to APN8Web.handle and decode the JSON response.
#   3. Check the verdicts: known corpus member, census member, Gold x^3, a non-APN LUT,
#      a non-quadratic APN function, and malformed input.
# VBF API used: SBox, gf_monomial_lut
# VBFCatalog API used: load_catalog, corpus_function
#
# Run: julia --threads=1,1 --project=.. runtests.jl  (or `make test` in web/)

using HTTP
using JSON3
using Random
using Test
using VBF
using VBFCatalog

include(joinpath(@__DIR__, "..", "server.jl"))
isdefined(@__MODULE__, :QK) || include(joinpath(@__DIR__, "..", "..", "qknuth.jl"))

call(method, path, body = "") =
    APN8Web.handle(HTTP.Request(method, path, ["Content-Type" => "text/plain"], body))
classify(body) = (r = call("POST", "/api/classify", body); (r.status, JSON3.read(String(r.body))))
lutstr(lut; sep = ", ") = "[" * join(lut, sep) * "]"

const CENSUS = [split(l, '\t') for l in eachline(APN8Web.CENSUS_TSV)]

@testset "APN8 web handler" begin
    APN8Web.init!()

    @testset "page and routes" begin
        r = call("GET", "/")
        @test r.status == 200
        @test occursin("<textarea", String(r.body))
        @test call("GET", "/nothing").status == 404
        h = JSON3.read(String(call("GET", "/api/health").body))
        @test h.ok && h.census == 553 && h.index_rows > 4_000_000
    end

    @testset "coefficient decoder agrees with QK.lut" begin
        for (_, c) in CENSUS[1:20]
            C = zeros(UInt16, 8, 8)
            t = 0
            for i in 1:8, j in i + 1:8
                t += 1
                C[i, j] = C[j, i] = parse(UInt16, c[2t - 1:2t]; base = 16)
            end
            @test APN8Web.coeffs_to_lut(c) == Int.(QK.lut(C, 8))
        end
    end

    @testset "known beierle2025_n8 member" begin
        cat = load_catalog()
        G = corpus_function(cat, "beierle2025_n8", 1000)
        close(cat)
        st, j = classify(lutstr(Int.(G.lut)))
        @test st == 200
        @test j.format == "lut"
        @test j.apn && j.algebraic_degree == 2
        @test j.status == "known"
        @test j.ea_available
        @test startswith(j.verdict, "KNOWN (sigma matches ")
    end

    @testset "census member (one of the 553)" begin
        h, c = CENSUS[7]
        st, j = classify(String(c))
        @test st == 200
        @test j.format == "coefficients"
        @test j.status == "census"
        @test j.sigma == h
        @test j.census_line == 7
        # The same function as a newline-separated LUT.
        st2, j2 = classify(join(APN8Web.coeffs_to_lut(String(c)), "\n"))
        @test j2.format == "lut" && j2.status == "census" && j2.census_line == 7
    end

    @testset "Gold x^3 is known" begin
        st, j = classify("x^3")
        @test j.format == "polynomial"
        @test j.status == "known"
        st2, j2 = classify(join(gf_monomial_lut(8, 3; modulus = 0x11B), " "))
        @test j2.status == "known" && j2.sigma == j.sigma
        st3, j3 = classify("x^3 mod=0x11D")
        @test j3.status == "known"
    end

    @testset "non-APN random LUT" begin
        lut = randperm(Xoshiro(2026), 256) .- 1
        st, j = classify(lutstr(lut; sep = ","))
        @test st == 200
        @test j.ok && !j.apn
        @test j.status == "not_apn"
        @test j.differential_uniformity > 2
        r = call("POST", "/api/ea", lutstr(lut))
        @test r.status == 400
    end

    @testset "APN, not quadratic (Kasami x^57)" begin
        st, j = classify("x^57")
        @test j.apn && j.algebraic_degree > 2
        @test j.status == "apn_not_quadratic"
        @test !haskey(j, :sigma)
    end

    @testset "malformed input" begin
        for bad in ["", "1 2 3", join(fill(300, 256), " "), "hello world",
                    "x^3 +* (", repeat("g", 56), "x^3 mod=0x1F"]
            st, j = classify(bad)
            @test st == 400
            @test !j.ok && j.status == "error"
            @test !isempty(j.error)
        end
        @test occursin("found 3", classify("1 2 3")[2].error)
        @test occursin("outside 0..255", classify(join(fill(300, 256), " "))[2].error)
    end
end
