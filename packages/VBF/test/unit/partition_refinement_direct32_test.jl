@testitem "checked native direct signatures preserve full-width semantics" begin
    using VBF,Test,Random
    rng=Xoshiro(0xd132)
    @testset "Private constructors and bounded scratch eligibility" begin
        legacy=VBF._PRWorkspace(4,4,8)
        fields=ntuple(i->getfield(legacy,i),16)
        @test !legacy.native_direct
        @test !VBF._PRWorkspace{Int32,typeof(legacy.rng)}(fields...).native_direct
        @test !VBF._PRWorkspace(fields...).native_direct
        @test !VBF._PRWorkspace(fields[1:14]...).native_direct
        @test !VBF._PRWorkspace(fields[1:11]...).native_direct
        work=VBF._PRWorkspace(4,4,8;native_direct=true)
        weights=Int[-8191,-1,0,1,8191]
        original=copy(weights)
        @test VBF._pr_direct_weights!(legacy,weights,5)===nothing
        @test VBF._pr_direct_weights!(work,weights,5)===work.scratch
        @test work.scratch[1:5]==Int32.(weights) && weights==original
        @test VBF._pr_direct_weights!(work,weights,0)===work.scratch
        for (bad,k) in (([8192],1),([-8192],1),([typemin(Int)],1),([typemax(Int)],1),
                (ones(Int,17),17),(ones(Int,1),2),(Int[], -1))
            before=copy(work.scratch)
            @test VBF._pr_direct_weights!(work,bad,k)===nothing
            @test work.scratch==before
        end
        traced=VBF._PRWorkspace(4,4,8;native_direct=true,trace=(args...)->nothing)
        @test VBF._pr_direct_weights!(traced,weights,5)===nothing
        wide=VBF._PRWorkspace(zeros(Int64,16),fields[2:end]...,true)
        @test wide.native_direct && VBF._pr_direct_weights!(wide,weights,5)===nothing
        large=VBF._PRWorkspace(19,1,1;native_direct=true)
        bound=Int(fld(typemax(Int32),8191))
        @test VBF._pr_direct_weights!(large,ones(Int,bound+1),bound+1)===nothing
        normals=zeros(UInt32,bound);edge=fill(8191,bound)
        for sign in (1,-1)
            fill!(edge,sign*8191)
            @test VBF._pr_direct_weights!(large,edge,bound)===large.scratch
            @test VBF._pr_signed_sum32(UInt32(0),normals,large.scratch,bound)==sign*bound*8191
        end
        # The original generic helper still supports arbitrary Int32 weights.
        @test VBF._pr_signed_sum(UInt32(0),zeros(UInt32,2),fill(typemax(Int32),2),2)==2Int(typemax(Int32))
    end

    @testset "Every partial native sum fits and still returns Int" begin
        for k in (0,1,31,256,512,4096),p in (UInt32(0),UInt32(65535))
            normals=rand(rng,UInt32,k)
            positive=Int[isodd(count_ones(p&v)) ? -8191 : 8191 for v in normals]
            for weights in (positive,-positive,rand(rng,-8191:8191,k))
                expected=VBF._pr_signed_sum(p,normals,weights,k)
                actual=VBF._pr_signed_sum32(p,normals,Int32.(weights),k)
                @test actual==expected && actual isa Int
            end
        end
    end

    @testset "Serial/threaded direct, dense reuse and custom-key fallbacks" begin
        points=FunctionGraph(gold_apn(8)).packed
        planes=VBF._PRPlanes(rand(rng,UInt32,8192),rand(rng,Int8[-1,1],8192))
        # Keep normals within the same ambient space as the native graph.
        planes.normals .&= UInt32(65535)
        pp=VBF._pr_native_partition(256,[1,33,129,257])
        full=VBF._pr_native_partition(8192,[1,1025,4097,8193])
        medium=VBF._PRPartition{Int32}(Int32.(randperm(rng,8192)[1:2048]),[1,257,1025,2049])
        small=VBF._PRPartition{Int32}(Int32.(randperm(rng,8192)[1:512]),[1,65,257,513])
        for threaded in (false,true)
            old=VBF._PRWorkspace(16,256,8192;threaded)
            new=VBF._PRWorkspace(16,256,8192;threaded,native_direct=true)
            for hp in (medium,full,small,full,medium)
                keys=Int[8191,-8191,7]
                VBF._pr_point_scores!(old.point_left,points,planes,hp,old;keys)
                VBF._pr_point_scores!(new.point_left,points,planes,hp,new;keys)
                @test old.point_left==new.point_left
                VBF._pr_plane_scores!(old.plane_left,points,pp,planes,hp,old;keys)
                VBF._pr_plane_scores!(new.plane_left,points,pp,planes,hp,new;keys)
                @test old.plane_left==new.plane_left
            end
            for weight in (8192,-8192,typemin(Int),typemax(Int))
                keys=fill(weight,3)
                VBF._pr_point_scores!(old.point_left,points,planes,medium,old;keys)
                VBF._pr_point_scores!(new.point_left,points,planes,medium,new;keys)
                @test old.point_left==new.point_left
                VBF._pr_plane_scores!(old.plane_left,points,pp,planes,medium,old;keys)
                VBF._pr_plane_scores!(new.plane_left,points,pp,planes,medium,new;keys)
                @test old.plane_left==new.plane_left
            end
        end
        # Rectangular/private direct domains can exceed transform scratch.
        points2=UInt32[0,1]
        planes2=VBF._PRPlanes(UInt32.(1:30),ones(Int8,30))
        hp=VBF._pr_native_partition(30)
        old=VBF._PRWorkspace(4,2,30)
        new=VBF._PRWorkspace(4,2,30;native_direct=true)
        @test old.direct_threshold==32 && length(new.scratch)==16
        VBF._pr_point_scores!(old.point_left,points2,planes2,hp,old)
        VBF._pr_point_scores!(new.point_left,points2,planes2,hp,new)
        @test old.point_left==new.point_left
    end

    @testset "Exact witness, RNG and node-limit behavior" begin
        for (F,G) in ((gold_apn(5,1),gold_apn(5,2)),
                (gold_apn(8),SBox{8}(gold_apn(8).lut .⊻ UInt8(17)))),algorithm in (:paper,:optimized)
            n=inputbits(F);left,right=FunctionGraph(F).packed,FunctionGraph(G).packed
            wl,wr=VBF._pr_graph_walsh(left,2n),VBF._pr_graph_walsh(right,2n)
            hf=VBF._pr_intersection_histogram(wl,length(left))
            hg=VBF._pr_intersection_histogram(wr,length(right))
            @test hf==hg
            floor=(n<=7 ? 16 : 2)*length(left)
            classes,nplanes=VBF._pr_select_classes(hf,floor;preserve_order=algorithm!==:paper)
            lf,hl=VBF._pr_build_planes(wl,length(left),classes,hf)
            rt,hr=VBF._pr_build_planes(wr,length(right),classes,hg)
            pl,pr=VBF._pr_native_partition(length(left)),VBF._pr_native_partition(length(right))
            function query(native,nodes,timeout=120.0)
                work=VBF._PRWorkspace(2n,length(left),nplanes;algorithm,rng=Xoshiro(940),native_direct=native)
                budget=VBF._PRBudget(time_ns(),timeout,nodes,0,:none)
                parts=(copy(pl),copy(pr),copy(hl),copy(hr))
                cert=VBF._pr_dfs!(F,G,left,right,lf,rt,parts...,VBF._PRAffineMap(n),work,
                    floor,true,budget,algorithm===:optimized,nothing,VBF._PRPartitionPool(parts...))
                cert===nothing || @test ccz_equivalent_function(F,cert)==G
                (cert===nothing ? nothing : (cert.linear.cols,cert.constant),budget.nodes,budget.stopped,rand(work.rng,UInt64),
                    Tuple((copy(p.order),copy(p.starts)) for p in parts))
            end
            for cap in (0,1,2,17,1000,100000)
                @test query(false,cap)==query(true,cap)
            end
            @test query(false,100000,0.0)==query(true,100000,0.0)
        end
    end
end
