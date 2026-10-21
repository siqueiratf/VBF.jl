@testitem "native child partition pools preserve search and observer semantics" begin
    using VBF,Test,Random

    values(parts)=Tuple((copy(p.order),copy(p.starts)) for p in parts)
    function geometry(F,G,algorithm)
        n,m=inputbits(F),outputbits(F)
        left,right=FunctionGraph(F).packed,FunctionGraph(G).packed
        wl,wr=VBF._pr_graph_walsh(left,n+m),VBF._pr_graph_walsh(right,n+m)
        hf=VBF._pr_intersection_histogram(wl,length(left))
        hg=VBF._pr_intersection_histogram(wr,length(right))
        @test hf==hg
        floor=(n<=7 ? 16 : 2)*length(left)
        classes,nplanes=VBF._pr_select_classes(hf,floor;preserve_order=algorithm!==:paper)
        lf,hl=VBF._pr_build_planes(wl,length(left),classes,hf)
        rt,hr=VBF._pr_build_planes(wr,length(right),classes,hg)
        pl,pr=VBF._pr_native_partition(length(left)),VBF._pr_native_partition(length(right))
        (;n,m,left,right,lf,rt,pl,pr,hl,hr,floor,nplanes)
    end
    function runner(F,G,x,algorithm;trace=nothing)
        work=VBF._PRWorkspace(x.n+x.m,length(x.left),x.nplanes;algorithm,rng=Xoshiro(940),trace)
        function run(pooled;nodes=100000,timeout=120.0)
            Random.seed!(work.rng,940)
            budget=VBF._PRBudget(time_ns(),timeout,nodes,0,:none)
            parts=(copy(x.pl),copy(x.pr),copy(x.hl),copy(x.hr))
            pool=pooled ? VBF._PRPartitionPool(parts...) : nothing
            cert=VBF._pr_dfs!(F,G,x.left,x.right,x.lf,x.rt,parts...,
                VBF._PRAffineMap(x.n,x.m),work,x.floor,true,budget,
                algorithm===:optimized && algebraic_degree(G)<=2,nothing,pool)
            (;cert,nodes=budget.nodes,stop=budget.stopped,rng_next=rand(work.rng,UInt64),parts,pool)
        end
    end
    signature(r)=(r.cert===nothing ? nothing : (r.cert.linear.cols,r.cert.constant),r.nodes,r.stop,r.rng_next)

    @testset "Snapshot ownership, lengths and index types" begin
        for I in (Int,Int32),n in (0,1,17,512)
            p=VBF._PRPartition{I}(collect(I(1):I(n)),n==0 ? [1] : [1,n+1])
            q=VBF._PRPartition{I}(I[],Int[])
            @test VBF._pr_partition_copyto!(q,p)===q
            @test q.order==p.order && q.starts==p.starts
            @test q.order!==p.order && q.starts!==p.starts
            VBF._pr_partition_copyto!(q,VBF._PRPartition{I}(I[],[1]))
            VBF._pr_partition_copyto!(q,p)
            @test q.order==p.order && q.starts==p.starts
        end
        p=VBF._pr_native_partition(256);h=VBF._pr_native_partition(4096,[1,2,4097])
        pool=VBF._PRPartitionPool(p,p,h,h)
        a=VBF._pr_child_partitions!(pool,1,p,p,h,h)
        b=VBF._pr_child_partitions!(pool,2,a...)
        @test length(unique(objectid(part.order) for part in (a...,b...)))==8
        @test length(unique(objectid(part.starts) for part in (a...,b...)))==8
        @test all(part->part!==p && part!==h,(a...,b...))
        VBF._pr_trim_pair!(a[3],a[4],1;preserve_order=false)
        @test length(a[3].order)==1
        VBF._pr_child_partitions!(pool,1,p,p,h,h)
        @test values(a)==values(b)==values((p,p,h,h))
        @test_throws ErrorException VBF._pr_child_partitions!(pool,4,p,p,h,h)
    end

    F=gold_apn(8)
    input=F2AffineMap(F2LinearMap{8,UInt8}(UInt8[1<<mod(i+1,8) for i in 0:7]),UInt8(5))
    output=F2LinearMap{8,UInt8}(UInt8[1<<mod(i+3,8) for i in 0:7])
    affine_image=SBox{8}(UInt8[output(F(input(UInt8(x))))⊻UInt8(x)⊻UInt8(17) for x in 0:255])
    cases=((gold_apn(3),SBox{3}(gold_apn(3).lut .⊻ UInt8(3))),
        (gold_apn(5,1),gold_apn(5,2)),(F,affine_image))
    @testset "Exact witness, node budgets, RNG and private root state" begin
        for (F,G) in cases,algorithm in (:paper,:optimized)
            x=geometry(F,G,algorithm);run=runner(F,G,x,algorithm)
            for cap in (0,1,2,5,17,1000,100000)
                a,b=run(false;nodes=cap),run(true;nodes=cap)
                @test signature(a)==signature(b)
                @test values(a.parts)==values(b.parts)
                @test length(b.pool.layers)<=x.n+x.m+1
                @test all(layer->all(p->all(q->p!==q && p.order!==q.order && p.starts!==q.starts,b.parts),layer),b.pool.layers)
                if b.cert!==nothing
                    @test ccz_equivalent_function(F,b.cert)==G
                    columns,constant=copy(b.cert.linear.cols),b.cert.constant
                    for layer in b.pool.layers,p in layer
                        fill!(p.order,0);fill!(p.starts,0)
                    end
                    @test b.cert.linear.cols==columns && b.cert.constant==constant
                end
            end
            a,b=run(false;timeout=0.0),run(true;timeout=0.0)
            @test signature(a)==signature(b)
            @test values(a.parts)==values(b.parts)==values((x.pl,x.pr,x.hl,x.hr))
            @test isempty(b.pool.layers)
            # Omitting the new optional arguments retains private copying.
            work=VBF._PRWorkspace(x.n+x.m,length(x.left),x.nplanes;algorithm,rng=Xoshiro(940))
            budget=VBF._PRBudget(time_ns(),120.0,17,0,:none)
            parts=(copy(x.pl),copy(x.pr),copy(x.hl),copy(x.hr))
            cert=VBF._pr_dfs!(F,G,x.left,x.right,x.lf,x.rt,parts...,
                VBF._PRAffineMap(x.n,x.m),work,x.floor,true,budget,
                algorithm===:optimized && algebraic_degree(G)<=2)
            expected=run(false;nodes=17)
            @test (cert===nothing ? nothing : (cert.linear.cols,cert.constant),budget.nodes,budget.stopped,rand(work.rng,UInt64))==signature(expected)
            @test values(parts)==values(expected.parts)
        end
    end

    @testset "Trace callbacks keep their historical object aliases" begin
        F,G=cases[1]
        for algorithm in (:paper,:optimized)
            x=geometry(F,G,algorithm)
            traces=[Any[],Any[]];aliases=[Any[],Any[]]
            identities=[IdDict{Any,Int}(),IdDict{Any,Int}()]
            observe=i->(stage,pl,pr,hl,hr)->begin
                parts=(pl,pr,hl,hr)
                push!(traces[i],(stage,values(parts)))
                push!(aliases[i],Tuple(get!(identities[i],p,length(identities[i])+1) for p in parts))
            end
            a=runner(F,G,x,algorithm;trace=observe(1))(false)
            b=runner(F,G,x,algorithm;trace=observe(2))(true)
            @test signature(a)==signature(b)
            @test traces[1]==traces[2] && aliases[1]==aliases[2]
            @test isempty(b.pool.layers)
        end
    end

    @testset "Sibling reuse removes repeated native copy allocations" begin
        F,G=cases[2];x=geometry(F,G,:paper);run=runner(F,G,x,:paper)
        run(false;nodes=1000);run(true;nodes=1000)
        copying=@allocated run(false;nodes=1000)
        pooled=@allocated run(true;nodes=1000)
        @test pooled<0.85copying
    end
end
