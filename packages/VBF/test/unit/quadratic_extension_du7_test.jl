@testitem "DU7 pruning preserves exhaustive small-dimensional completions" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);beta=Q.bent_fourier(G)
    work=Q.V5Work(5,4);table=Q.PolarRankTable(G)
    stable=(:Ss,:nX,:nX_used,:next_x,:du_reject,:nT,:key,:capped,:skipped)
    for q in UInt32(1):UInt32(63),need in 0:2
        baseline=Q.v5_extensions(G,[q],need,work;beta,max_kernel=8)
        for mode in (:triangles,:bitsets,:auto)
            filtered=Q.v5_extensions(G,[q],need,work;beta,max_kernel=8,du7_filter=mode,rank_table=table)
            @test all(getproperty(filtered,k)==getproperty(baseline,k) for k in stable)
            @test filtered.ncand<=baseline.ncand
        end
        nofilter=Q.v5_extensions(G,[q],need,work;beta,du_filter=false,max_x=2,max_kernel=0)
        requested=Q.v5_extensions(G,[q],need,work;beta,du_filter=false,max_x=2,max_kernel=0,du7_filter=:bitsets)
        @test requested==nofilter
    end
    @test_throws ArgumentError Q.v5_extensions(G,UInt32[1],1,work;beta,du7_filter=:invalid)
end

@testitem "fused selected affine equations retain canonical solutions" begin
    using VBF,Test,Random
    Q=VBF.QuadraticExtensions;rng=Xoshiro(18105272)
    rows=UInt32[];piv=Int[];K=UInt32[]
    for D in (0,1,5,23,31),_ in 1:100
        domain=UInt32(0):((UInt32(1)<<D)-UInt32(1))
        C=rand(rng,domain,rand(rng,0:100));t=rand(rng,domain)
        Z=filter(c->!Q.par(c&t),C)
        expected=isempty(Z) ? nothing : Q.solve_ones(Z,D)
        actual=Q._solve_ones_annihilating(C,t,D,rows,piv,K)
        @test actual==expected
        if actual!==nothing
            v0,basis=actual
            @test all(c->Q.par(c&v0),Z)
            @test all(k->all(c->!Q.par(c&k),Z),basis)
        end
    end
end

@testitem "DU7 bitsets agree with direct point counts and retain ordered partial words" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions;G=Q.geometry(4)
    for q in UInt32[1,3,7,11,63]
        R,p=Q.rref([q]);_,mask=Q.pivots_masks(R,p,G.N)
        fi=[i for (i,w) in enumerate(G.flats) if !Q.par(w&q)]
        C=UInt32[Q.pext(G.flats[i],mask) for i in fi]
        L=UInt32.(0:129);plan=Q._du7_prepare(C,fi,G,L)
        plan===nothing && continue
        bits=Q._DU7Bits(plan)
        for x in UInt32(1):UInt32(31)
            lifted=Q.lift(x,mask)
            cx=[i for i in fi if !Q.par(G.flats[i]&lifted)]
            degrees=zeros(Int,16)
            for i in cx,p in G.flatpts[i];degrees[p+1]+=1;end
            maximum(degrees)<=3 || continue
            for last in (0,1,63,64,65,129,130)
                selected=collect(Q._du7_valid_indices!(bits,Q._du7_state(plan,x),last))
                @test issorted(selected) && length(unique(selected))==length(selected)
                expected=Int[]
                for i in 1:last
                    t=Q.lift(L[i],mask);fill!(degrees,0)
                    for f in cx
                        Q.par(G.flats[f]&t) && continue
                        for p in G.flatpts[f];degrees[p+1]+=1;end
                    end
                    maximum(degrees)<=1 && push!(expected,i)
                end
                @test selected==expected
            end
        end
    end
    @test Q._du7_triangle_reject([(UInt32(1),UInt32(2))],UInt32(4))
    @test !Q._du7_triangle_reject([(UInt32(1),UInt32(2))],UInt32(1))
end

@testitem "DU7 pruning preserves partial-search observer scopes" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);beta=Q.bent_fourier(G);V=UInt32[1]
    stable=(:index,:next_x,:total_x,:representative,:Ss,:du_reject,:nT,:capped)
    for mode in (:triangles,:bitsets),cap in (0,8),selection in (nothing,[1,2])
        old=Any[];new=Any[]
        kwargs=selection===nothing ? (;max_x=3,start_x=2) : (;selected_coset_indices=selection)
        a=Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,max_kernel=cap,kwargs...,coset_observer=e->push!(old,e))
        b=Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,max_kernel=cap,kwargs...,du7_filter=mode,coset_observer=e->push!(new,e))
        @test a.Ss==b.Ss && a.capped==b.capped && a.next_x==b.next_x
        @test length(old)==length(new)
        @test all(all(getproperty(x,k)==getproperty(y,k) for k in stable) for (x,y) in zip(old,new))
    end
end
