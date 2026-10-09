@testitem "partition_refinement_groups" begin
    using VBF, Test, Random

    budget() = VBF._PRBudget(time_ns(), 120.0, 10^6, 0, :none)
    compose_perm(p, q) = [p[i] for i in q]
    function closure(gens, n)
        queue = [Tuple(1:n)]
        seen = Set(queue)
        head = 1
        while head <= length(queue)
            p = queue[head]
            for g in gens
                q = Tuple(compose_perm(g, p))
                if !(q in seen)
                    push!(seen, q); push!(queue, q)
                end
            end
            head += 1
        end
        return seen
    end

    @testset "Schreier–Sims against explicit small permutation groups" begin
        rng = Xoshiro(9405)
        for _ in 1:30
            gens = [randperm(rng, 5) for _ in 1:3]
            oracle = closure(gens, 5)
            H, b = VBF._PRPermutationGroup(5), budget()
            for g in gens
                VBF._pr_group_add!(H, g, b)
            end
            @test H.closed && VBF._pr_group_order(H) == length(oracle)
            for p in oracle
                @test VBF._pr_group_contains(H, collect(p))
            end
            for point in 1:5
                K = VBF._pr_group_stabilizer(H, point, b)
                expected = count(p -> p[point] == point, oracle)
                @test VBF._pr_group_order(K) == expected
                @test all(g -> g[point] == point, K.strong)
            end
        end
    end

    @testset "ambient kernel and full group against all AGL(4,2) maps" begin
        functions = (SBox{2}([0,0,0,0]), SBox{2}([3,2,1,0]), SBox{2}([0,0,0,1]))
        graphs = [FunctionGraph(F).packed for F in functions]
        counts = zeros(Int, 3, 2)
        # Enumerate every invertible 4x4 matrix and every translation directly.
        for a in 1:15, b in 1:15, c in 1:15, d in 1:15
            lut = [(x&1 != 0 ? a : 0) ⊻ (x&2 != 0 ? b : 0) ⊻
                   (x&4 != 0 ? c : 0) ⊻ (x&8 != 0 ? d : 0) for x in 0:15]
            length(unique(lut)) == 16 || continue
            ea = a >> 2 == 0 && b >> 2 == 0
            for t in 0:15, i in eachindex(graphs)
                all(p -> (lut[Int(p)+1] ⊻ t) in graphs[i], graphs[i]) || continue
                counts[i,1] += 1
                ea && (counts[i,2] += 1)
            end
        end
        for (i,F) in pairs(functions), (j,relation) in pairs((:ccz,:ea))
            H = partition_refinement_automorphisms(F; relation)
            @test H.complete && H.stop_reason === :none
            @test H.order == counts[i,j] == H.graph_order * H.kernel_order
            ambient = [[Int(A(UInt32(x)))+1 for x in 0:15] for A in H.generators]
            @test length(closure(ambient, 16)) == H.order
            @test all(A -> is_invertible(A) && ccz_equivalent_function(F,A) == F, H.generators)
            if relation === :ea
                @test all(A -> all(v -> v >> 2 == 0, A.linear.cols[1:2]), H.generators)
            end
        end
    end

    @testset "independent graph-action oracle enumerates all eight-point permutations" begin
        # An affine permutation of a finite spanning set exists exactly when
        # its affine GF(2) dependencies are preserved. EA also preserves those
        # of the projected input set. This oracle does not use partial maps.
        function graph_order_oracle(F, ea)
            points = FunctionGraph(F).packed
            rows = UInt32[sum(UInt32(((p >> bit)&1) << (i-1)) for (i,p) in pairs(points))
                          for bit in 0:5]
            push!(rows, 0xff)
            dependencies = kernel_f2(rows; nbits = 8)
            inputdeps = kernel_f2(vcat(rows[4:6], UInt32[0xff]); nbits = 8)
            p, count = collect(1:8), Ref(0)
            function visit(k)
                if k == 9
                    for (relations, shift) in ((dependencies, 0), (ea ? inputdeps : UInt32[], 3))
                        for r in relations
                            image = UInt32(0)
                            for i in 1:8
                                (r >> (i-1))&1 != 0 && (image ⊻= points[p[i]] >> shift)
                            end
                            image == 0 || return
                        end
                    end
                    count[] += 1
                    return
                end
                for j in k:8
                    p[k], p[j] = p[j], p[k]
                    visit(k+1)
                    p[k], p[j] = p[j], p[k]
                end
            end
            visit(1)
            return count[]
        end
        rng = Xoshiro(9406)
        for F in (gold_apn(3,1), random_function_sbox(rng,Val(3)), random_function_sbox(rng,Val(3)))
            for relation in (:ccz,:ea)
                H = partition_refinement_automorphisms(F; relation)
                @test H.complete
                @test H.graph_order == graph_order_oracle(F, relation === :ea)
            end
        end
    end

    @testset "paper Example 2, safe subgroup pruning and shared budgets" begin
        F,G = gold_apn(7,1), gold_apn(7,2)
        H = partition_refinement_automorphisms(G)
        @test H.complete && H.order == 128 * 127 * 7
        result = partition_refinement_equivalence(F,G; automorphisms=H)
        @test result isa Exhausted
        @test nodes_visited(result) == 21 # paper Example 2
        @test !are_ccz_equivalent(F,G;strategy=:partition_refinement,automorphisms=H,on_inconclusive=:throw)
        @test partition_refinement_equivalence(F,G;automorphism_timeout_seconds=1) isa Exhausted
        @test partition_refinement_equivalence(F,G;automorphism_timeout_seconds=1,max_nodes=1) isa BudgetHit
        @test partition_refinement_equivalence(F,G;automorphisms=H,max_memory_bytes=0) isa BudgetHit
        small = gold_apn(3,1)
        partial = partition_refinement_automorphisms(small;max_nodes=1,algorithm=:optimized)
        @test !partial.complete && partial.stop_reason === :nodes
        @test !isempty(partial.generators)
        @test partition_refinement_equivalence(small,small;automorphisms=partial) isa Found
        for (options,reason) in (((max_nodes=0,),:nodes),((timeout_seconds=0,),:time),((max_memory_bytes=0,),:memory))
            stopped = partition_refinement_automorphisms(small;options...)
            @test !stopped.complete && stopped.stop_reason === reason
        end
        @test_throws ArgumentError partition_refinement_automorphisms(small;relation=:invalid)
        @test_throws ArgumentError partition_refinement_equivalence(F,G;automorphism_timeout_seconds=NaN)
        @test_throws ArgumentError partition_refinement_equivalence(small,small;
            automorphisms=[zero_affine_map(6,UInt32)])
        @test_throws ArgumentError partition_refinement_equivalence(SBox{2}([0,0,0,0]),SBox{2}([0,0,0,0]);
            automorphisms=[F2AffineMap(identity_linear_map(4,UInt32),UInt32(1))])
        ccz_group = partition_refinement_automorphisms(SBox{2}([0,0,0,0]))
        @test_throws ArgumentError partition_refinement_equivalence(SBox{2}([0,0,0,0]),SBox{2}([0,0,0,0]);
            relation=:ea,automorphisms=ccz_group)
    end

    @testset "positive certificates and public API group forwarding" begin
        rng = Xoshiro(9407)
        F = random_function_sbox(rng,Val(4))
        inner,outer = random_affine_permutation(rng,Val(4)),random_affine_permutation(rng,Val(4))
        G = SBox{4}([outer(F(inner(x))) ⊻ x for x in 0:15])
        H = partition_refinement_automorphisms(G;relation=:ea)
        @test H.complete
        @test are_ea_equivalent(F,G;automorphisms=H,on_inconclusive=:throw)
        @test are_ccz_equivalent(F,G;automorphisms=H,on_inconclusive=:throw)
        c = ea_equivalence_certificate(F,G;automorphisms=H)
        @test all(c.L1(F(c.A2(x))) ⊻ c.A_drift(x) == G(x) for x in 0:15)
        A = ccz_equivalence_certificate(F,G;automorphisms=H)
        @test ccz_equivalent_function(F,A) == G
        P = random_permutation_sbox(rng,Val(4))
        Q = compositional_inverse(P)
        K = partition_refinement_automorphisms(Q)
        @test K.complete
        @test ccz_equivalent_function(P,ccz_equivalence_certificate(P,Q;automorphisms=K)) == Q
        @test ccz_equivalent_function(P,ccz_equivalence_certificate(P,Q;automorphism_timeout_seconds=1)) == Q
    end
end
