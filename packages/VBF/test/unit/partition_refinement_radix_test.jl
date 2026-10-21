@testitem "refinement radix cells preserve stable signed-score order" begin
    using VBF,Test,Random
    rng=Xoshiro(0x7ad1)
    for n in (0,1,2,255,256,257,1024,4096),kind in 1:4
        scores=kind==1 ? rand(rng,-8191:8191,n) : kind==2 ? rand(rng,-2:2,n) :
            kind==3 ? rand(rng,[typemin(Int),-1,0,1,typemax(Int)],n) : fill(-17,n)
        order=shuffle(rng,collect(1:n));expected=sort(copy(order);by=i->scores[i])
        work=VBF._PRWorkspace(0,max(1,n),max(1,n))
        actual=copy(order)
        VBF._pr_sort_cell!(actual,scores,1,n,work)
        @test actual==expected
        if n>=256 && kind!=4
            @test length(work.sort_order)==n && length(work.sort_counts)==256
            @test (@allocated VBF._pr_sort_cell!(actual,scores,1,n,work))<1024
        end
    end
    for _ in 1:50,changed in (false,true)
        n=1024;starts=[1,129,513,n+1]
        scores=rand(rng,-8191:8191,n);mate=copy(scores)
        first_order=shuffle(rng,collect(1:n));second_order=copy(first_order)
        for c in 1:length(starts)-1
            shuffle!(rng,view(second_order,starts[c]:starts[c+1]-1))
        end
        changed && (mate[first_order[300]]=typemax(Int))
        a=VBF._PRPartition(copy(first_order),copy(starts))
        b=VBF._PRPartition(copy(second_order),copy(starts))
        x,y=copy(a),copy(b);work=VBF._PRWorkspace(0,n,n)
        expected=VBF._pr_split_pair!(a,b,scores,mate)
        actual=VBF._pr_split_pair!(x,y,scores,mate,work)
        @test actual==expected==!changed
        @test x.order==a.order && y.order==b.order
        @test x.starts==a.starts && y.starts==b.starts
    end
end
