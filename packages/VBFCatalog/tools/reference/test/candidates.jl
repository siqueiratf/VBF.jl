module CandidateTests
using Test
include("../check_candidates.jl")

@testset "fresh candidate comparison" begin
    mktempdir() do dir
        f = UInt8.(polynomial_to_lut("X^3", 8, conway_polynomial(8)))
        h = bytes2hex(signature(Workspace(), f))
        db = SQL.DB(joinpath(dir, "fresh_union.sqlite"))
        try
            SQL.execute(db, "CREATE TABLE signatures(sigma_hash TEXT PRIMARY KEY)")
            DBI.execute(db, "INSERT INTO signatures VALUES(?)", (h,))
        finally
            close(db)
        end
        open(io -> TOML.print(io, Dict("provenance_complete"=>true,
            "fresh_union_sha256"=>filehash(joinpath(dir, "fresh_union.sqlite")))), joinpath(dir, "comparison.toml"), "w")
        path = joinpath(dir, "candidates.tsv")
        open(path, "w") do io
            println(io, "sigma\tstatus\tlut_hex")
            println(io, h, "\tsearch\t", bytes2hex(f))
            println(io, h, "\tknown\t", bytes2hex(f))
        end
        check_candidates(dir, [path])
        report = TOML.parsefile(joinpath(dir, "candidate_comparison.toml"))
        @test report["checked"] == report["matching_records"] == 2
        @test report["distinct_matching_signatures"] == 1
        @test report["duplicate_signatures"] == 1
        @test report["original_status"]["search"]["matches"] == 1
        @test candidate_lut(bytes2hex(encode_quadratic(SBox{8}(f)))) == f
        coeffs = zeros(UInt8, 28); coeffs[1] = 0x53
        lut = candidate_lut(bytes2hex(coeffs))
        @test lut == UInt8[x & 3 == 3 ? 0x53 : 0 for x in 0:255]
        open(io -> println(io, "0"^64, '\t', bytes2hex(f)), path, "w")
        @test_throws ErrorException check_candidates(dir, [path])
    end
end
end
