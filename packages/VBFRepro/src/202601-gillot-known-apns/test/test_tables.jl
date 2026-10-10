@testset "GL table drivers" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))
    include(joinpath(@__DIR__, "..", "section6.jl"))
    include(joinpath(@__DIR__, "..", "table1.jl"))
    include(joinpath(@__DIR__, "..", "table2.jl"))
    include(joinpath(@__DIR__, "..", "table4.jl"))
    include(joinpath(@__DIR__, "..", "table5.jl"))
    include(joinpath(@__DIR__, "..", "table6.jl"))
    include(joinpath(@__DIR__, "..", "table7.jl"))
    include(joinpath(@__DIR__, "..", "table8.jl"))
    include(joinpath(@__DIR__, "..", "table9.jl"))
    @test gl_section3().identity_checked
    @test !gl_section6(max_nodes=0).complete
    @test gl_table5().all_affine
    @test only(gl_table5().rows).degree_counts==[0,15,0,0,0]
    @test gl_table8().total==0
    @test length(gl_paper_roots())==14
    @test algebraic_degree(first(gl_paper_roots()))==3
    @test length(gl_bent_roots())==13
    @test all(gl_kappa(gl_component(F,b))==1 for F in gl_bent_roots() for b in 1:7)
    @test !gl_table9(limit=1,max_nodes=0).complete
    @test !only(gl_table9(limit=1,max_nodes=0).rows).proven_empty
    r=gl_table6([gold_apn(3)];limit=1,max_subfunctions=1,max_subfunctions_per_parent=1,
        max_nodes=10000,max_solutions=1000)
    @test r.processed==1 && r.expected==7 && !r.complete
    @test only(r.records).complete
    @test only(r.records).solutions>0
    @test length(only(r.records).completion_luts)==only(r.records).solutions
    empty_result=gl_table6(limit=0,max_subfunctions=0,timeout_seconds=0)
    @test empty_result.processed==0 && empty_result.expected==0 && empty_result.complete
    @test !empty_result.full_known_closure
    @test !gl_table4(max_comparisons=0).complete
    @test !gl_table8(max_nodes=0).complete
    @test all(c.A+c.B==63 && c.A*c.alpha+c.B*c.beta==126 for c in GL_TABLE7_CONFIGURATIONS)
    mktempdir() do dir
        path=joinpath(dir,"anf.txt")
        write(path,"anf=ab\nanf=abc\n")
        @test gl_table1(path=path,limit=2).processed==2
        @test !gl_table1(path=path,limit=2).complete
        @test gl_table1(path=path,timeout_seconds=0).processed==0
        @test !gl_table7(path=path,limit=2).complete
        checkpoint=joinpath(dir,"checkpoint.toml")
        write(checkpoint,"checkpoint_directory = '../escape'\n")
        @test_throws ArgumentError gl_section6(checkpoint_path=checkpoint)
    end
end
