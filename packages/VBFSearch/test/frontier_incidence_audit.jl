using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/frontier_incidence_audit.jl"))
const FIA=FrontierIncidenceAudit
@testset "exact sibling extension incidence and positive controls" begin
    QE=VBF.QuadraticExtensions;G=QE.geometry(4)
    S=UInt32[1,2,4,8]
    lines=[[q] for q in QE.comp_forms(S)[2:end]]
    r=FIA.incidence_records(G,S,lines)
    @test r.incidence==15*7
    @test r.distinct_states==QE.gauss_binom(4,2)==35
    @test r.repeated_incidence==70
    @test r.shared_states==35
    @test r.coincident_sibling_pairs==binomial(15,2)
    @test sum(r.per_space_savings)==70
    @test all(length(v)==3 for v in values(r.state_spaces))
    @test_throws ArgumentError FIA.internal_extensions(S,UInt32[16])
    @test_throws ArgumentError FIA.internal_extensions(S,S)
    @test Set(Tuple.(FIA.internal_extensions(S,UInt32[3,12])))==
        Set(Tuple.(FIA.internal_extensions(UInt32[5,6,9,8],UInt32[15,12])))
    # Known bent filtering is independently checked by direct rank enumeration.
    f=FIA.incidence_records(G,S,lines;target_bent=2)
    expected=Set(Tuple(first(QE.rref(t.forms))) for t in
        QE.subspaces_of_comp(QE.comp_forms(S),QE.bent_mask(G,QE.comp_forms(S)),2;keep=nb->nb==2))
    @test Set(keys(f.state_spaces))==expected
end

@testset "V4 incidence finds exact shared U6 beyond parent siblings" begin
    QE=VBF.QuadraticExtensions;G=QE.geometry(8)
    U=UInt32[1,2,4,8,16,32]
    bases=QE.subspaces_of_comp(QE.comp_forms(U),falses(64),5;keep=nb->true)
    spaces=[Dict("forms"=>Int.(first(QE.rref(r.forms))),"parent_id"=>i) for (i,r) in enumerate(bases)]
    r=FIA.shared_extensions(G,spaces;target_bent=0)
    @test r["complete"]
    @test r["distinct_exact_v5_spaces"]==63
    @test r["intersecting_v5_pairs"]==binomial(63,2)
    @test r["distinct_v4_spaces"]==QE.gauss_binom(6,4)==651
    @test r["eligible_shared_u6"]==1
    @test r["eligible_shared_u6_across_parents"]==1
    @test only(r["states"])["distinct_v5_count"]==63
    @test r["eligible_cross_parent_v5_pairs"]==binomial(63,2)
end
