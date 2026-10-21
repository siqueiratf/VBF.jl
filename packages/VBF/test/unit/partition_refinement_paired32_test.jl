@testitem "paired native incidence scores preserve bounded integer and output semantics" begin
    using VBF,Test,Random
    rng=Xoshiro(0x940032)

    @testset "Subset adjustment exceeds Int32 while each signature remains bounded" begin
        k=Int(fld(typemax(Int32),8191))
        bound=k*8191
        @test bound<=typemax(Int32)<2Int128(bound)
        normals=fill(UInt32(1),k)
        for sign in (-1,1)
            weights=fill(Int32(sign*8191),k)
            total=VBF._pr_direct_weight_total32(weights,k)
            @test total===sign*bound
            @test VBF._pr_signed_sum32_pair(UInt32(1),UInt32(0),normals,weights,k,total)===(-total,total)
            @test VBF._pr_signed_sum32_pair(UInt32(1),UInt32(1),normals,weights,k,total)===(-total,-total)
        end
        weights=Int32[isodd(j) ? 8191 : -8191 for j in 1:k]
        normals=UInt32[isodd(j) ? 1 : 0 for j in 1:k]
        total=VBF._pr_direct_weight_total32(weights,k)
        @test total===0
        @test VBF._pr_signed_sum32_pair(UInt32(1),UInt32(0),normals,weights,k,total)===(-bound,0)
        @test VBF._pr_signed_sum32_pair(UInt32(1),UInt32(1),normals,-weights,k,-total)===(bound,bound)
    end

    @testset "Empty, odd and even point output tails, serial and threaded" begin
        for n in (0,1,2,3,4,17),k in (0,17,257,2380)
            points=rand(rng,UInt32,n)
            normals=rand(rng,UInt32,k)
            weights=rand(rng,Int32(-8191):Int32(8191),k)
            expected=Int[VBF._pr_signed_sum(p,normals,weights,k) for p in points]
            @test VBF._pr_direct_point_scores32!(zeros(Int,n),points,normals,weights,k)==expected
            @test VBF._pr_parallel_point_scores32!(zeros(Int,n),points,normals,weights,k)==expected
        end
    end

    @testset "Plane permutation, signs, tails and inactive score preservation" begin
        for npoints in (0,1,17,257),nactive in (0,1,2,3,4,17)
            points=rand(rng,UInt32,npoints)
            weights=rand(rng,Int32(-8191):Int32(8191),npoints)
            planes=VBF._PRPlanes(rand(rng,UInt32,21),Int8[isodd(j) ? -1 : 1 for j in 1:21])
            active=Int32.(randperm(rng,21)[1:nactive])
            expected=fill(typemin(Int),21)
            for i in active
                expected[i]=VBF._pr_signed_sum(planes.normals[i],points,weights,npoints)*planes.signs[i]
            end
            @test VBF._pr_direct_plane_scores32!(fill(typemin(Int),21),points,planes,active,weights)==expected
            @test VBF._pr_parallel_plane_scores32!(fill(typemin(Int),21),points,planes,active,weights)==expected
        end
    end
end
