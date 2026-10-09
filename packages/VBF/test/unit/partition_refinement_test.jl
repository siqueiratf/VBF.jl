@testitem "partition_refinement" begin
    using VBF, Test, Random

    @testset "all two-bit functions: independent affine-span classification" begin
        affine = SBox{2}(UInt8[0, 1, 2, 3])
        nonlinear = SBox{2}(UInt8[0, 0, 0, 1])
        # Four distinct points are either an affine plane (xor = 0) or an
        # affine-independent set. These are exactly the two AGL(4,2) orbits.
        for code in 0:255
            F = SBox{2}(UInt8[(code >> (2x)) & 3 for x in 0:3])
            isaffine = xor(xor(F.lut[1], F.lut[2]), xor(F.lut[3], F.lut[4])) == 0
            for (G, expected) in ((affine, isaffine), (nonlinear, !isaffine))
                for relation in (:ccz, :ea)
                    result = partition_refinement_equivalence(F, G; relation)
                    @test !is_budget_hit(result)
                    @test (result isa Found) == expected
                    if expected
                        A = only(search_solutions(result))
                        @test is_invertible(A.linear)
                        @test ccz_equivalent_function(F, A) == G
                        relation === :ea && @test all(c -> c >> 2 == 0, A.linear.cols[1:2])
                    else
                        @test proves_emptiness(result)
                    end
                end
            end
        end
    end

    @testset "arbitrary functions and affine witnesses" begin
        rng = Xoshiro(2026940)
        for n in 3:7, trial in 1:3
            F = random_function_sbox(rng, Val(n))
            A = random_affine_permutation(rng, Val(n))
            B = random_affine_permutation(rng, Val(n))
            C = random_linear_function(rng, Val(n))
            G = SBox{n}([B(F(A(x))) ⊻ C(x) for x in 0:((1 << n)-1)])
            for relation in (:ccz, :ea)
                result = partition_refinement_equivalence(F, G; relation)
                @test result isa Found
                if result isa Found
                    witness = only(search_solutions(result))
                    @test ccz_equivalent_function(F, witness) == G
                    relation === :ea && @test all(c -> c >> n == 0, witness.linear.cols[1:n])
                end
            end
        end
    end

    @testset "CCZ includes EA and distinguishes Kim from Dillon under EA" begin
        K, D = kim_apn(), dillon_apn_permutation()
        r = partition_refinement_equivalence(K, D)
        @test r isa Found
        @test ccz_equivalent_function(K, only(search_solutions(r))) == D
        @test proves_emptiness(partition_refinement_equivalence(K, D; relation = :ea))
        @test proves_emptiness(partition_refinement_equivalence(gold_apn(5, 1), gold_apn(5, 2)))
    end

    @testset "rank-deficient graphs complete inside the EA output subspace" begin
        z = SBox{4}(zeros(UInt8, 16))
        G = SBox{4}(UInt8[(x >> 1) ⊻ 7 for x in 0:15])
        for relation in (:ccz, :ea)
            result = partition_refinement_equivalence(z, G; relation)
            @test result isa Found
            A = only(search_solutions(result))
            @test is_invertible(A.linear)
            @test ccz_equivalent_function(z, A) == G
        end
        A = VBF._PRAffineMap(2)
        @test VBF._pr_insert!(A, UInt32(0), UInt32(0), 2, true)
        @test VBF._pr_insert!(A, UInt32(5), UInt32(5), 2, true)
        # Domain directions 5 and 6 have the same input projection, but their
        # proposed images 5 and 10 do not: output-subspace preservation fails.
        @test !VBF._pr_insert!(A, UInt32(6), UInt32(10), 2, true)
    end

    @testset "budgets, invalid options and storage width" begin
        F, G = gold_apn(4, 1), SBox{4}(UInt8[(x * 3) & 15 for x in 0:15])
        for (options, reason) in (((max_nodes = 0,), :nodes),
                                  ((timeout_seconds = 0.0,), :time),
                                  ((max_memory_bytes = 0,), :memory))
            r = partition_refinement_equivalence(F, G; options...)
            @test r isa BudgetHit
            @test r.where_it_stopped.reason === reason
            @test !proves_emptiness(r)
        end
        @test partition_refinement_equivalence(F, F; max_nodes = 1) isa BudgetHit
        @test proves_emptiness(partition_refinement_equivalence(F, gold_apn(5, 1)))
        @test partition_refinement_equivalence(F, SBox{4,UInt16}(UInt16.(F.lut))) isa Found
        for options in ((relation = :invalid,), (max_nodes = -1,),
                        (timeout_seconds = NaN,), (min_active_hyperplanes = -1,),
                        (max_memory_bytes = -1,))
            @test_throws ArgumentError partition_refinement_equivalence(F, G; options...)
        end
    end

    @testset "direct and transform refinement give identical signed scores" begin
        points = FunctionGraph(gold_apn(5, 1)).packed
        spectrum = VBF._pr_graph_walsh(points, 10)
        histogram = VBF._pr_intersection_histogram(spectrum, length(points))
        classes, nplanes = VBF._pr_select_classes(histogram, 1024)
        planes, hp = VBF._pr_build_planes(spectrum, length(points), classes, histogram)
        pp = VBF._PRPartition(length(points))
        VBF._pr_individualize!(pp, 1, 7)
        w = VBF._PRWorkspace(10, length(points), nplanes)
        direct = VBF._PRWorkspace(w.scratch, w.point_left, w.point_right,
            w.plane_left, w.plane_right, w.normals, w.weights, w.point_weights,
            w.point_cells, w.threaded, typemax(Int))
        dense = VBF._PRWorkspace(w.scratch, w.point_left, w.point_right,
            w.plane_left, w.plane_right, w.normals, w.weights, w.point_weights,
            w.point_cells, w.threaded, 0)
        a, b = zeros(Int, length(points)), zeros(Int, length(points))
        VBF._pr_point_scores!(a, points, planes, hp, direct)
        VBF._pr_point_scores!(b, points, planes, hp, dense)
        @test a == b
        a, b = zeros(Int, nplanes), zeros(Int, nplanes)
        VBF._pr_plane_scores!(a, points, pp, planes, hp, direct)
        VBF._pr_plane_scores!(b, points, pp, planes, hp, dense)
        @test a == b
    end
end
