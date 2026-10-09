@testitem "optimized_subspace_search" begin
    using VBF, Test, Random

    @testset "all small vector sets retain exact ordered bases" begin
        for mask in 0:255, dim in 0:4
            z = UInt32[x for x in 0:7 if !iszero(mask & (1 << x))]
            expected = extract_linear_subspaces(z, dim; max_bits = 3, algorithm = :reference)
            actual = extract_linear_subspaces(z, dim; max_bits = 3, algorithm = :optimized)
            @test actual == expected
            bounded = extract_linear_subspaces_bounded(z, dim; max_bits = 3,
                algorithm = :optimized, max_nodes = typemax(Int), timeout_seconds = Inf)
            @test bounded isa Exhausted
            @test search_solutions(bounded) == expected
        end
        rng = Xoshiro(2025940)
        for width in 4:6, _ in 1:20, dim in 1:width
            z = UInt32[x for x in 0:((1 << width)-1) if rand(rng, Bool)]
            @test extract_linear_subspaces(z, dim; max_bits = width, algorithm = :optimized) ==
                  extract_linear_subspaces(z, dim; max_bits = width, algorithm = :reference)
        end
        # Gaussian binomial coefficients give an independent count oracle.
        for (dim, count) in enumerate((63,651,1395,651,63,1))
            bases = extract_linear_subspaces(UInt32.(1:63), dim;
                max_bits = 6, algorithm = :optimized)
            @test length(bases) == count
            @test bases == extract_linear_subspaces(UInt32.(1:63), dim;
                max_bits = 6, algorithm = :reference)
        end
    end

    @testset "duplicate multiplicity, out-of-width points, and sparse fallback" begin
        sets = (UInt32[7, 1, 1, 0, 2, 3, 8], UInt32[1,2,3,1,2,3],
                UInt32[0x80000000,0x40000000,0xc0000000,1,0x80000001,0x40000001,0xc0000001])
        for z in sets, width in (2,3,32), dim in 0:4
            @test extract_linear_subspaces(z, dim; max_bits = width, algorithm = :optimized) ==
                  extract_linear_subspaces(z, dim; max_bits = width, algorithm = :reference)
        end
    end

    @testset "budgets cannot certify incomplete optimized enumeration" begin
        z = UInt32.(1:15)
        full = extract_linear_subspaces_bounded(z, 2; max_bits = 4,
            algorithm = :optimized, max_nodes = typemax(Int))
        @test full isa Exhausted
        for cap in (0,1,2,10,nodes_visited(full)-1)
            partial = extract_linear_subspaces_bounded(z, 2; max_bits = 4,
                algorithm = :optimized, max_nodes = cap)
            @test partial isa BudgetHit
            @test partial.where_it_stopped.reason == :nodes
            @test nodes_visited(partial) == cap
            bases = search_solutions(partial)
            @test bases == search_solutions(full)[1:length(bases)]
            @test !proves_emptiness(partial)
        end
        exact = extract_linear_subspaces_bounded(z, 2; max_bits = 4,
            algorithm = :optimized, max_nodes = nodes_visited(full))
        @test exact isa Exhausted
        for cap in (0,1,length(search_solutions(full)))
            partial = extract_linear_subspaces_bounded(z, 2; max_bits = 4,
                algorithm = :optimized, max_subspaces = cap, max_nodes = typemax(Int))
            @test partial isa BudgetHit
            @test partial.where_it_stopped.reason == :solutions
            @test search_solutions(partial) == search_solutions(full)[1:cap]
        end
        time_stop = extract_linear_subspaces_bounded(z, 2;
            algorithm = :optimized, timeout_seconds = 0)
        @test time_stop isa BudgetHit
        @test time_stop.where_it_stopped.reason == :time
        positive_time_stop = extract_linear_subspaces_bounded(UInt32.(1:4095), 6;
            max_bits = 12, algorithm = :optimized, timeout_seconds = 0.001,
            max_nodes = typemax(Int))
        @test positive_time_stop isa BudgetHit
        @test positive_time_stop.where_it_stopped.reason == :time
        @test !proves_emptiness(positive_time_stop)
        bucket_impossible = extract_linear_subspaces_bounded(UInt32[4,5,6,7], 2;
            max_bits = 3, algorithm = :optimized, max_nodes = 1)
        @test bucket_impossible isa Exhausted
        @test proves_emptiness(bucket_impossible)
        @test_throws ArgumentError extract_linear_subspaces(z, 2; algorithm = :unknown)
        @test_throws ArgumentError extract_linear_subspaces_bounded(z, 2; algorithm = :unknown)
    end
end
