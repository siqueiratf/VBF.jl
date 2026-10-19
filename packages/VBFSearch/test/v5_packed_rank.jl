using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/v5_packed_rank.jl"))
const V5PR=V5PackedRank
@testset "two-bit ranks preserve zero, all rank values and Fourier coset counts" begin
    Q=VBF.QuadraticExtensions
    for n in (2,4,6)
        G=Q.geometry(n);full=Q.PolarRankTable(G);packed=V5PR.PackedPolarRanks(full)
        @test packed.n==n
        @test length(packed.codes)==cld(length(full.ranks),4)
        @test [V5PR.packed_rank(packed,UInt32(q)) for q in 0:length(full.ranks)-1]==full.ranks
    end
    G=Q.geometry(4);full=Q.PolarRankTable(G);packed=V5PR.PackedPolarRanks(full);beta=Q.bent_fourier(G)
    a=Int32[];b=Int32[]
    for V in Q.each_rref(G.N,2)
        expected=Q.coset_bent_counts!(a,G,V,beta;rank_table=full)
        actual=V5PR.packed_coset_bent_counts!(b,G,V,beta;rank_table=packed)
        @test expected==actual
        @test a==b
    end
    V=UInt32[0x21]
    for mode in (:none,:bitsets,:triangles,:auto),kwargs in ((;),(;max_x=3),(;max_kernel=0),(;selected_coset_indices=[2,5]))
        old_events=Any[];new_events=Any[]
        old=Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,rank_table=full,du7_filter=mode,kwargs...,coset_observer=e->push!(old_events,e))
        new=V5PR.packed_v5_extensions(G,V,1,Q.V5Work(5,4);beta,rank_table=packed,du7_filter=mode,kwargs...,coset_observer=e->push!(new_events,e))
        @test old==new
        @test old_events==new_events
    end
    wrong=V5PR.PackedPolarRanks(Q.PolarRankTable(Q.geometry(2)))
    @test_throws ArgumentError V5PR.packed_coset_bent_counts!(b,G,V,beta;rank_table=wrong)
end
