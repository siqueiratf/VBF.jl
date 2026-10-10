using Test, BenchmarkTools
include("run.jl")
@testset "discovery evidence and scratch-store benchmarks" begin
    @test length(SUITE.metadata)>=5
    @test all(k->k[1] in ("evidence","persistence"),keys(SUITE.metadata))
    mktempdir() do dir
        result=run_suite(SUITE,"VBFSearch";out=joinpath(dir,"run"),seconds=1.0,samples=2)
        @test length(BenchmarkTools.leaves(result.results))==length(SUITE.metadata)
        @test all(length(trial)==2 for (_,trial) in BenchmarkTools.leaves(result.results))
    end
end

@testset "standalone CLI dispatcher" begin
    @test success(pipeline(`$(Base.julia_cmd()) --startup-file=no --project=$(@__DIR__) $(joinpath(@__DIR__,"run.jl")) --list --level=3`;stdout=devnull,stderr=devnull))
end
