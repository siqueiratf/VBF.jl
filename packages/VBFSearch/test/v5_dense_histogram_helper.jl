using Test,VBF
include(joinpath(@__DIR__,"fixtures","v5_prototype_baselines.jl"))
withenv(V5PrototypeBaselines.environment(:pre_du7)...) do
    include(joinpath(@__DIR__,"../tools/analysis/v5_dense_histogram_helper.jl"))
end
const V5DHH=V5DenseHistogramHelper
@testset "non-inlined dense histograms preserve original types and all state" begin
    counts=Int32[8,0,8,3,-1,16]
    h,X=V5DHH.dense_hc_candidates(counts,8,1,1)
    @test h==Dict{Int32,Int}(0=>1,8=>1,3=>1,-1=>1,16=>1)
    @test X==UInt32[2]
    g=Int16[typemin(Int16),-1,0,0,typemax(Int16)]
    @test V5DHH.dense_hg(g)==Dict{Int16,Int}(typemin(Int16)=>1,-1=>1,0=>2,typemax(Int16)=>1)
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);V=UInt32[0x21];beta=Q.bent_fourier(G)
    for need in 0:2,kwargs in ((;),(;max_x=0),(;max_x=3),(;max_kernel=0),
        (;selected_coset_indices=[2,5]),(;should_stop=()->true))
        a_events=Any[];b_events=Any[]
        a=Q.v5_extensions(G,V,need,Q.V5Work(5,4);beta,kwargs...,coset_observer=e->push!(a_events,e))
        b=V5DHH.dense_v5_extensions(G,V,need,Q.V5Work(5,4);beta,kwargs...,coset_observer=e->push!(b_events,e))
        @test a==b
        @test a_events==b_events
    end
end
