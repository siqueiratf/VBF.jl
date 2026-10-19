using Test,JSON3
include(joinpath(@__DIR__,"../tools/analysis/frontier_incidence_switching_ledger.jl"))
const FISL=FrontierIncidenceSwitchingLedger
@testset "saved switching evidence dimensions are replayed" begin
    text="basis_hex = []\ncomplete_constraints = true\ndirection = 2\nquotient_dimension = 0\nraw_dimension = 16\n"
    @test FISL.check_evidence(2,0,text)["raw_dimension"]==16
    @test_throws ErrorException FISL.check_evidence(3,0,text)
    @test_throws ErrorException FISL.check_evidence(2,0,replace(text,"true"=>"false"))
    @test_throws ErrorException FISL.check_evidence(2,0,replace(text,"16"=>"17"))
end
@testset "packet timing audit separates wall durations from campaign elapsed time" begin
    mktempdir() do dir
        path=joinpath(dir,"packets.jsonl")
        open(path,"w") do io
            for (kind,seconds) in (("switching",1.0),("v5",9.0))
                println(io,JSON3.write(Dict("kind"=>kind,"compute_wall_seconds"=>seconds,
                    "application_wall_seconds"=>0.1,"processed_cosets"=>0)))
            end
        end
        r=FISL.packet_timings(path)
        @test r["packets"]==2
        @test r["switching_fraction_of_compute_wall"]≈0.1
        @test r["v5_fraction_of_compute_wall"]≈0.9
        @test occursin("not CPU",r["interpretation"])
    end
end
