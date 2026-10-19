using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/quadratic_completion_smt.jl"))
const CSMT=QuadraticCompletionSMT
const CSMTQ=VBF.QuadraticExtensions

@testset "Canonical simultaneous completion formula and positive replay" begin
    G=CSMTQ.geometry(4);U=UInt32[0x21];p=CSMT.problem(G,U)
    @test p.r==3 && p.D==5
    spaces=Set{Vector{UInt32}}()
    beta=CSMTQ.bent_fourier(G)
    for need in 0:2
        result=CSMTQ.v5_extensions(G,U,need,CSMTQ.V5Work(5,4);
            beta,max_kernel=5,du7_filter=:bitsets)
        @test !result.capped
        union!(spaces,result.Ss)
    end
    @test length(spaces)==20
    models=Set{Vector{UInt32}}()
    for S in spaces
        model=CSMT.model_of_space(p,S)
        @test length(model)==3
        replay=CSMT.replay_model(p,model)
        @test replay.S==S
        @test length(replay.bent_counts)==7
        @test replay.target_match
        @test !CSMT.replay_model(p,model;need=3).target_match
        push!(models,model)
    end
    @test length(models)==20
    text=CSMT.formula(p;blocked=collect(models))
    @test count("(assert (not (and ",text)==20
    @test occursin("(check-sat)",text)
    @test_throws ArgumentError CSMT.formula(p;blocked=[UInt32[1,1,2]])
    @test_throws ArgumentError CSMT.replay_model(p,UInt32[1,1,2])
    @test_throws ArgumentError CSMT.problem(G,UInt32[])
    @test CSMT.parse_model("(define-fun v0 () (_ BitVec 5) #b00001)\n(define-fun v1 () (_ BitVec 5) #x02)\n(define-fun v2 () (_ BitVec 5) (_ bv4 5))",3)==UInt32[1,2,4]
    @test CSMT.parse_model("unknown",3)===nothing
end
