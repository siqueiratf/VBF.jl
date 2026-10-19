using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/quadratic_completion_family.jl"))
const CFamily=QuadraticCompletionFamily

@testset "Exact annihilator family with explicit quotient transporters" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);U=UInt32[1,2]
    p=CFamily.K.S.problem(G,U)
    indices=CFamily.K.C.O.flat_indices(G,U)
    B=UInt32[Q.pext(G.flats[i],p.mask) for i in indices if 8 in G.flatpts[i]]
    @test length(B)==7
    result=CFamily.K.D.solve((;r=2,D=p.D,flats=B);timeout_seconds=Inf,capture_proof=true)
    @test result.status=="unsat"
    family=CFamily.certify(G,U,B,result.proof;target_bent=0)
    @test family.obstruction_rank==3
    @test family.annihilator_dimension==3
    @test family.all_six_space_count==7
    @test length(family.explicit_transport_receipts)==7
    for receipt in family.explicit_transport_receipts
        R,piv=Q.rref(receipt.forms);_,mask=Q.pivots_masks(R,piv,G.N)
        A=F2LinearMap{p.D,UInt32}(receipt.source_to_target_columns)
        @test is_invertible(A)
        @test A.(B)==UInt32[Q.pext(w,mask) for w in family.ambient_flats]
    end
    @test_throws ErrorException CFamily.certify(G,U,B,nothing)
end
