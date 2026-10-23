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

@testitem "DU7 private capacity resets domains and obeys its retained byte cap" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions
    function synthetic_plan(npairs,ntriples,L)
        pairs=fill((UInt32(1),UInt32(2)),npairs)
        triples=fill((UInt32(1),UInt32(2),UInt32(4)),ntriples)
        mask=foldl(|,(UInt64(1)<<(3(i-1)) for i in 1:ntriples);init=UInt64(0))
        valid=ntuple(word->foldl(|,(UInt64(1)<<((i-1)&63) for i in 1:npairs
            if ((i-1)>>6)+1==word);init=UInt64(0)),4)
        tables=Vector{NTuple{9,UInt64}}[]
        plan=Q._DU7Plan(pairs,triples,mask,valid,tables,L)
        for chunk in 0:2
            push!(tables,[Q._du7_linear_state(plan,UInt32(value)<<(8chunk)) for value in 0:255])
        end
        plan
    end
    work=Q._DU7Workspace()
    @test Q._du7_workspace_bytes(work)==0
    @test work.max_bytes==8*1024^2
    @test_throws ArgumentError Q._DU7Workspace(;max_bytes=-1)
    for (npairs,ntriples,L) in ((8,2,UInt32.(0:129)),(1,0,UInt32.(0:64)),
            (4,1,reverse(UInt32.(0:129))),(0,0,UInt32[]),(2,1,UInt32[5]))
        plan=synthetic_plan(npairs,ntriples,L)
        fresh=Q._DU7Bits(plan);reused=Q._DU7Bits(plan,work)
        @test (@inferred Q._DU7Bits(plan,work)) isa Q._DU7Bits
        words=cld(length(L),64)
        @test reused.zeroes===work.zeroes && reused.signatures===work.signatures && reused.bad===work.bad
        @test reused.triple_count==ntriples
        @test reused.zeroes[1:words,1:npairs]==fresh.zeroes
        @test reused.signatures[1:words,1:8ntriples]==fresh.signatures
        @test Q._du7_workspace_bytes(work)<=work.max_bytes
        for x in UInt32(0):UInt32(7),last in unique([0,min(1,length(L)),min(63,length(L)),
                min(64,length(L)),min(65,length(L)),length(L)])
            state=Q._du7_state(plan,x)
            actual=collect(Q._du7_valid_indices!(reused,state,last))
            expected=collect(Q._du7_valid_indices!(fresh,state,last))
            @test actual==expected
        end
        legacy=Q._DU7Bits(fresh.zeroes,fresh.signatures,fresh.bad)
        @test legacy.triple_count==ntriples
        converted=Q._DU7Bits(UInt128.(fresh.zeroes),UInt128.(fresh.signatures),UInt128.(fresh.bad))
        @test converted.zeroes==fresh.zeroes && converted.signatures==fresh.signatures
    end
    wide=synthetic_plan(8,0,UInt32.(0:129));narrow=synthetic_plan(1,1,UInt32.(0:63))
    crossed=Q._DU7Workspace(;max_bytes=216)
    Q._DU7Bits(wide,crossed)
    @test Q._du7_workspace_bytes(crossed)==216
    value=Q._DU7Bits(narrow,crossed)
    @test size(crossed.zeroes)==(1,1) && size(crossed.signatures)==(1,8)
    @test Q._du7_workspace_bytes(crossed)==80
    @test value.zeroes==Q._DU7Bits(narrow).zeroes
    oversized=Q._DU7Workspace(;max_bytes=79)
    old=(oversized.zeroes,oversized.signatures,oversized.bad)
    fallback=Q._DU7Bits(narrow,oversized)
    @test Q._du7_workspace_bytes(oversized)==0
    @test all(a===b for (a,b) in zip(old,(oversized.zeroes,oversized.signatures,oversized.bad)))
    @test fallback.zeroes!==oversized.zeroes && fallback.zeroes==Q._DU7Bits(narrow).zeroes
    disabled=Q._DU7Workspace(;max_bytes=0)
    @test Q._DU7Bits(narrow,disabled).signatures==Q._DU7Bits(narrow).signatures
    @test Q._du7_workspace_bytes(disabled)==0
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
        L=UInt32.(0:129);plan=Q._du7_prepare(C,fi,G)
        plan===nothing && continue
        bits=Q._DU7Bits(plan,L)
        @test !hasfield(typeof(plan),:states)
        @test size(bits.zeroes,1)==cld(length(L),64)
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
    empty_spaces=Q._EmptyCompletionSpaces()
    @test empty_spaces==Set{Vector{UInt32}}()
    @test Set{Vector{UInt32}}()==empty_spaces
    @test collect(empty_spaces)==Vector{UInt32}[]
    @test !(UInt32[1] in empty_spaces)
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
