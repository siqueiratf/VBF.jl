@testitem "bounded_switching_neighbors" begin
    using Test
    using VBF

    F = SBox{4}(gf_monomial_lut(4, 3))
    legacy_events = Tuple{Symbol,Any}[]
    grouped = switching_neighbors(F; observer = (event, value) ->
        push!(legacy_events, (event, value)))
    expected = reduce(vcat, grouped; init = typeof(F)[])
    @test !isempty(expected)

    @testset "equation scratch never aliases retained pivots or removed solutions" begin
        system=VBF._sn_system(8);other=VBF._sn_system(8)
        scratch=system.equation_row
        @test scratch !== other.equation_row
        VBF._sn_add_equation!(system,(0,1))
        first_pivot=only(system.pivot_rows)
        @test first_pivot !== scratch
        @test first_pivot==BitVector([true,true,false,false,false,false,false,false])
        VBF._sn_add_equation!(system,(1,2))
        @test system.pivot_cols==[1,2]
        @test system.pivot_rows[2]==BitVector([false,true,true,false,false,false,false,false])
        retained=copy.(system.pivot_rows)
        for positions in ((0,2),(0,1),(2,2,5,5),())
            # The first equation is the sum of the two stored equations; the
            # others are duplicate or identically zero, including cancellations.
            VBF._sn_add_equation!(system,positions)
            @test system.pivot_rows==retained
            @test system.pivot_cols==[1,2]
            @test system.equation_row===scratch
        end
        VBF._sn_remove_solution!(system,(0,3,7))
        removed=copy(only(system.removed))
        @test only(system.removed)!==scratch
        fill!(scratch,true)
        VBF._sn_add_equation!(system,())
        @test !any(scratch)
        @test system.pivot_rows==retained
        @test only(system.removed)==removed
        VBF._sn_add_equation!(system,(3,4))
        @test system.pivot_cols==[1,2,4]
        @test system.pivot_rows[1]===first_pivot
        @test system.pivot_rows[1:2]==retained
        @test all(row->row!==scratch,system.pivot_rows)
        @test all(i==j || system.pivot_rows[i]!==system.pivot_rows[j]
            for i in eachindex(system.pivot_rows), j in eachindex(system.pivot_rows))
        VBF._sn_add_equation!(other,(7,))
        @test system.pivot_rows[1:2]==retained
        @test only(system.removed)==removed
    end

    @testset "specialized constraint callbacks preserve order, stops and nested searches" begin
        q=length(F.lut)
        reference=[VBF._sn_system(q) for _ in 1:q-1]
        trace=Any[]
        VBF._sn_constraints!(reference,F.lut,(stage,direction,position)->push!(trace,(stage,direction,position)))
        nested=Ref(false);nested_trace=Any[]
        systems=[VBF._sn_system(q) for _ in 1:q-1]
        callback=function(stage,direction,position)
            push!(nested_trace,(stage,direction,position))
            if !nested[] && position isa Tuple
                nested[]=true
                inner=switching_neighbors_bounded(gold_apn(3);timeout_seconds=Inf)
                @test inner isa Exhausted
            end
        end
        VBF._sn_constraints!(systems,F.lut,callback)
        @test nested[]
        @test nested_trace==trace
        @test [s.pivot_cols for s in systems]==[s.pivot_cols for s in reference]
        @test [s.pivot_rows for s in systems]==[s.pivot_rows for s in reference]
        @test [VBF._sn_kernel(s) for s in systems]==[VBF._sn_kernel(s) for s in reference]
        sentinel=ErrorException("constraint callback stop")
        prefix=Any[];partial=[VBF._sn_system(q) for _ in 1:q-1]
        stopped=try
            VBF._sn_constraints!(partial,F.lut,(stage,direction,position)->begin
                push!(prefix,(stage,direction,position))
                length(prefix)==17 && throw(sentinel)
            end)
            nothing
        catch err
            err
        end
        @test stopped===sentinel
        @test prefix==trace[1:17]
        # The callback interrupts before adding the current flat; completed
        # pivot rows remain disjoint from scratch even at this early frontier.
        @test all(row!==s.equation_row for s in partial for row in s.pivot_rows)
    end

    @testset "persisted candidate cursor resumes exactly once" begin
        direction, combination = Ref(1), Ref(big(1))
        visits = Tuple{Int,BigInt}[]
        collected = typeof(F)[]
        checkpoint = function (event,value)
            if event === :candidate_complete
                push!(visits,(value.direction,BigInt(value.combination)))
                value.apn && push!(collected,value.candidate)
            end
            if event in (:candidate_complete,:direction_complete)
                direction[],combination[] = value.next_direction,BigInt(value.next_combination)
            end
        end
        for _ in 1:(length(expected)+20)
            r = switching_neighbors_bounded(F;max_evaluations=1,timeout_seconds=Inf,
                start_direction=direction[],start_combination=combination[],checkpoint)
            r isa Exhausted && break
        end
        @test collected == expected
        @test length(visits) == length(unique(visits)) == length(expected)
        @test direction[] == 16 && combination[] == 1
        @test isempty(search_solutions(switching_neighbors_bounded(F;
            start_direction=16,timeout_seconds=Inf)))
        @test_throws ArgumentError switching_neighbors_bounded(F;start_direction=0)
        @test_throws ArgumentError switching_neighbors_bounded(F;start_direction=17)
        @test_throws ArgumentError switching_neighbors_bounded(F;start_combination=0)
        @test_throws ArgumentError switching_neighbors_bounded(F;start_direction=16,start_combination=2)
    end

    @testset "cooperative external stop" begin
        stopped=switching_neighbors_bounded(F;stop_requested=()->true)
        @test stopped isa BudgetHit
        @test stopped.where_it_stopped.reason==:external
        @test nodes_visited(stopped)==0
    end

    @testset "one equation per affine two-flat preserves the full system" begin
        using Random
        rng = Xoshiro(82026)
        # Compare with the ordered-pair definition, including nonquadratic
        # tables. Identical pivot rows imply identical kernels and neighbours,
        # not merely matching counts or APN status.
        for n in 3:5, lut in (gold_apn(n).lut, rand(rng, UInt8(0):UInt8((1<<n)-1), 1<<n))
            q = 1 << n
            reference = [VBF._sn_system(q) for _ in 1:(q-1)]
            for a in 1:(q-1), x in 0:(q-1), y in 0:(q-1)
                x == y && continue
                x == (y ⊻ a) && continue
                u = lut[x+1] ⊻ lut[(x⊻a)+1] ⊻ lut[y+1] ⊻ lut[(y⊻a)+1]
                iszero(u) || VBF._sn_add_equation!(reference[Int(u)], (x⊻a,x,y⊻a,y))
            end
            actual = [VBF._sn_system(q) for _ in 1:(q-1)]
            visited = Ref(0)
            check = (_,_,position) -> position isa Tuple && (visited[] += 1)
            VBF._sn_constraints!(actual, lut, check)
            @test visited[] == q*(q-1)*(q-2) ÷ 24
            for u in 1:(q-1)
                @test actual[u].pivot_cols == reference[u].pivot_cols
                @test actual[u].pivot_rows == reference[u].pivot_rows
                @test VBF._sn_kernel(actual[u]) == VBF._sn_kernel(reference[u])
            end
        end
    end

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

    @testset "optional per-direction diagnostics" begin
        diagnostics = Tuple{Symbol,Any}[]
        events = Tuple{Symbol,Any}[]
        result = switching_neighbors_bounded(
            F; max_evaluations=typemax(Int), timeout_seconds=Inf,
            observer=(event,value)->push!(events,(event,value)),
            diagnostics=(event,value)->push!(diagnostics,(event,value)),
        )
        @test result isa Exhausted
        @test events == legacy_events
        kernels = [value for (event,value) in diagnostics if event === :kernel]
        directions = [value for (event,value) in diagnostics if event === :direction_complete]
        @test [row.direction for row in kernels] == collect(1:15)
        @test [row.direction for row in directions] == collect(1:15)
        @test all(row -> row.raw_dimension == row.quotient_dimension+row.trivial_dimension,
            kernels)
        @test all(row -> row.trivial_dimension == 8,kernels)
        @test [row.evaluations for row in directions] ==
            [Int((big(1) << row.quotient_dimension)-1) for row in kernels]
        @test [row.neighbors for row in directions] == length.(grouped)
        @test sum(row.evaluations for row in directions) == nodes_visited(result)
        empty!(diagnostics)
        partial = switching_neighbors_bounded(
            F; timeout_seconds=Inf,max_neighbors=1,
            diagnostics=(event,value)->push!(diagnostics,(event,value)),
        )
        @test partial isa BudgetHit
        stop = only([value for (event,value) in diagnostics if event === :stop])
        @test stop.point === partial.where_it_stopped
        @test stop.evaluations == nodes_visited(partial)
        @test stop.neighbors == length(search_solutions(partial)) == 1
        @test all(event !== :direction_complete for (event,_) in diagnostics)
    end

    @testset "all one-coordinate extensions modulo trivial EA changes" begin
        # Independent oracle: solve the inhomogeneous flat equations for an
        # output quotient, by enumerating every Boolean completion on 8 points.
        # This tests coverage, not only the APN status of generated neighbours.
        small = gold_apn(3)
        neighbours = switching_neighbors(small)
        maskof(values) = sum(Int(value) << (x-1) for (x,value) in enumerate(values))
        for direction in 1:7
            output = inv(F2LinearMap{3,UInt8}(
                complete_basis(UInt8[direction],3)))
            transformed = [Int(output(y)) for y in small.lut]
            quotient = transformed .>> 1
            base = maskof(transformed .& 1)
            flats = [(x,y,z,t) for x in 0:7 for y in (x+1):7
                for z in (y+1):7 for t in (z+1):7
                if x ⊻ y ⊻ z ⊻ t == 0 &&
                   quotient[x+1] ⊻ quotient[y+1] ⊻ quotient[z+1] ⊻ quotient[t+1] == 0]
            completions = [bits for bits in 0:255 if all(flat ->
                isodd(sum((bits >> x) & 1 for x in flat)),flats)]
            @test base in completions
            generators = [255;
                [maskof([(x >> bit) & 1 for x in 0:7]) for bit in 0:2];
                [maskof((quotient .>> bit) .& 1) for bit in 0:1]]
            trivial = [0]
            for generator in generators
                append!(trivial,[bits ⊻ generator for bits in copy(trivial)])
                unique!(trivial)
            end
            canonical(bits) = minimum(bits ⊻ change for change in trivial)
            reference = Set(canonical(bits ⊻ base) for bits in completions)
            generated = Set([0])
            for G in neighbours[direction]
                differences = G.lut .⊻ small.lut
                @test all(value -> value in (0,direction),differences)
                push!(generated,canonical(maskof([!iszero(value) for value in differences])))
            end
            @test generated == reference
            for bits in completions
                G = SBox{3}([(quotient[x+1] << 1) | ((bits >> x) & 1) for x in 0:7])
                @test differential_uniformity(G) == 2
            end
        end
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
                    inner = switching_neighbors_bounded(F; timeout_seconds = Inf, max_evaluations = 1)
                    @test inner isa BudgetHit
                    @test nodes_visited(inner) == 1
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
