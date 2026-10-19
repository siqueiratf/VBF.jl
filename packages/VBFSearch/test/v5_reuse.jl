@testset "Verified V5 completion reuse preserves the entire result set" begin
    Q=VBF.QuadraticExtensions
    G=Q.geometry(6)
    F=gold_apn(6)
    a=anf(F)
    c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:5 for j in i+1:5]
    forms=Q.coord_forms(c,6)
    V=first(Q.rref(forms[1:3]))
    mask=Q.bent_mask(G,Q.comp_forms(vcat(V,forms[4])))
    need=count(identity,mask[9:16])
    identity_columns=UInt16[1 << i for i in 0:5]
    columns=copy(identity_columns)
    W=V
    for i in 1:6, j in 1:6
        i==j && continue
        candidate=copy(identity_columns)
        candidate[i] ⊻= candidate[j]
        transformed=transform_quadratic_space(G,V,candidate)
        if transformed!=V
            columns=candidate
            W=transformed
            break
        end
    end
    @test W!=V
    as_set(outcome)=Set(Tuple(S) for S in search_solutions(outcome))
    cache=V5CompletionCache(max_entries=2)
    fresh=cached_v5_extensions!(cache,G,V,need;max_kernel=12,source_tag="fixture")
    @test fresh.outcome isa Exhausted
    @test !fresh.reused && fresh.certificate["source_complete"]
    @test !isempty(search_solutions(fresh.outcome))
    @test length(cache.entries)==1
    expected=as_set(fresh.outcome)
    pop!(search_solutions(fresh.outcome))
    exact=cached_v5_extensions!(cache,G,V,need;max_kernel=12,max_pairs=0)
    @test exact.reused && exact.comparisons==0 && exact.work===nothing
    @test as_set(exact.outcome)==expected
    @test exact.certificate["source_tag"]=="fixture"

    reused=cached_v5_extensions!(cache,G,W,need;max_kernel=12,max_pairs=1,
        equivalence_seconds=20,equivalence_nodes=100_000)
    @test reused.reused && reused.comparisons==1
    @test reused.outcome isa Exhausted
    @test verify_quadratic_space_transporter(G,V,W,reused.certificate["input_columns"])
    oracle=Q.v5_extensions(G,W,need,Q.V5Work(12,6);beta=Q.bent_fourier(G),max_kernel=12)
    @test !oracle.capped && !oracle.skipped
    @test as_set(reused.outcome)==Set(Tuple(S) for S in oracle.Ss)
    @test all(S->differential_uniformity(last(Q.function_of(G,S)))==2,
        search_solutions(reused.outcome))

    stopped=cached_v5_extensions!(cache,G,W,need;max_kernel=12,max_x=0,
        max_pairs=1,equivalence_seconds=0)
    @test !stopped.reused && stopped.outcome isa BudgetHit
    @test stopped.certificate===nothing && length(cache.entries)==1
    empty_cache=V5CompletionCache()
    interrupted=cached_v5_extensions!(empty_cache,G,V,need;max_kernel=12,max_x=0)
    @test interrupted.outcome isa BudgetHit
    @test isempty(empty_cache.entries)
    external=cached_v5_extensions!(empty_cache,G,V,need;should_stop=()->true)
    @test external.outcome isa BudgetHit
    @test external.outcome.where_it_stopped.reason==:external
    @test isempty(empty_cache.entries)
    @test_throws ArgumentError V5CompletionCache(max_entries=0)
    @test_throws ArgumentError cached_v5_extensions!(cache,G,V,need;max_pairs=-1)
    @test_throws ArgumentError cached_v5_extensions!(cache,G,V[1:2],need)
end
