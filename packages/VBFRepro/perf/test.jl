using Test, BenchmarkTools
include("run.jl")
@testset "paper inventory and bounded invocation" begin
    @test length(SUITE.metadata)>=4
    @test all(!isempty(m.paper_id) for m in values(SUITE.metadata))
    @test any(m->m.paper_id=="202203-kaleyski-ea-invariants",values(SUITE.metadata))
    # Keep CI tiny: reports enumerate expensive spaces. Exercise their actual
    # core equivalence primitive with the same construction as the paper helper.
    reg=suite()
    benchmark!(reg;group="papers",name="Kaleyski_equivalence_smoke",n=3,
        paper_id="202203-kaleyski-ea-invariants",mode="core_only",setup=()->gold_apn(3,1),
        call=F->are_ea_equivalent(F,F),validate=(p,v)->(@test v))
    mktempdir() do dir
        result=run_suite(reg,"VBFRepro";out=joinpath(dir,"run"),seconds=1.0,samples=2)
        @test length(result.results["papers"][("Kaleyski_equivalence_smoke",3)])==2
        files=result.manifest["provenance"]["source_files"]
        @test haskey(files,"packages/VBFRepro/src/202203-kaleyski-ea-invariants/report.jl")
    end
end

@testset "standalone CLI dispatcher" begin
    @test success(pipeline(`$(Base.julia_cmd()) --startup-file=no --project=$(@__DIR__) $(joinpath(@__DIR__,"run.jl")) --list --level=3`;stdout=devnull,stderr=devnull))
end
