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
