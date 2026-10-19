using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/quadratic_completion_core_pilot.jl"))
const CCP=QuadraticCompletionCorePilot

@testset "Exact core support, Veronese witnesses and necessary transfer invariants" begin
    p=(;r=1,D=3,flats=UInt32[1,2,3,4,5])
    core=CCP.K.minimize(p;max_seconds=10,max_nodes=10000,query_seconds=1)
    @test length(core.flats)==3
    @test core.rank==2
    @test core.irreducible
    @test CCP.K.D.replay_unsat((;r=1,D=3,flats=core.flats),core.proof)
    fano=CCP.quadratic_lift_certificate(UInt32.(1:7),3)
    @test fano.status=="unsat"
    @test length(fano.witness)==7
    @test CCP.quadratic_lift_certificate(UInt32[1,2,3],2).status=="no_certificate"
    for subset in 0:127
        C=UInt32[c for c in 1:7 if isodd(subset>>(c-1))]
        result=CCP.quadratic_lift_certificate(C,3)
        if result.status=="unsat"
            @test CCP.K.D.solve((;r=2,D=3,flats=C);timeout_seconds=Inf).status=="unsat"
            A=CCP.lifted_rows(C,3)
            @test isodd(length(result.witness))
            @test all(j->iseven(count(identity,A[result.witness,j])),axes(A,2))
        end
    end
    L=F2LinearMap{3,UInt32}(UInt32[3,2,4])
    for C in (UInt32[1,2,3],UInt32.(1:7),UInt32[1,2,4,7])
        @test CCP.triangle_invariants(C)==CCP.triangle_invariants(L.(C))
    end
end
