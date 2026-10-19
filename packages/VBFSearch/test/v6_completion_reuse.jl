using Test, VBF
include(joinpath(@__DIR__,"..","tools","analysis","v6_completion_reuse.jl"))
using .V6CompletionReuse

@testset "Completion state is independent of its V5 presentation" begin
    Q=VBF.QuadraticExtensions
    G=Q.geometry(4)
    U=UInt32[0x21,0x12]
    oracle=V6CompletionReuse.complete_state(G,U)
    @test oracle.complete && !isempty(oracle.Ss)
    @test all(S->differential_uniformity(last(Q.function_of(G,S)))==2,oracle.Ss)
    beta=Q.bent_fourier(G)
    # Every hyperplane of the same U reaches exactly the same complete C(U).
    presentation_keys=Any[]
    comp=Q.comp_forms(U)
    for v in comp[2:end]
        V=UInt32[v]
        R,piv=Q.rref(V)
        _,Qmask=Q.pivots_masks(R,piv,G.N)
        representative=first(u for u in comp if Q.span_dim(vcat(V,u))==2)
        canonical=representative
        for (row,p) in zip(R,piv)
            (canonical>>p)&1==1 && (canonical ⊻= row)
        end
        x=Q.pext(canonical,Qmask)
        forms=Q.comp_forms(vcat(V,canonical))
        need=count(q->Q.form_rank(G,q)==G.n,forms[3:4])
        events=Any[]
        result=Q.v5_extensions(G,V,need,Q.V5Work(G.N-1,G.n);beta,
            coset_observer=e->push!(events,e))
        event=only(e for e in events if e.representative==canonical)
        @test !event.capped
        @test event.Ss==oracle.Ss
        push!(presentation_keys,V6CompletionReuse.state_key(G,vcat(V,event.representative)))
    end
    @test length(unique(presentation_keys))==1
end

@testset "Every four-bit completion agrees with direct APN differentials" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4)
    apn_spaces=[S for S in Q.each_rref(G.N,G.n) if
        differential_uniformity(last(Q.function_of(G,S)))==2]
    @test !isempty(apn_spaces)
    for U in Q.each_rref(G.N,G.n-2)
        expected=Set(S for S in apn_spaces if first(Q.rref(vcat(S,U)))==S)
        actual=V6CompletionReuse.complete_state(G,U)
        @test actual.complete
        @test actual.Ss==expected
    end
end

@testset "Exact and GL-equivalent U reuse is certified and detached" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4)
    U=UInt32[0x21,0x12]
    cache=V6CompletionReuse.CompletionCache(max_entries=2)
    fresh=V6CompletionReuse.cached_state!(cache,G,U)
    @test fresh.complete && !fresh.reused
    expected=deepcopy(fresh.Ss)
    first(fresh.Ss)[1] ⊻= 1
    exact=V6CompletionReuse.cached_state!(cache,G,reverse(U))
    @test exact.complete && exact.reused && exact.Ss==expected
    A=UInt16[3,2,4,8]
    W=transform_quadratic_space(G,U,A)
    @test W!=first(Q.rref(U))
    transported=V6CompletionReuse.cached_state!(cache,G,W;source_index=1,input_columns=A)
    independent=V6CompletionReuse.complete_state(G,W)
    @test transported.complete && transported.reused
    @test transported.Ss==independent.Ss
    @test_throws ArgumentError V6CompletionReuse.cached_state!(cache,G,W;
        source_index=1,input_columns=UInt16[1,2,4,8])
    @test_throws ArgumentError V6CompletionReuse.cached_state!(cache,G,W;
        source_index=1,input_columns=UInt16[1,1,4,8])
    @test_throws ArgumentError V6CompletionReuse.cached_state!(cache,G,W;
        source_index=1,input_columns=A,max_T=1)
    @test_throws ArgumentError V6CompletionReuse.cached_state!(cache,G,W;
        source_index=0,input_columns=A)
    capped_cache=V6CompletionReuse.CompletionCache()
    capped=V6CompletionReuse.cached_state!(capped_cache,G,U;max_kernel=0)
    @test !capped.complete && isempty(capped_cache.entries)
    capped=V6CompletionReuse.cached_state!(capped_cache,G,U;max_T=0)
    @test !capped.complete && isempty(capped_cache.entries)
    @test_throws ArgumentError V6CompletionReuse.CompletionCache(max_entries=0)
    @test_throws ArgumentError V6CompletionReuse.state_key(G,U[1:1])
end
