using Test, VBFWorkingPaper, VBFRepro, SHA, TOML
@testset "Consumer boundary and publication identities" begin
    @test paper_bib_key("202508-beierle-millions")=="Beierle_202500"
    @test paper_bib_key("unknown")===nothing
    for package in ("VBF","VBFCatalog","VBFSearch","VBFRepro")
        p=TOML.parsefile(joinpath(workspace_root(),"packages",package,"Project.toml"))
        @test !haskey(p["deps"],"VBFWorkingPaper")
    end
    @test !isdir(joinpath(pkgdir(VBFRepro),"src","analysis"))
    @test all(p->paper_bib_key(p.id)!==nothing,discover_papers())
end
@testset "Paper build consumes generated evidence without editing sources" begin
    mktempdir() do dir
        source=joinpath(dir,"overleaf");mkdir(source)
        write(joinpath(source,"main.tex"),raw"\documentclass{article}\begin{document}\label{tab:audit}\begin{tabular}{c}old\end{tabular}\end{document}")
        assessments=joinpath(dir,"grades.csv")
        write(assessments,"paper_key,category,year,r1,r2,r3,r4\n202508-beierle-millions,B,2025,f,h,h,o\n")
        original=read(joinpath(source,"main.tex"));out=joinpath(dir,"build")
        @test stage_paper(;source,output=out,assessments)==out
        @test read(joinpath(source,"main.tex"))==original
        @test occursin(raw"\input{generated/tab_audit.tex}",read(joinpath(out,"main.tex"),String))
        table=read(joinpath(out,"generated","tab_audit.tex"),String)
        @test occursin(raw"\tabref{Beierle_202508}",table)
        @test !occursin("old",read(joinpath(out,"main.tex"),String))
        manifest=TOML.parsefile(joinpath(out,"build.toml"))
        @test manifest["table_sha256"]==bytes2hex(sha256(table))
        @test !manifest["compiled"]
        @test_throws ArgumentError stage_paper(;source,output=out,assessments)
        @test_throws ArgumentError stage_paper(;source,output=source,assessments)
        write(joinpath(source,"main.tex"),"no audit table")
        @test_throws ErrorException stage_paper(;source,output=joinpath(dir,"bad"),assessments)
        @test !ispath(joinpath(dir,"bad"))
    end
end

module CensusTests
include("census/runtests.jl")
end
module FamilyTests
include("families.jl")
end
