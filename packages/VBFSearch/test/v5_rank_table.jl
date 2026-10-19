using Test,VBF
include(joinpath(@__DIR__,"fixtures","v5_prototype_baselines.jl"))
withenv(V5PrototypeBaselines.environment(:pre_du7)...) do
    include(joinpath(@__DIR__,"../tools/analysis/v5_rank_table.jl"))
end
@testset "Ambient rank lookup preserves every n4 two-space Fourier count" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);ranks=V5RankTable.build_table(G);beta=Q.bent_fourier(G)
    a=Int32[];b=Int32[]
    @test Int.(ranks)==[Q.form_rank(G,UInt32(s)) for s in 0:(1<<G.N)-1]
    for U in Q.each_rref(G.N,2)
        x=Q.coset_bent_counts!(a,G,U,beta)
        y=Q.rank_table_coset_bent_counts!(b,G,U,beta,ranks)
        @test x==y
        @test a==b
    end
end
