@testitem "bounded_subspace_search" begin
    using VBF
    using Test

    @testset "complete enumeration agrees on every subset of F₂³" begin
        for mask in 0:255
            z = UInt32[x for x in 0:7 if !iszero(mask & (1 << x))]
            for dim in 0:4
                expected = extract_linear_subspaces(z, dim; max_bits = 3)
                result = VBF.extract_linear_subspaces_bounded(
                    z, dim; max_bits = 3, max_nodes = typemax(Int),
                    timeout_seconds = Inf,
                )
                @test result isa Exhausted
                @test search_solutions(result) == expected
                @test proves_emptiness(result) == isempty(expected)
                @test nodes_visited(result) >= 1
                @test elapsed_seconds(result) >= 0
            end
        end
        # Preserve the existing treatment of repeated and out-of-width points.
        z = UInt32[7, 1, 1, 0, 2, 3, 8]
        for dim in 0:3
            result = VBF.extract_linear_subspaces_bounded(z, dim; max_bits = 2)
            @test result isa Exhausted
            @test search_solutions(result) == extract_linear_subspaces(z, dim; max_bits = 2)
        end
    end

    @testset "node budgets include rejected candidates" begin
        z = UInt32[1, 2, 3, 4, 5, 6, 7]
        full = VBF.extract_linear_subspaces_bounded(z, 2; max_bits = 3)
        total_nodes = nodes_visited(full)
        exact = VBF.extract_linear_subspaces_bounded(
            z, 2; max_bits = 3, max_nodes = total_nodes,
        )
        @test exact isa Exhausted
        @test search_solutions(exact) == search_solutions(full)
        for cap in 0:total_nodes-1
            result = VBF.extract_linear_subspaces_bounded(
                z, 2; max_bits = 3, max_nodes = cap,
            )
            @test result isa BudgetHit
            @test result.where_it_stopped.reason == :nodes
            @test nodes_visited(result) == cap
            partial = search_solutions(result)
            @test partial == search_solutions(full)[1:length(partial)]
            @test !proves_emptiness(result)
        end
        # Neither candidate can pass the leading-bit test. Their examination
        # still consumes the budget, rather than bypassing it in a dead loop.
        dead = VBF.extract_linear_subspaces_bounded(
            UInt32[4, 8], 1; max_bits = 2, max_nodes = 2,
        )
        @test dead isa BudgetHit
        @test nodes_visited(dead) == 2
        @test isempty(search_solutions(dead))
        @test !proves_emptiness(dead)
    end

    @testset "solution and time limits preserve partial-result semantics" begin
        z = UInt32[1, 2, 3, 4, 5, 6, 7]
        full = extract_linear_subspaces(z, 2; max_bits = 3)
        for cap in 0:length(full)
            result = VBF.extract_linear_subspaces_bounded(
                z, 2; max_bits = 3, max_subspaces = cap,
            )
            @test result isa BudgetHit
            @test result.where_it_stopped.reason == :solutions
            @test search_solutions(result) == full[1:cap]
            @test !proves_emptiness(result)
        end
        time_stop = VBF.extract_linear_subspaces_bounded(z, 2; timeout_seconds = 0)
        @test time_stop isa BudgetHit
        @test time_stop.where_it_stopped.reason == :time
        @test nodes_visited(time_stop) == 0
        @test isempty(search_solutions(time_stop))
        @test !proves_emptiness(time_stop)
        # An impossible dimension still has many partial branches. A positive
        # deadline must interrupt their enumeration inside the shared DFS.
        dead_branch_timeout = VBF.extract_linear_subspaces_bounded(
            UInt32.(1:127), 8; max_bits = 7, max_nodes = typemax(Int),
            timeout_seconds = 0.001,
        )
        @test dead_branch_timeout isa BudgetHit
        @test dead_branch_timeout.where_it_stopped.reason == :time
        @test isempty(search_solutions(dead_branch_timeout))
        @test !proves_emptiness(dead_branch_timeout)
        # Even the unique zero-dimensional solution has conservative cap semantics.
        zero_dim = VBF.extract_linear_subspaces_bounded(UInt32[], 0; max_subspaces = 1)
        @test zero_dim isa BudgetHit
        @test search_solutions(zero_dim) == [UInt32[]]
        complete_zero = VBF.extract_linear_subspaces_bounded(UInt32[], 0; max_bits = 0)
        @test complete_zero isa Exhausted
        @test search_solutions(complete_zero) == [UInt32[]]
        full_width = VBF.extract_linear_subspaces_bounded(UInt32[typemax(UInt32)], 1)
        @test full_width isa Exhausted
        @test search_solutions(full_width) == [UInt32[typemax(UInt32)]]
    end

    @testset "invalid bounds" begin
        extract = VBF.extract_linear_subspaces_bounded
        @test_throws ArgumentError extract(UInt32[], -1)
        @test_throws ArgumentError extract(UInt32[], 1; max_bits = -1)
        @test_throws ArgumentError extract(UInt32[], 1; max_bits = 33)
        @test_throws ArgumentError extract(UInt32[], 1; max_nodes = -1)
        @test_throws ArgumentError extract(UInt32[], 1; max_subspaces = -1)
        @test_throws ArgumentError extract(UInt32[], 1; timeout_seconds = -1)
        @test_throws ArgumentError extract(UInt32[], 1; timeout_seconds = NaN)
    end
end
