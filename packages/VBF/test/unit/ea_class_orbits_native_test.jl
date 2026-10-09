@testitem "ea_class_orbits_native" begin
    using VBF, Test, Random

    partition(r) = Set(Tuple.(sort.(r.orbits)))
    @testset "native generators reproduce legacy partitions and EA classes" begin
        for n in (4,5)
            F = gold_apn(n,1)
            legacy = ea_class_orbits(F; backend = :ortho_derivative)
            native = ea_class_orbits(F; backend = :partition_refinement,
                timeout_seconds = 30)
            @test native.complete && legacy.complete
            @test native.bases == legacy.bases
            @test partition(native) == partition(legacy)
            @test length(native.orbits) == (n == 4 ? 2 : 3)
            @test native.nauts < legacy.nauts
            @test native.group_order !== nothing
            optimized = ea_class_orbits(F;backend=:partition_refinement,
                automorphisms=native.automorphisms,subspace_algorithm=:optimized,
                timeout_seconds=30)
            @test optimized.complete
            @test optimized.bases == native.bases
            @test partition(optimized) == partition(native)
            result = ea_class_representatives(F; timeout_seconds = 30)
            @test result.complete
            @test length(result.representatives) == length(native.orbits)
            @test length(result.mappings) == length(result.orbit_indices)
            for (G,A,i) in zip(result.representatives,result.mappings,result.orbit_indices)
                @test is_invertible(A)
                @test ccz_equivalent_function(F,A) == G
                # The selected basis is the input projection's Walsh space:
                # high input bits in VBF's graph and dual conventions.
                chosen = result.orbit_result.bases[first(result.orbit_result.orbits[i])]
                actual = transpose(A.linear).cols[(n+1):(2n)]
                @test Set(span_from_basis(actual)) == Set(span_from_basis(chosen))
                @test differential_uniformity(G) == 2
                @test ea_class_orbits(G; backend = :partition_refinement,
                    timeout_seconds = 30).complete
            end
            for i in eachindex(result.representatives), j in (i+1):length(result.representatives)
                r = partition_refinement_equivalence(result.representatives[i],
                    result.representatives[j]; relation = :ea, timeout_seconds = 30)
                @test r isa Exhausted
            end
        end
    end

    @testset "general nonquadratic graphs and partial subgroups" begin
        F = gold_apn(4,1)
        reps = ea_class_representatives(F)
        G = only(filter(f -> algebraic_degree(f) > 2,reps.representatives))
        native = ea_class_orbits(G; backend = :partition_refinement, timeout_seconds = 30)
        @test native.complete && length(native.orbits) == 2
        @test_throws ArgumentError ea_class_orbits(G; backend = :ortho_derivative)
        partial = partition_refinement_automorphisms(F; max_nodes = 0)
        upper = ea_class_orbits(F; backend = :partition_refinement, automorphisms = partial)
        @test !upper.complete && upper.subspaces_complete && upper.actions_complete
        @test !upper.automorphisms_complete
        @test length(upper.orbits) == upper.nspaces > length(reps.representatives)
        H = partition_refinement_automorphisms(F)
        reused = ea_class_orbits(F; backend = :partition_refinement, automorphisms = H)
        @test reused.complete && partition(reused) == partition(reps.orbit_result)
        @test reused.group_order == H.order
        @test reused.automorphisms === H
        # Generator membership alone cannot establish that a supplied group
        # is the full group of this function. This unrelated graph has order 1.
        other = SBox{4}([1,4,4,14,15,1,11,11,4,2,14,13,0,11,3,10])
        wrong_source = partition_refinement_automorphisms(other)
        @test wrong_source.complete && isempty(wrong_source.generators)
        unbound = AutomorphismGroupResult{8}(H.relation,H.generators,H.complete,
            H.stop_reason,H.order,H.graph_order,H.kernel_order,H.nodes_visited,H.elapsed_seconds)
        for supplied in (wrong_source,unbound)
            r = ea_class_orbits(F; backend = :partition_refinement, automorphisms = supplied)
            @test !r.complete && !r.automorphisms_complete
            @test r.subspaces_complete && r.actions_complete && r.stop_reason == :subgroup
            @test length(r.orbits) >= length(reps.representatives)
        end
        legacy_small = ea_class_orbits(gold_apn(3,1))
        @test !legacy_small.complete && legacy_small.stop_reason == :subgroup
        plain = ea_class_representatives(F; prefer_permutations = false, automorphisms = H)
        @test plain.complete
        @test all(ccz_equivalent_function(F,A) == G for (G,A) in zip(plain.representatives,plain.mappings))
        @test ea_class_orbits(SBox{2}([0,0,0,0]); backend = :partition_refinement).complete
    end

    @testset "limits and invalid supplied actions cannot certify a census" begin
        F = gold_apn(4,1)
        for kwargs in ((max_nodes = 0,), (timeout_seconds = 0,),
                       (max_subspaces = 0,), (max_memory_bytes = 0,))
            r = ea_class_orbits(F; backend = :partition_refinement, kwargs...)
            @test !r.complete && !r.subspaces_complete && isempty(r.bases)
            @test !ea_class_representatives(F; kwargs...).complete
        end
        limited = ea_class_orbits(F; backend = :partition_refinement, max_subspaces = 1)
        @test !limited.complete && !limited.subspaces_complete
        @test limited.stop_reason == :solutions && length(limited.bases) == 1
        for kwargs in ((max_nodes = -1,), (timeout_seconds = -1,),
                       (max_subspaces = -1,), (max_memory_bytes = -1,),
                       (backend = :unknown,), (algorithm = :unknown,),
                       (subspace_algorithm = :unknown,))
            @test_throws ArgumentError ea_class_orbits(F; kwargs...)
        end
        wrong_width = partition_refinement_automorphisms(gold_apn(3,1))
        @test_throws ArgumentError ea_class_orbits(F; backend = :partition_refinement,
            automorphisms = wrong_width)
        bad = AutomorphismGroupResult{8}(:ccz,
            [F2AffineMap(identity_linear_map(8,UInt32),UInt32(1))],
            true,:none,BigInt(1),BigInt(1),BigInt(1),0,0.0)
        @test_throws ArgumentError ea_class_orbits(F; backend = :partition_refinement,
            automorphisms = bad)
        ea_group = partition_refinement_automorphisms(F; relation = :ea)
        @test !ea_class_orbits(F; backend = :partition_refinement,
            automorphisms = ea_group).complete
        H = partition_refinement_automorphisms(F)
        # Extraction is capped before allocating all bases, not after it.
        per_space = (16 << 4) + 4*4 + 256
        memory = ea_class_orbits(F; backend = :partition_refinement,
            automorphisms = H, max_memory_bytes = (16 << 8) + 2per_space)
        @test memory.stop_reason == :memory && !memory.complete
        @test !memory.subspaces_complete && length(memory.bases) == 2
        # Exhaust extraction and span creation, then interrupt orbit actions.
        spaces = extract_linear_subspaces_bounded(walsh_zeroes(F),4;
            max_bits = 8, max_nodes = typemax(Int), timeout_seconds = Inf)
        stopped = ea_class_orbits(F; backend = :partition_refinement, automorphisms = H,
            max_nodes = nodes_visited(spaces) + length(search_solutions(spaces)) + 1)
        @test stopped.subspaces_complete && !stopped.actions_complete && !stopped.complete
        @test stopped.stop_reason == :nodes
    end
end
