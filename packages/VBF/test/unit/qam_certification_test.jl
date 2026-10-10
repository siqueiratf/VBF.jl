@testitem "qam_certification" begin
using VBF, Test
@testset "invariant collision must be decided, never silently merged" begin
    F,G=gold_apn(5,1),gold_apn(5,2)
    @test apn_ea_mugshot(F)==apn_ea_mugshot(G)
    for confirm in (false,true)
        reps=SBox{5,UInt8}[];buckets=Dict{APNEAMugshot,Vector{SBox{5,UInt8}}}()
        @test VBF._qam_add_candidate!(reps,buckets,F;confirm,timeout_seconds=20,max_nodes=10^6)==:added
        @test VBF._qam_add_candidate!(reps,buckets,G;confirm,timeout_seconds=20,max_nodes=10^6)==(confirm ? :added : :duplicate)
        @test length(reps)==(confirm ? 2 : 1)
    end
    reps=[F];buckets=Dict(apn_ea_mugshot(F)=>[F])
    @test VBF._qam_add_candidate!(reps,buckets,G;confirm=true,timeout_seconds=20,max_nodes=0)==:inconclusive
    @test reps==[F]
end
@testset "budget and boundary semantics" begin
    for f in (() -> search_qam(2,1;max_evaluations=0),
              () -> search_qam(2,1;timeout_seconds=0),
              () -> search_qam_full(3;max_nodes=0),
              () -> search_qam_full(3;timeout_seconds=0))
        o=f();@test o isa BudgetHit;@test nodes_visited(o)==0;@test !proves_emptiness(o)
    end
    exact=search_qam(2,1;max_evaluations=2)
    @test exact isa Exhausted
    @test nodes_visited(exact)==2
    @test occursin("lower bound",coverage_note(exact))
    capped=search_qam(3,1;limit=1)
    @test capped isa Found
    @test nodes_visited(capped)>0
    @test_throws ArgumentError search_qam(2,1;max_evaluations=-1)
    @test_throws ArgumentError search_qam_full(3;max_nodes=-1)
end
@testset "full proper-submatrix pruning loses no 3-bit quadratic APNs" begin
    expected=Set{Tuple}()
    for a in 0:7,b in 0:7,c in 0:7
        M=[0 a b;a 0 c;b c 0];F=qam_to_sbox(M)
        differential_uniformity(F)==2 && push!(expected,Tuple(F.lut))
    end
    observed=Set{Tuple}()
    observer=(event,F)->(event===:apn && push!(observed,Tuple(F.lut));nothing)
    out=search_qam_full(3;confirm=true,observer,max_evaluations=1000,timeout_seconds=30)
    @test out isa Exhausted
    @test observed==expected
    @test search_region(out).params["solution_unit"]=="ea_class"
    @test all(F->differential_uniformity(F)==2,search_solutions(out))
end
end
