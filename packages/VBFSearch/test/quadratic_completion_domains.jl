using Test,VBF,JSON3
include(joinpath(@__DIR__,"../tools/analysis/quadratic_completion_smt.jl"))
include(joinpath(@__DIR__,"../tools/analysis/quadratic_completion_domains.jl"))
const CD=QuadraticCompletionDomains
const CDSMT=QuadraticCompletionSMT

@testset "Finite-field constraint propagation and output-label symmetry" begin
    for r in 1:3,subset in 0:127
        D=3;flats=UInt32[c for c in 1:7 if isodd(subset>>(c-1))]
        p=(;r,D,flats)
        expected=any(0:(1<<(r*D))-1) do packed
            vectors=UInt32[(packed>>(j*D))&7 for j in 0:r-1]
            all(c->any(v->isodd(count_ones(c&v)),vectors),flats)
        end
        actual=CD.solve(p;timeout_seconds=Inf,capture_proof=true)
        @test actual.status==(expected ? "sat" : "unsat")
        if expected
            @test all(c->any(v->isodd(count_ones(c&v)),actual.vectors),flats)
        else
            @test CD.replay_unsat(p,actual.proof)
        end
    end
    G=VBF.QuadraticExtensions.geometry(4)
    p=CDSMT.problem(G,UInt32[0x21]);result=CD.solve(p;timeout_seconds=Inf)
    @test result.status=="sat"
    replay=CDSMT.replay_model(p,result.vectors)
    @test length(replay.S)==4
    @test CD.solve(p;max_nodes=0).status=="unknown"
    @test CD.solve(p;timeout_seconds=0).status=="unknown"
    impossible=(;r=1,D=2,flats=UInt32[1,2,3])
    proof=CD.solve(impossible;capture_proof=true,timeout_seconds=Inf).proof
    @test CD.replay_unsat(impossible,JSON3.read(JSON3.write(proof)))
    @test !CD.replay_unsat(impossible,merge(proof,(;branches=Any[])))
    @test !CD.replay_unsat(impossible,nothing)
end
