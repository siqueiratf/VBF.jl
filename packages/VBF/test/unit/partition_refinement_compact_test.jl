@testitem "compact native partitions retain exact order and private compatibility" begin
    using VBF,Test,Random
    @test eltype(VBF._PRPartition(10).order)==Int
    historical=VBF._PRPartition(Int32[1,2],Int32[1,3])
    @test eltype(historical.order)==eltype(historical.starts)==Int
    @test VBF._pr_partition_index_type(Int(typemax(Int32)))==Int32
    if sizeof(Int)>4
        @test VBF._pr_partition_index_type(Int(typemax(Int32))+1)==Int
    end
    rng=Xoshiro(0xc04c)
    for n in (0,1,256,4096)
        native=VBF._pr_native_partition(n)
        @test eltype(native.order)==Int32 && eltype(native.starts)==Int
        @test native.order==collect(1:n)
        duplicate=copy(native)
        @test eltype(duplicate.order)==Int32 && duplicate.order!==native.order
        @test duplicate.starts==native.starts && duplicate.starts!==native.starts
    end
    for n in (0,1,512,4096),preserve_order in (false,true),floor in (0,1,n,typemax(Int))
        starts=n==0 ? [1] : n<4 ? [1,n+1] : [1,n÷4+1,n÷2+1,n+1]
        a=VBF._PRPartition(shuffle(rng,collect(1:n)),copy(starts));b=copy(a)
        x=VBF._PRPartition{Int32}(Int32.(a.order),copy(starts));y=copy(x)
        VBF._pr_trim_pair!(a,b,floor;preserve_order)
        VBF._pr_trim_pair!(x,y,floor;preserve_order)
        @test a.order==x.order && b.order==y.order
        @test a.starts==x.starts && b.starts==y.starts
        @test eltype(x.order)==eltype(y.order)==Int32
    end
    for _ in 1:30,changed in (false,true)
        n=1024;starts=[1,129,513,n+1]
        scores=rand(rng,-8191:8191,n);mate=copy(scores)
        order=shuffle(rng,collect(1:n))
        changed && (mate[order[300]]=typemax(Int))
        a=VBF._PRPartition(copy(order),copy(starts));b=copy(a)
        x=VBF._PRPartition{Int32}(Int32.(order),copy(starts));y=copy(x)
        work=VBF._PRWorkspace(0,n,n)
        expected=VBF._pr_split_pair!(a,b,scores,mate,work)
        actual=VBF._pr_split_pair!(x,y,scores,mate,work)
        @test actual==expected==!changed
        @test a.order==x.order && b.order==y.order
        @test a.starts==x.starts && b.starts==y.starts
    end
    native=VBF._pr_native_partition(4096);historical=VBF._PRPartition(4096)
    copy(native);copy(historical)
    native_bytes=@allocated copy(native)
    historical_bytes=@allocated copy(historical)
    @test native_bytes<0.6historical_bytes
end
