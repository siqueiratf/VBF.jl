using Test, BenchmarkTools, TOML, SHA
include("support.jl")
using .PerfSupport
@testset "BenchmarkTools resets mutable state and saves native trials" begin
    reg=suite();observed=Ref(0)
    benchmark!(reg;group="smoke",name="mutation",setup=()->[1,2,3],
        call=v->begin
            @assert v==[1,2,3] # fails if samples/evaluations reuse mutated payload
            push!(v,4);observed[]+=1
            v
        end,
        validate=(p,v)->(@test v==[1,2,3,4]))
    @test reg.benchmarks["smoke"][("mutation",0)].params.evals==1
    mktempdir() do dir
        result=run_suite(reg,"VBF";out=joinpath(dir,"run"),seconds=0.1,samples=3)
        @test length(result.results["smoke"][("mutation",0)])==3
        loaded=only(BenchmarkTools.load(joinpath(result.out,"benchmarktools.json")))
        @test loaded["smoke"][("mutation",0)].times==result.results["smoke"][("mutation",0)].times
        manifest=TOML.parsefile(joinpath(result.out,"manifest.toml"))
        @test manifest["measurement_protocol"]=="BenchmarkTools trial summary v1"
        @test manifest["workloads"][1]["sample_limit"]==3
        @test haskey(manifest["provenance"]["source_files"],"packages/VBF/perf/Project.toml")
        @test length(readlines(joinpath(result.out,"timings.tsv")))==2
        @test observed[]>=4 # separate validation plus at least three samples
        @test_throws ArgumentError run_suite(reg,"VBF";out=result.out,samples=1)
    end
    # Explicit CLI/sample limit supersedes workload defaults.
    one=suite();benchmark!(one;group="smoke",name="one",samples=1,call=_->1)
    mktempdir() do dir
        result=run_suite(one,"VBF";out=joinpath(dir,"override"),seconds=0.1,samples=3)
        @test length(result.results["smoke"][("one",0)])==3
    end
    @test_throws ArgumentError run_suite(reg,"VBF";seconds=0.0)
    @test_throws ArgumentError run_suite(reg,"VBF";samples=0)
    @test_throws ArgumentError run_suite(reg,"VBF";group="absent")
end
include("run.jl")
@testset "full API inventory survives migration" begin
    @test length(SUITE.metadata)>150
    @test all(k->k[1]!="catalog",keys(SUITE.metadata))
    @test haskey(SUITE.metadata,("invariants","sigma_hash",8))
    @test haskey(SUITE.metadata,("constructions","search_quadratic_apn_le",7))
    @test all(b.params.evals==1 for group in values(SUITE.benchmarks) for b in values(group))
end

include("profile_support.jl")
@testset "profile configuration is serializable" begin
    mktempdir() do dir
        out=joinpath(dir,"profile")
        PerfProfiles.profile_main(SUITE,"VBF",["--group=spectra","--workload=ddt","--n=8","--out="*out])
        manifest=TOML.parsefile(joinpath(out,"manifest.toml"))
        @test manifest["measurement_protocol"]=="Julia sampling profile v1"
        @test manifest["config"]["parameters"] isa Dict
        @test manifest["config"]["workload"]=="ddt"
        @test isfile(joinpath(out,"profile_raw.jls"))
    end
end

include("refinement_optimizations.jl")
@testset "diagnostic runners use serializable BenchmarkTools trials" begin
    trials=BenchmarkGroup()
    seconds,bytes,value=measure(trials,"tiny",()->sum(1:3),v->(@assert v==6),3)
    @test value==6 && seconds>=0 && bytes>=0
    @test length(trials["tiny"])==3
    mktempdir() do dir
        out=save_diagnostic(trials,"smoke",["--out="*joinpath(dir,"run")],
            Dict("samples"=>3),IOBuffer("case,seconds\ntiny,"*string(seconds)*"\n"))
        @test isfile(joinpath(out,"manifest.toml"))
        @test length(only(BenchmarkTools.load(joinpath(out,"benchmarktools.json")))["tiny"])==3
    end
end
