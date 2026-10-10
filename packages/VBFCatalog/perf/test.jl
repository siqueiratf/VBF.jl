using Test, BenchmarkTools, SHA
include("run.jl")
@testset "catalog benchmarks read without changing the catalog" begin
    path=catalog_path();before=bytes2hex(open(sha256,path))
    @test haskey(SUITE.metadata,("catalog","count_functions",0))
    @test all(k->k[1]=="catalog",keys(SUITE.metadata))
    mktempdir() do dir
        result=run_suite(SUITE,"VBFCatalog";out=joinpath(dir,"run"),
            workload="count_functions",seconds=1.0,samples=2)
        @test length(result.results["catalog"][("count_functions",0)])==2
        @test result.manifest["inputs"]["catalog_sha256"]==before
    end
    @test bytes2hex(open(sha256,path))==before
end
