@testitem "dense extension histograms retain signed overflow and ordered cosets" begin
    using VBF,Test,Random
    Q=VBF.QuadraticExtensions;rng=Xoshiro(18105273)
    @test Q._v5_flat_histogram(Int16[-1,0,0,1])==Dict{Int16,Int}(-1=>1,0=>2,1=>1)
    for scale in (-2,0,1,3,8),d in (0,5,13),need in (-1,0,2)
        cnt=vcat(Int32[0,-3,-1,0,1,3,8,typemin(Int32),typemax(Int32)],rand(rng,Int32,100))
        h,X=Q._v5_bent_histogram(cnt,scale,need,d)
        expected=Dict{Int32,Int}()
        for v in cnt[2:end];expected[v]=get(expected,v,0)+1;end
        @test h==expected
        @test X==UInt32[i-1 for i in 2:length(cnt) if cnt[i]==need*scale]
    end
    values=collect(typemin(Int16):typemax(Int16));shuffle!(rng,values)
    append!(values,Int16[typemin(Int16),0,0,typemax(Int16)])
    h=Q._v5_flat_histogram(values)
    @test length(h)==65536 && sum(Base.values(h))==length(values)
    @test h[typemin(Int16)]==2 && h[0]==3 && h[typemax(Int16)]==2

    @testset "exclusive dense scratch resets without aliasing results" begin
        bins=fill(-19,3)
        reused=Q._v5_flat_histogram(values,bins)
        @test reused==h
        @test length(bins)==65536
        previous=copy(reused)
        fill!(bins,-31)
        constant=fill(typemin(Int16),4096)
        @test Q._v5_flat_histogram(constant,bins)==Dict(typemin(Int16)=>4096)
        @test reused==previous
        @test Q._v5_flat_histogram(values,bins)==h
        @test Q._v5_flat_histogram(values,Int[])==h
        @test Q._v5_flat_histogram(values,fill(77,65537))==h

        fill!(bins,23)
        @test Q._v5_flat_histogram(Int16[-1,0,0,1],bins)==Dict{Int16,Int}(-1=>1,0=>2,1=>1)
        @test all(==(23),bins)
        @test isempty(Q._v5_flat_histogram(Int16[],bins))
        @test all(==(23),bins)
        @test Q._v5_flat_histogram(values,bins)==h
        @test reused==previous

        large=zeros(Int16,1<<20)
        Q._v5_flat_histogram(large,bins)
        allocated=@allocated Q._v5_flat_histogram(large,bins)
        @test Q._v5_flat_histogram(large,bins)==Dict{Int16,Int}(0=>length(large))
        @test allocated<16_384
    end
end
