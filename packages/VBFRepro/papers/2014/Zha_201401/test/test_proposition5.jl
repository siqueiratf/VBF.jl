@testset "Finite earlier inverse-swap family separation" begin
    include(joinpath(@__DIR__,"..","proposition5.jl"))
    r=proposition5_family_report(io=devnull)
    @test r.reference.complete
    @test r.reference.outcome isa Exhausted
    @test length(r.reference.records)==255
    @test r.reference.nonzero_pairs==32385
    @test r.reference.unordered_pairs==32640
    @test r.reference.du4_pairs==9180
    @test r.reference.identity_points==32640*256
    @test count(x->x.invariants.du==4,r.reference.records)==72
    @test all(x->x.ratio==0 || x.trace_eligible==(x.invariants.du==4),r.reference.records)
    @test r.all_separated
    @test length(r.comparisons)==18
    @test all(isempty(x.matching_normalized_ratios) for x in r.comparisons)
    alternate=proposition5_family_report(modulus=285,io=devnull)
    @test alternate.all_separated
    @test alternate.reference.du4_pairs==r.reference.du4_pairs
    # Uncompressed positive controls independently recompute both full invariant tuples.
    byratio=Dict(x.ratio=>x for x in r.reference.records)
    for (u,v) in ((1,32),(2,64),(3,96),(5,13),(1,2),(0,3))
        F=ZhaInverseSwapControl.inverse_swap(u,v,8;modulus=283)
        ratio=u==0 ? 0 : gf_mul(v,gf_inv(u,8;modulus=283),8;modulus=283)
        @test inverse_swap_invariants(F)==byratio[ratio].invariants
        if u!=0
            cert=inverse_swap_scaling_witness(u,v,8;modulus=283)
            G=ZhaInverseSwapControl.inverse_swap(1,cert.ratio,8;modulus=283)
            @test cert.verified
            @test !verify_ea_witness(F.lut,G.lut,cert.columns,1)
        end
    end
    stopped=inverse_swap_family_evidence(8;max_evaluations=0)
    @test stopped.outcome isa BudgetHit
    @test !stopped.complete
    @test stopped.identity_points==0
    partial=proposition5_family_report(max_evaluations=1,io=devnull)
    @test !partial.all_separated
    @test all(x.status==:inconclusive for x in partial.comparisons)
    @test_throws ArgumentError inverse_swap_family_evidence(7)
    @test_throws ArgumentError inverse_swap_family_evidence(8;max_evaluations=-1)
    @test_throws ArgumentError inverse_swap_scaling_witness(0,1,8)
    @test_throws ArgumentError inverse_swap_scaling_witness(1,2,6)
end
