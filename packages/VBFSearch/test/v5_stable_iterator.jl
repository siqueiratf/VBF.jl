using Test,VBF
include(joinpath(@__DIR__,"fixtures","v5_prototype_baselines.jl"))
withenv(V5PrototypeBaselines.environment(:pre_stable_dense)...) do
    include(joinpath(@__DIR__,"../tools/analysis/v5_stable_iterator.jl"))
end
const V5SI=V5StableIterator
@testset "one iterator type preserves native V5 filters and cursor events" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);V=UInt32[0x21];beta=Q.bent_fourier(G)
    for mode in (:none,:triangles,:bitsets,:auto),need in 0:2,
            kwargs in ((;),(;max_x=0),(;max_x=3),(;max_kernel=0),
                (;selected_coset_indices=[2,5]),(;du_filter=false),(;should_stop=()->true))
        old_events=Any[];new_events=Any[]
        a=Q.v5_extensions(G,V,need,Q.V5Work(5,4);beta,du7_filter=mode,kwargs...,
            coset_observer=e->push!(old_events,e))
        b=V5SI.stable_v5_extensions(G,V,need,Q.V5Work(5,4);beta,du7_filter=mode,kwargs...,
            coset_observer=e->push!(new_events,e))
        @test a==b
        @test old_events==new_events
    end
    @test V5SI.replace_once("abc","a","z")=="zbc"
    @test_throws ErrorException V5SI.replace_once("abc","x","z")
end
