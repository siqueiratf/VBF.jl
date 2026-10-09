@testitem "bounded_switching_neighbors" begin
    using Test
    using VBF

    F = SBox{4}(gf_monomial_lut(4, 3))
    legacy_events = Tuple{Symbol,Any}[]
    grouped = switching_neighbors(F; observer = (event, value) ->
        push!(legacy_events, (event, value)))
    expected = reduce(vcat, grouped; init = typeof(F)[])
    @test !isempty(expected)

    @testset "complete enumeration and observer compatibility" begin
        bounded_events = Tuple{Symbol,Any}[]
        result = switching_neighbors_bounded(
            F; max_evaluations = typemax(Int), timeout_seconds = Inf,
            observer = (event, value) -> push!(bounded_events, (event, value)),
        )
        @test result isa Exhausted
        @test search_solutions(result) == expected
        @test bounded_events == legacy_events
        @test nodes_visited(result) == count(e -> e[1] === :candidate, legacy_events)
        @test elapsed_seconds(result) >= 0
        @test search_region(result).kind === :switching_neighbors
    end

    @testset "partial solutions retain only verified neighbours" begin
        for cap in (1, 2, length(expected))
            observed = typeof(F)[]
            result = switching_neighbors_bounded(
                F; max_evaluations = typemax(Int), timeout_seconds = Inf,
                max_neighbors = cap,
                observer = (event, value) -> event === :apn && push!(observed, value),
            )
            @test result isa BudgetHit
            @test result.where_it_stopped.reason === :solutions
            @test search_solutions(result) == expected[1:cap] == observed
            @test !proves_emptiness(result)
            for G in search_solutions(result)
                @test differential_uniformity(G) <= 2
                differences = unique(G.lut .⊻ F.lut)
                @test length(filter(!iszero, differences)) == 1
            end
        end
        for cap in (1, 2, 3)
            result = switching_neighbors_bounded(
                F; max_evaluations = cap, timeout_seconds = Inf,
            )
            @test result isa BudgetHit
            @test result.where_it_stopped.reason === :nodes
            @test nodes_visited(result) == cap
            @test search_solutions(result) == expected[1:length(search_solutions(result))]
            @test all(G -> differential_uniformity(G) <= 2, search_solutions(result))
            @test result.where_it_stopped.resume_key["stage"] === :candidate
            @test result.where_it_stopped.resume_key["direction"] > 0
        end
    end

    @testset "zero budgets and invalid arguments" begin
        for kwargs in ((max_evaluations = 0,), (max_neighbors = 0,),
                       (timeout_seconds = 0,))
            events = Symbol[]
            result = switching_neighbors_bounded(
                F; kwargs..., observer = (event, _) -> push!(events, event),
            )
            @test result isa BudgetHit
            @test isempty(search_solutions(result))
            @test nodes_visited(result) == 0
            @test isempty(events)
            @test result.where_it_stopped.resume_key["stage"] === :validation
        end
        for kwargs in ((max_evaluations = -1,), (max_neighbors = -1,),
                       (timeout_seconds = -1,), (timeout_seconds = -Inf,),
                       (timeout_seconds = NaN,))
            @test_throws ArgumentError switching_neighbors_bounded(F; kwargs...)
        end
        nonapn = SBox{4}(collect(UInt8(0):UInt8(15)))
        @test_throws ArgumentError switching_neighbors_bounded(nonapn)
        @test switching_neighbors_bounded(nonapn; max_evaluations = 0) isa BudgetHit
    end

    @testset "deadline covers construction before candidate enumeration" begin
        # This complete constraint system cannot fit in a one-millisecond
        # budget. The deadline must stop construction, rather than wait for
        # the first candidate evaluation to check the clock.
        larger = SBox{7}(gf_monomial_lut(7, 3))
        result = switching_neighbors_bounded(larger; timeout_seconds = 0.001)
        @test result isa BudgetHit
        @test result.where_it_stopped.reason === :time
        @test nodes_visited(result) == 0
        @test isempty(search_solutions(result))
        @test result.where_it_stopped.resume_key["stage"] in
            (:validation, :removed_solutions, :constraints, :kernel)
    end

    @testset "large switching kernels cannot overflow into an empty search" begin
        @test VBF._sn_combinations(3) == 1:7
        @test eltype(VBF._sn_combinations(3)) === Int
        for dimension in (63, 64)
            combinations = VBF._sn_combinations(dimension)
            @test first(combinations) == 1
            @test last(combinations) == (big(1) << dimension) - 1
            @test !isempty(combinations)
        end
        # An independent 63-vector Boolean space exercises the actual coset
        # enumeration, without constructing an expensive switching system.
        larger = SBox{7}(gf_monomial_lut(7, 3))
        basis = [BitVector([i == j for i in 1:128]) for j in 1:63]
        for cap in (0, 1)
            evaluated = Ref(0)
            events = Symbol[]
            check = function (stage, direction, position)
                if stage === :candidate
                    evaluated[] >= cap && throw(VBF._SNStopped(
                        StopPoint(:nodes, "synthetic large-kernel candidate cap"),
                    ))
                    evaluated[] += 1
                end
            end
            stopped = try
                VBF._sn_apn_coset(
                    larger, eltype(larger.lut)(1), basis,
                    (event, _) -> push!(events, event), check,
                )
                nothing
            catch err
                err
            end
            @test stopped isa VBF._SNStopped
            @test stopped.point.reason === :nodes
            @test evaluated[] == cap
            @test count(==(:candidate), events) == cap
        end
    end

    @testset "reentrant observer state" begin
        outer_events = Symbol[]
        nested = Ref(false)
        result = switching_neighbors_bounded(
            F; timeout_seconds = Inf, max_neighbors = 1,
            observer = function (event, value)
                push!(outer_events, event)
                if !nested[]
                    nested[] = true
                    inner = switching_neighbors_bounded(F; timeout_seconds = 0)
                    @test inner isa BudgetHit
                    @test nodes_visited(inner) == 0
                end
            end,
        )
        @test nested[]
        @test result isa BudgetHit
        @test search_solutions(result) == expected[1:1]
        @test count(==(:candidate), outer_events) == nodes_visited(result)
        @test count(==(:apn), outer_events) == 1
    end
end
