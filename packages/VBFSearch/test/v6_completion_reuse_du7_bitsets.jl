using VBF, Test
include(joinpath(@__DIR__,"fixtures","v5_prototype_baselines.jl"))
withenv(V5PrototypeBaselines.environment(:pre_du7)...) do
    include(joinpath(@__DIR__,"..","tools","analysis","v6_completion_reuse_du7_bitsets.jl"))
end
using .V6CompletionReuseDU7Bitsets

@testset "Surviving L-position iterator preserves order across word boundaries" begin
    bad=UInt64[0x8010000000000001,0xffff000000000001,0x123456789abcdef0]
    for last in (0,1,63,64,65,127,128,129,173,192)
        expected=[i for i in 1:last if
            ((bad[((i-1)>>6)+1]>>((i-1)&63))&1)==0]
        @test collect(V6CompletionReuseDU7Bitsets.ValidIndices(bad,last))==expected
    end
end

@testset "Incompatibility bitset union equals packed signatures across words" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);V=UInt32[1]
    R,piv=Q.rref(V);_,Qmask=Q.pivots_masks(R,piv,G.N)
    C=UInt32[];Cidx=Int[]
    for (i,w) in enumerate(G.flats)
        all(r->!Q.par(w&r),R) || continue
        push!(C,Q.pext(w,Qmask));push!(Cidx,i)
    end
    L=UInt32[mod(i,32) for i in 0:172]
    M=V6CompletionReuseDU7Bitsets.M
    plan=M.prepare(C,Cidx,G,L)
    bits=V6CompletionReuseDU7Bitsets.DU7Bits(plan)
    for x in UInt32(1):UInt32(31),last in (0,1,63,64,65,128,129,173)
        xstate=M.state(plan,x)
        expected=[i for i in 1:last if !M.reject(plan,xstate,plan.states[i])]
        actual=collect(V6CompletionReuseDU7Bitsets.valid_indices!(bits,xstate,last,
            V6CompletionReuseDU7Bitsets.TriangleStats()))
        @test actual==expected
    end
end

@testset "Bitset DU7 preserves outputs caps cursors and original coset indices" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);beta=Q.bent_fourier(G)
    for V in (UInt32[1],UInt32[0x21]),need in 0:2,du_filter in (false,true),kernel in (0,23)
        oldevents=Any[];newevents=Any[]
        expected=V6CompletionReuseDU7Bitsets.M.T.reference_v5_extensions(G,V,need,Q.V5Work(5,4);beta,du_filter,max_kernel=kernel,
            coset_observer=e->push!(oldevents,e))
        native=Q.v5_extensions(G,V,need,Q.V5Work(5,4);beta,du_filter,max_kernel=kernel)
        V5PrototypeBaselines.native_parity(expected,native)
        actual=V6CompletionReuseDU7Bitsets.bitset_du7_v5_extensions(G,V,need,Q.V5Work(5,4);
            beta,du_filter,max_kernel=kernel,coset_observer=e->push!(newevents,e))
        @test expected.Ss==actual.Ss
        @test expected.capped==actual.capped
        @test expected.nX==actual.nX
        @test expected.nX_used==actual.nX_used
        @test expected.next_x==actual.next_x
        @test expected.key==actual.key
        @test expected.nT==actual.nT
        @test actual.ncand<=expected.ncand
        @test length(oldevents)==length(newevents)
        for (old,new) in zip(oldevents,newevents)
            @test old.index==new.index
            @test old.next_x==new.next_x
            @test old.representative==new.representative
            @test old.Ss==new.Ss
            @test old.capped==new.capped
            @test old.du_reject==new.du_reject
            @test old.nT==new.nT
        end
        expected.nX==0 && continue
        chosen=unique([1,expected.nX])
        selected=Any[]
        partial=V6CompletionReuseDU7Bitsets.bitset_du7_v5_extensions(G,V,need,Q.V5Work(5,4);
            beta,du_filter,max_kernel=kernel,selected_coset_indices=chosen,
            coset_observer=e->push!(selected,e))
        @test partial.selected_scope && partial.selected_coset_indices==chosen
        @test partial.next_x===nothing
        @test [e.index for e in selected]==chosen
        for e in selected
            old=only(x for x in oldevents if x.index==e.index)
            @test old.Ss==e.Ss
        end
    end
end
