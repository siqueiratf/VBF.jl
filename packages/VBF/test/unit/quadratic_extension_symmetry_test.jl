@testitem "quadratic extension subgroup orbits preserve all original outputs" begin
    using VBF, Test
    Q = VBF.QuadraticExtensions
    G = Q.geometry(4)
    V = UInt32[0x21] # x1*x2 + x3*x4
    beta = Q.bent_fourier(G)
    generators = [UInt16[2,1,4,8], UInt16[1,2,8,4], UInt16[4,8,1,2]]

    # Independent control: enumerate all 4-spaces in Alt(4), select those
    # containing V and check APN directly from every differential.
    brute = Set{Vector{UInt32}}()
    for S in Q.each_rref(G.N, G.n)
        first(Q.rref(vcat(S, V))) == S || continue
        differential_uniformity(last(Q.function_of(G, S))) == 2 || continue
        push!(brute, S)
    end
    @test length(brute) == 20
    for need in 0:2
        plain_events = Dict{Int,Any}()
        plain = Q.v5_extensions(G, V, need, Q.V5Work(5,4); beta,
            coset_observer=event->(plain_events[event.index]=event))
        orbit_events = Any[]
        reduced = v5_extensions_by_symmetry(G, V, need, Q.V5Work(5,4); beta,
            generators, coset_observer=event->push!(orbit_events,event))
        @test plain.Ss == reduced.Ss == brute
        @test reduced.complete
        @test !reduced.capped
        @test reduced.nX_covered == reduced.nX == length(plain_events)
        @test reduced.nX_searched == reduced.n_orbits < reduced.nX
        @test reduced.ncand < plain.ncand
        @test length(orbit_events) == reduced.nX
        @test [e.index for e in orbit_events] == collect(1:reduced.nX)
        @test any(e->e.replayed, orbit_events)
        for event in orbit_events
            original = plain_events[event.index]
            @test event.Ss == original.Ss
            @test event.representative == original.representative
            @test event.coverage_complete
            @test verify_quadratic_space_transporter(G, V, V, event.input_columns)
            source = plain_events[event.source_index]
            @test verify_quadratic_space_transporter(G, vcat(V,source.representative),
                vcat(V,event.representative),event.input_columns)
            @test event.capped == original.capped
        end
    end
end

@testitem "quadratic extension orbit certificates reject unsafe inputs" begin
    using VBF, Test
    Q = VBF.QuadraticExtensions
    G = Q.geometry(4)
    V = UInt32[0x21]
    all_cosets = UInt32.(1:31)
    generators = [UInt16[2,1,4,8], UInt16[4,8,1,2]]
    plan = quadratic_extension_orbits(G,V,all_cosets,generators)
    @test length(plan.representatives) < length(all_cosets)
    @test_throws ArgumentError quadratic_extension_orbits(G,V,all_cosets,[UInt16[1,1,4,8]])
    @test_throws ArgumentError quadratic_extension_orbits(G,V,all_cosets,[UInt16[4,2,1,8]])
    @test_throws ArgumentError quadratic_extension_orbits(G,V,all_cosets,[UInt16[1,2,4,16]])
    @test_throws ArgumentError quadratic_extension_orbits(G,V,UInt32[0],generators)
    @test_throws ArgumentError quadratic_extension_orbits(G,V,UInt32[32],generators)
    @test_throws ArgumentError quadratic_extension_orbits(G,V,UInt32[1,1],generators)
    nontrivial = findfirst(i->plan.representative_of[i]!=i,eachindex(all_cosets))
    @test nontrivial !== nothing
    @test_throws ArgumentError quadratic_extension_orbits(G,V,
        UInt32[all_cosets[nontrivial]],generators)
    @test_throws ArgumentError transport_quadratic_extension_orbit(G,plan,nontrivial,
        Vector{UInt32}[])
    @test_throws ArgumentError transport_quadratic_extension_orbit(G,plan,first(plan.representatives),
        [UInt32[0x21]])
    identity_plan = quadratic_extension_orbits(G,V,all_cosets,Vector{UInt16}[])
    @test identity_plan.representatives == collect(eachindex(all_cosets))
    @test all(i->quadratic_extension_orbit_witness(identity_plan,i)==UInt16[1,2,4,8],
        eachindex(all_cosets))
    beta=Q.bent_fourier(G)
    ordinary=Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta)
    identity_events=Any[]
    identity_search=v5_extensions_by_symmetry(G,V,1,Q.V5Work(5,4);beta,
        generators=Vector{UInt16}[],coset_observer=e->push!(identity_events,e))
    @test identity_search.Ss == ordinary.Ss
    @test identity_search.ncand == ordinary.ncand
    @test identity_search.complete
    @test identity_search.nX_searched == identity_search.nX_covered == ordinary.nX
    @test all(e->!e.replayed && e.next_x===nothing,identity_events)
end

@testitem "quadratic extension symmetry preserves caps and interruption" begin
    using VBF, Test
    Q = VBF.QuadraticExtensions
    G = Q.geometry(4); V=UInt32[0x21]; beta=Q.bent_fourier(G)
    generators = [UInt16[2,1,4,8],UInt16[1,2,8,4],UInt16[4,8,1,2]]
    capped_events = Any[]
    capped = v5_extensions_by_symmetry(G,V,1,Q.V5Work(5,4);beta,generators,
        max_kernel=0,coset_observer=e->push!(capped_events,e))
    @test capped.capped
    @test !capped.complete
    @test capped.nX_covered < capped.nX
    @test any(e->e.capped && !e.coverage_complete,capped_events)
    stopped = v5_extensions_by_symmetry(G,V,1,Q.V5Work(5,4);beta,generators,
        should_stop=()->true)
    @test !stopped.complete
    @test stopped.nX_searched == stopped.nX_covered == 0
    @test isempty(stopped.Ss)
    # Subset selection is visibly partial, cannot act as a sequential cursor,
    # and observes original rather than renumbered coset indices.
    events = Any[]
    selected = Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,
        selected_coset_indices=[2,5],coset_observer=e->push!(events,e))
    @test selected.selected_scope
    @test selected.selected_coset_indices == [2,5]
    @test selected.next_x === nothing
    @test [e.index for e in events] == [2,5]
    @test all(e->e.next_x===nothing,events)
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,
        selected_coset_indices=[1],start_x=2)
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,
        selected_coset_indices=[1],max_x=1)
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,
        selected_coset_indices=[2,1])
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,
        selected_coset_indices=[1,1])
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(5,4);beta,
        selected_coset_indices=[16])
end

@testitem "quadratic space stabilizer discovery is verified and bounded" begin
    using VBF, Test
    Q=VBF.QuadraticExtensions
    G=Q.geometry(4);V=UInt32[0x21]
    result=quadratic_space_stabilizers(G,V;max_nodes=10_000,timeout_seconds=20.0)
    @test result.complete
    @test !isempty(result.generators)
    @test all(A->A!=UInt16[1,2,4,8],result.generators)
    @test all(A->verify_quadratic_space_transporter(G,V,V,A),result.generators)
    reduced=v5_extensions_by_symmetry(G,V,1,Q.V5Work(5,4);
        beta=Q.bent_fourier(G),generators=result.generators)
    @test reduced.complete
    @test reduced.n_orbits < reduced.nX
    nodes=quadratic_space_stabilizers(G,V;max_nodes=0,timeout_seconds=20.0)
    @test !nodes.complete
    @test nodes.stop_reason == :nodes
    time=quadratic_space_stabilizers(G,V;timeout_seconds=0.0)
    @test !time.complete
    @test time.stop_reason == :time
    memory=quadratic_space_stabilizers(G,V;max_memory_bytes=0,timeout_seconds=20.0)
    @test !memory.complete
    @test memory.stop_reason == :memory
    @test_throws ArgumentError quadratic_space_stabilizers(G,V;max_nodes=-1)
    @test_throws ArgumentError quadratic_space_stabilizers(G,V;timeout_seconds=-1)
end
