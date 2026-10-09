module EquivalenceTests
using Test
include("../check_equivalence.jl")

@testset "independent EA witnesses" begin
    f = UInt8.(polynomial_to_lut("X^3",8,conway_polynomial(8)))
    g = UInt8[f[(x⊻0x53)+1] ⊻ UInt8(x) ⊻ 0xac for x in 0:255]
    cols = vcat([1<<i for i in 0:7],[(1<<(i+8)) | (1<<i) for i in 0:7])
    constant = (Int(0x53)<<8) | Int(0x53⊻0xac)
    @test verify_ea_witness(f,g,cols,constant)
    badlut = copy(g); badlut[99] ⊻= 1
    @test !verify_ea_witness(f,badlut,cols,constant)
    @test !verify_ea_witness(f,g,cols,constant⊻1)
    singular = copy(cols); singular[1] = singular[2]
    @test !verify_ea_witness(f,g,singular,constant)
    singular = copy(cols); singular[9] = singular[10]
    @test !verify_ea_witness(f,g,singular,constant)
    # Swapping graph halves fixes the identity graph but is not an EA map.
    swap = vcat([1<<(i+8) for i in 0:7],[1<<i for i in 0:7])
    @test !verify_ea_witness(UInt8.(0:255),UInt8.(0:255),swap,0)
    @test !verify_ea_witness(f,g,cols[1:15],constant)
    @test !verify_ea_witness(f,g,cols,65536)

    solved = solve_pair(f,g;timeout_seconds=30.0,max_nodes=1_000_000)
    @test solved.status == "ea_equivalent"
    @test verify_ea_witness(f,g,solved.cols,solved.constant)
    stopped = solve_pair(f,g;timeout_seconds=30.0,max_nodes=0)
    @test stopped.status == "inconclusive"
    @test stopped.result isa BudgetHit
    @test isempty(stopped.cols)
    affine = UInt8.(0:255)
    negative = solve_pair(f,affine;timeout_seconds=30.0,max_nodes=1_000_000)
    @test negative.status == "ea_inequivalent"
    @test negative.result isa Exhausted

    mktempdir() do dir
        path = joinpath(dir,"witnesses.toml")
        row = Dict{String,Any}("sigma_hash"=>"fixture", "status"=>"ea_equivalent",
            "candidate_lut_hex"=>bytes2hex(f),"public_lut_hex"=>bytes2hex(g),
            "candidate_lut_sha256"=>bytes2hex(SHA.sha256(f)),
            "public_lut_sha256"=>bytes2hex(SHA.sha256(g)),
            "graph_map_columns"=>cols,"graph_map_constant"=>constant)
        report = save_equivalence_report(path,Dict(),[row],"fixture")
        @test report["complete"]
        @test verify_witness_report(path) == 1
        row["graph_map_constant"] = constant⊻1
        save_equivalence_report(path,Dict(),[row],"fixture")
        @test_throws ErrorException verify_witness_report(path)
        row["graph_map_constant"] = constant
        row["candidate_lut_sha256"] = "wrong"
        save_equivalence_report(path,Dict(),[row],"fixture")
        @test_throws ErrorException verify_witness_report(path)
        unresolved = Dict("sigma_hash"=>"second","status"=>"inconclusive")
        report = save_equivalence_report(path,Dict(),[unresolved],"fixture")
        @test !report["complete"]
        @test report["inconclusive"] == 1
    end
end
end
