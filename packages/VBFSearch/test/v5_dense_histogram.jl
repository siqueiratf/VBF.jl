using Test,VBF
include(joinpath(@__DIR__,"fixtures","v5_prototype_baselines.jl"))
withenv(V5PrototypeBaselines.environment(:pre_du7)...) do
    include(joinpath(@__DIR__,"../tools/analysis/v5_dense_histogram.jl"))
end
const V5DH=V5DenseHistogram
@testset "dense V5 histograms preserve exact results and event semantics" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);V=UInt32[0x21];beta=Q.bent_fourier(G)
    cases=[(;need=need,kwargs=kwargs) for need in 0:2 for kwargs in
        ((;),(;max_x=0),(;max_x=3),(;max_kernel=0),
         (;selected_coset_indices=[2,5]),(;should_stop=()->true))]
    for case in cases
        original_events=Any[];dense_events=Any[]
        ordinary=Q.v5_extensions(G,V,case.need,Q.V5Work(5,4);beta,case.kwargs...,
            coset_observer=e->push!(original_events,e))
        dense=V5DH.dense_v5_extensions(G,V,case.need,Q.V5Work(5,4);beta,case.kwargs...,
            coset_observer=e->push!(dense_events,e))
        @test ordinary==dense
        @test ordinary==V5DH.original_v5_extensions(G,V,case.need,Q.V5Work(5,4);beta,case.kwargs...)
        @test original_events==dense_events
    end
    ordinary=Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta)
    key_seen=Ref(false)
    skipped=V5DH.dense_v5_extensions(G,V,1,Q.V5Work(5,4);beta,
        should_skip=key->(key_seen[]=key==ordinary.key))
    @test key_seen[]
    @test skipped.skipped
    @test skipped.key==ordinary.key
    @test isempty(skipped.Ss)
    @test skipped.nX_used==0
    @test_throws ErrorException V5DH.dense_histogram_source("upstream drift")
end
