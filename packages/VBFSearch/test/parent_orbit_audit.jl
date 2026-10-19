using Test, VBF
include(joinpath(@__DIR__,"../tools/analysis/v5_parent_orbit_audit.jl"))
const POA=V5ParentOrbitAudit

@testset "full-parent generators certify original component-space orbits" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(3)
    S=UInt32[1,2,4]
    spaces=[UInt32[q] for q in 1:7]
    cyclic=[UInt16[2,4,1]]
    subgroup=POA.parent_space_orbits(G,S,spaces,cyclic)
    @test length(subgroup.representatives)==3
    @test subgroup.saved_jobs==4
    @test length(subgroup.representative_for)==length(spaces)
    for i in eachindex(spaces)
        @test verify_quadratic_space_transporter(G,
            spaces[subgroup.representative_for[i]],spaces[i],
            subgroup.input_columns_from_representative[i])
        @test verify_quadratic_space_transporter(G,S,S,
            subgroup.input_columns_from_representative[i])
    end
    # A complete native parent group gives one orbit here. This is stronger
    # than the deliberately partial C3 subgroup, with both reductions sound.
    native=quadratic_space_stabilizers(G,S;timeout_seconds=20.0)
    @test native.complete
    full=POA.parent_space_orbits(G,S,spaces,native.generators)
    @test length(full.representatives)==1
    @test full.saved_jobs==6
    identity=POA.parent_space_orbits(G,S,spaces,Vector{UInt16}[])
    @test identity.saved_jobs==0
    @test identity.representatives==collect(1:7)
end

@testset "parent orbit plans reject false actions and incomplete domains" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(3);S=UInt32[1,2,4]
    @test_throws ArgumentError POA.parent_space_orbits(G,S,Vector{UInt32}[],Vector{UInt16}[])
    @test_throws ArgumentError POA.parent_space_orbits(G,S,[UInt32[1],UInt32[1]],Vector{UInt16}[])
    @test_throws ArgumentError POA.parent_space_orbits(G,UInt32[1,2],[UInt32[4]],Vector{UInt16}[])
    @test_throws ArgumentError POA.parent_space_orbits(G,S,[UInt32[1]],[UInt16[2,4,1]])
    @test_throws ArgumentError POA.parent_space_orbits(G,S,[UInt32[1]],[UInt16[1,1,4]])
    @test_throws ArgumentError POA.parent_space_orbits(G,UInt32[1,2],
        [UInt32[1],UInt32[2]],[UInt16[2,1,4]])
end

@testset "partial parent groups retain unknown extra reuse in cluster statistics" begin
    frame=Dict("population_parents"=>10000,"population_strata"=>Dict(
        "root/complete"=>1000,"discovered/queued_unprepared"=>9000))
    records=[Dict{String,Any}("uniform_parent_sample"=>true,"queue_state"=>"queued_unprepared",
        "maximizing_v5_count"=>10,"saved_jobs_certified"=>6,"orbit_count"=>4,
        "reuse_calculation_complete"=>false),
        Dict{String,Any}("uniform_parent_sample"=>true,"queue_state"=>"queued_unprepared",
        "maximizing_v5_count"=>1,"saved_jobs_certified"=>0,"orbit_count"=>1,
        "reuse_calculation_complete"=>true),
        Dict{String,Any}("uniform_parent_sample"=>true,"queue_state"=>"complete",
        "maximizing_v5_count"=>3,"saved_jobs_certified"=>0,"orbit_count"=>3,
        "reuse_calculation_complete"=>false)]
    rates=POA.rates(frame,records)
    @test rates["parents_with_certified_v5_job_reuse"]==1
    @test rates["parents_with_unknown_possible_reuse"]==1
    @test rates["saved_v5_jobs_certified"]==6
    @test rates["possible_additional_savings_if_unknown_groups_complete"]==5
    @test rates["v5_job_weighted_cluster_ratio_identified_estimate"]==[6/14,11/14]
    queue=POA.rates(frame,records;queue_only=true)
    @test queue["population_parents"]==9000
    @test queue["uniform_sampled_parents"]==2
    @test queue["parents_with_unknown_possible_reuse"]==0
end
