@testitem "quadratic component subspace buffers preserve counts and order" begin
    using VBF, Test, Random
    Q = VBF.QuadraticExtensions
    rng = MersenneTwister(0xb0ffe2)
    planes = [[1, 2, 3], [2, 5, 7], [1, 6, 7], [3, 5, 6],
              [1, 4, 5], [3, 4, 7], [2, 4, 6]]
    comp = UInt32[0x19, 0x2a, 0x43, 0x81, 0x128, 0x213, 0x324, 0x435]
    @test Q.each_rref(3, 1) == [UInt32[x] for x in (4, 5, 6, 7, 2, 3, 1)]
    @test Q.each_rref(0, 0) == [UInt32[]]
    @test Q.max_bent_dim(UInt32[0], falses(1), 0) == (0, 1)
    @test only(Q.subspaces_of_comp(UInt32[0], trues(1), 0; keep=iszero)).els == Int[]

    for mask in 0:255
        bent = BitVector([!iszero(mask & (1 << b)) for b in 0:7])
        counts = [count(b -> bent[b+1], plane) for plane in planes]
        best = maximum(counts)
        @test Q.max_bent_dim(comp, bent, 2) == (best, count(==(best), counts))
        calls = Int[]
        selected = Q.subspaces_of_comp(comp, bent, 2; keep=n -> (push!(calls, n); iseven(n)))
        @test calls == counts
        @test [V.els for V in selected] == planes[findall(iseven, counts)]
        for V in selected
            @test V.forms == [comp[Int(b)+1] for b in V.bbasis]
            @test Q.rref(UInt32.(V.els))[1] == V.bbasis
        end
    end

    for m in 1:6, k in 0:m
        components = rand(rng, UInt32, 1 << m)
        total = Int(Q.gauss_binom(m, k))
        @test length(Q.each_rref(m, k)) == total
        @test Q.max_bent_dim(components, falses(1 << m), k) == (0, total)
        @test Q.max_bent_dim(components, trues(1 << m), k) == ((1 << k)-1, total)
        singleton = falses(1 << m); singleton[2] = true
        expected = k == 0 ? (0, 1) : (1, Int(Q.gauss_binom(m-1, k-1)))
        @test Q.max_bent_dim(components, singleton, k) == expected
        none_calls = Ref(0)
        @test isempty(Q.subspaces_of_comp(components, singleton, k;
            keep=n -> (none_calls[] += 1; false)))
        @test none_calls[] == total
    end

    components = rand(rng, UInt32, 64)
    bent = BitVector(rand(rng, Bool, 64))
    spaces = Q.subspaces_of_comp(components, bent, 2; keep=n -> true)
    @test length(spaces) == Q.gauss_binom(6, 2)
    @test length(Set(Tuple(V.els) for V in spaces)) == length(spaces)
    for V in spaces
        @test issorted(V.els) && length(V.els) == 3
        @test xor(V.els[1], V.els[2]) == V.els[3]
        @test V.nbent == count(b -> bent[b+1], V.els)
    end
    maximum_bent = maximum(V.nbent for V in spaces)
    @test Q.max_bent_dim(components, bent, 2) ==
        (maximum_bent, count(V -> V.nbent == maximum_bent, spaces))
end

@testitem "quadratic cached subspaces retain ownership under concurrent reuse" begin
    using VBF, Test
    Q = VBF.QuadraticExtensions
    comp = UInt32.(0:127)
    bent = trues(128)
    tasks = [Threads.@spawn Q.max_bent_dim(comp, bent, 4) for _ in 1:8]
    @test all(==((15, Int(Q.gauss_binom(7, 4)))) , fetch.(tasks))
    expected = Q.subspaces_of_comp(UInt32.(0:7), trues(8), 2; keep=n -> true)
    changed = Q.subspaces_of_comp(UInt32.(0:7), trues(8), 2; keep=n -> true)
    fill!(changed[1].els, -1)
    fill!(changed[1].bbasis, UInt32(0))
    fill!(changed[1].forms, UInt32(0))
    @test changed[2:end] == expected[2:end]
    @test Q.subspaces_of_comp(UInt32.(0:7), trues(8), 2; keep=n -> true) == expected
    public_rows = Q.each_rref(3, 1)
    fill!(public_rows[1], UInt32(0))
    @test Q.each_rref(3, 1) == [UInt32[x] for x in (4, 5, 6, 7, 2, 3, 1)]
    @test Q.subspaces_of_comp(UInt32.(0:7), trues(8), 2; keep=n -> true) == expected
    @test Q._cached_component_kernels(9, 6) === nothing
    @test Q._cached_component_kernels(8, 4) === nothing
    cached = Q._cached_component_kernels(8, 5)
    @test length(cached) == 97_155
    @test eltype(cached) == NTuple{4,UInt64}
    @test all(kernel -> sum(count_ones, kernel) == 31, cached)
    @test all(kernel -> iszero(first(kernel) & UInt64(1)), cached)
    @test Base.summarysize(cached) < 3_200_000
end

@testitem "quadratic V5 scratch clears and resizes between calls" begin
    using VBF, Test
    Q = VBF.QuadraticExtensions
    cnt = Int32[]; transform = Int16[]; points = zeros(Int, 64)
    work = Q.V5Work(cnt, transform, points)
    @test work.cnt === cnt && work.g5 === transform && work.pts === points
    @test isempty(work.flat_histogram) && isempty(work.bitmap)
    histogram = Int[]; bitmap = UInt64[]
    extended = Q.V5Work(cnt, transform, points, histogram, bitmap)
    @test extended.cnt === cnt && extended.g5 === transform && extended.pts === points
    @test extended.flat_histogram === histogram && extended.bitmap === bitmap
    @test extended.du7 !== work.du7
    converted = Q.V5Work([1], [2], [3])
    @test converted.cnt == Int32[1] && converted.cnt isa Vector{Int32}
    @test converted.g5 == Int16[2] && converted.g5 isa Vector{Int16}
    @test converted.pts == [3] && converted.pts isa Vector{Int}
    converted_extended = Q.V5Work([1], [2], [3], Int32[4], UInt32[5])
    @test converted_extended.flat_histogram == [4] && converted_extended.flat_histogram isa Vector{Int}
    @test converted_extended.bitmap == UInt64[5] && converted_extended.bitmap isa Vector{UInt64}
    G6 = Q.geometry(6); beta6 = Q.bent_fourier(G6)
    G4 = Q.geometry(4); beta4 = Q.bent_fourier(G4)
    cases = ((G6, UInt32[1, 2, 4], beta6), (G4, UInt32[1], beta4),
             (G6, UInt32[1, 4, 16], beta6))
    retained = Any[]
    for (G, basis, beta) in cases, du7_filter in (:none, :bitsets)
        fill!(work.bitmap, typemax(UInt64))
        fill!(work.flat_histogram, -1)
        actual_events = Any[]; expected_events = Any[]
        counts = Int32[]
        preparation = Q.coset_bent_counts!(counts, G, basis, beta)
        need = maximum(counts) ÷ preparation.scale
        kwargs = (; beta, max_x=1, max_kernel=0, du7_filter)
        actual = Q.v5_extensions(G, basis, need, work; kwargs...,
            coset_observer=e -> push!(actual_events, e))
        expected = Q.v5_extensions(G, basis, need, Q.V5Work(G.N-length(basis), G.n);
            kwargs..., coset_observer=e -> push!(expected_events, e))
        @test actual == expected
        @test actual_events == expected_events
        @test length(work.bitmap) == max(1, (1 << (G.N-length(basis))) >> 6)
        G.n == 6 && @test length(work.flat_histogram) == 65_536
        G.n == 4 && du7_filter == :bitsets && @test Q._du7_workspace_bytes(work.du7) > 0
        for (previous, snapshot) in retained
            @test previous == snapshot
        end
        push!(retained, (actual, deepcopy(actual)))
    end
end

@testitem "packet constraint priorities preserve flat pairing and canonical affine kernels" begin
    using VBF, Test, Random
    Q=VBF.QuadraticExtensions
    constraints=UInt32[1,4,3,2,12,8,5,0,6,4]
    indices=collect(101:110)
    Q._v5_order_constraints!(constraints,indices)
    @test constraints==UInt32[0,8,4,4,12,2,6,1,3,5]
    @test indices==[108,106,102,110,105,104,109,101,103,107]
    @test Q._v5_order_constraints!(UInt32[],Int[])===nothing
    rng=MersenneTwister(0x501ae2)
    rows=UInt32[];pivots=Int[];kernel=UInt32[]
    for D in (1,5,12,23,31),_ in 1:30
        rank_dimension=max(1,D-3)
        mask=(UInt32(1)<<rank_dimension)-UInt32(1)
        solution=rand(rng,UInt32)|UInt32(1)
        original=UInt32[c for c in rand(rng,UInt32,120).&mask if Q.par(c&solution)]
        reordered=copy(original);indices=collect(eachindex(original))
        Q._v5_order_constraints!(reordered,indices)
        @test reordered==original[indices]
        @test sort(indices)==collect(eachindex(original))
        for t in (UInt32(0),rand(rng,UInt32)&((UInt32(1)<<D)-UInt32(1)))
            selected=filter(c->!Q.par(c&t),original)
            expected=isempty(selected) ? nothing : Q.solve_ones(selected,D)
            actual=Q._solve_ones_annihilating(reordered,t,D,rows,pivots,kernel)
            @test actual==expected
            if actual!==nothing
                v0,K=actual
                @test length(K)>=D-rank_dimension
                @test all(c->Q.par(c&v0),selected)
                @test all(k->all(c->!Q.par(c&k),selected),K)
            end
        end
    end
end

@testitem "V5 observer emission preserves concrete fields and callback behavior" begin
    using VBF, Test
    Q=VBF.QuadraticExtensions
    empty_spaces=Q._EmptyCompletionSpaces()
    spaces=Set([UInt32[1,2,4]])
    retained=Any[]
    observer=event->push!(retained,event)
    for next_x in (nothing,1002),Ss in (empty_spaces,spaces)
        @test Q._v5_emit_coset(observer,1001,next_x,2000,UInt32(73),Ss,1,20,3,true)===nothing
        event=last(retained)
        @test event==(;index=1001,next_x,total_x=2000,representative=UInt32(73),
                      Ss,du_reject=1,ncand=20,nT=3,capped=true)
        @test event.Ss===Ss
        @test isconcretetype(typeof(event))
        @test fieldtype(typeof(event),:next_x)===typeof(next_x)
        @test fieldtype(typeof(event),:Ss)===typeof(Ss)
    end
    @test length(retained)==4
    failure=ErrorException("observer interruption")
    caught=try
        Q._v5_emit_coset(_->throw(failure),1,2,2,UInt32(0),empty_spaces,0,0,0,false)
    catch error
        error
    end
    @test caught===failure
end

@testitem "V5 nonretaining observer does not box every event" begin
    using VBF, Test
    Q=VBF.QuadraticExtensions
    # Test items run at module scope; capture typed local Refs in this callback.
    let events=Ref(0),fields=Ref(UInt64(0))
        observer=event->begin
            events[]+=1
            fields[]+=UInt64(event.index+event.total_x+event.du_reject+event.ncand+event.nT)+
                      UInt64(event.representative)+UInt64(event.capped)
            event.next_x===nothing || (fields[]+=UInt64(event.next_x))
            fields[]+=UInt64(length(event.Ss))
            nothing
        end
        function emit_many(observer::F,empty_spaces,spaces,count) where F
            for index in 1:count
                next_x=iseven(index) ? nothing : index+1
                # Keep pre-existing Set wrappers out of a boxing union join.
                if index%3==0
                    VBF.QuadraticExtensions._v5_emit_coset(observer,index,next_x,count,UInt32(index),spaces,
                                    index%2,index%17,index%5,isodd(index))
                else
                    VBF.QuadraticExtensions._v5_emit_coset(observer,index,next_x,count,UInt32(index),empty_spaces,
                                    index%2,index%17,index%5,isodd(index))
                end
            end
            nothing
        end
        empty_spaces=Q._EmptyCompletionSpaces();spaces=Set([UInt32[1,2,4]])
        # Warm the same measurement path used by the allocation guard.
        @allocated emit_many(observer,empty_spaces,spaces,10_000)
        before=events[]
        @test (@allocated emit_many(observer,empty_spaces,spaces,10_000))<4096
        @test events[]-before==10_000
        @test fields[]>0
    end
end
