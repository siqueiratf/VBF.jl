@testitem "partition_refinement_threaded" begin
    using VBF,Test,Random

    @testset "parallel Walsh stages are exact, including chunk boundaries" begin
        rng = Xoshiro(9408)
        for T in (Int32,Int64), exponent in (0,8,18,19,20)
            input = rand(rng,T(-8):T(8),1 << exponent)
            expected = walsh_hadamard!(copy(input))
            actual = walsh_hadamard!(copy(input);threaded=true)
            @test actual == expected
            @test walsh_hadamard!(actual;threaded=true) == length(input) .* input
        end
        @test walsh_hadamard!(BigInt[1,-2,3,4];threaded=true) == BigInt[6,2,-8,4]
        @test_throws ArgumentError walsh_hadamard!(Int32[];threaded=true)
        @test_throws ArgumentError walsh_hadamard!(zeros(Int32,7);threaded=true)
    end

    @testset "direct point and plane sums match serial and dense scores" begin
        points = FunctionGraph(gold_apn(8,1)).packed
        spectrum = VBF._pr_graph_walsh(points,16)
        histogram = VBF._pr_intersection_histogram(spectrum,length(points))
        classes,nplanes = VBF._pr_select_classes(histogram,1024)
        planes,hp = VBF._pr_build_planes(spectrum,length(points),classes,histogram)
        pp = VBF._PRPartition(length(points))
        VBF._pr_individualize!(pp,1,17)
        w = VBF._PRWorkspace(16,length(points),nplanes)
        with_options(threaded,threshold) = VBF._PRWorkspace(w.scratch,w.point_left,w.point_right,
            w.plane_left,w.plane_right,w.normals,w.weights,w.point_weights,w.point_cells,
            threaded,threshold)
        serial = with_options(false,typemax(Int))
        parallel = with_options(true,typemax(Int))
        dense = with_options(true,0)
        a,b,c = zeros(Int,length(points)),zeros(Int,length(points)),zeros(Int,length(points))
        VBF._pr_point_scores!(a,points,planes,hp,serial)
        VBF._pr_point_scores!(b,points,planes,hp,parallel)
        VBF._pr_point_scores!(c,points,planes,hp,dense)
        @test a == b == c
        a,b,c = zeros(Int,nplanes),zeros(Int,nplanes),zeros(Int,nplanes)
        VBF._pr_plane_scores!(a,points,pp,planes,hp,serial)
        VBF._pr_plane_scores!(b,points,pp,planes,hp,parallel)
        VBF._pr_plane_scores!(c,points,pp,planes,hp,dense)
        @test a == b == c
    end

    @testset "complete search, budgets and concurrent discovery" begin
        F = gold_apn(8,1)
        G = SBox{8}([F(x ⊻ 17) ⊻ 31 for x in 0:255])
        serial = partition_refinement_equivalence(F,G;relation=:ea)
        parallel = partition_refinement_equivalence(F,G;relation=:ea,threaded=true)
        @test serial isa Found && parallel isa Found
        @test nodes_visited(serial) == nodes_visited(parallel)
        A,B = only(search_solutions(serial)),only(search_solutions(parallel))
        @test A.linear.cols == B.linear.cols && A.constant == B.constant
        @test ccz_equivalent_function(F,ccz_equivalence_certificate(F,G;threaded=true)) == G
        @test are_ea_equivalent(F,G;threaded=true,on_inconclusive=:throw)
        @test partition_refinement_equivalence(F,G;threaded=true,max_nodes=0) isa BudgetHit
        R = random_function_sbox(Xoshiro(9409),Val(9))
        S = SBox{9}([R(x ⊻ 37) ⊻ 91 for x in 0:511])
        serial9 = partition_refinement_equivalence(R,S;relation=:ea)
        parallel9 = partition_refinement_equivalence(R,S;relation=:ea,threaded=true)
        @test serial9 isa Found && parallel9 isa Found
        @test nodes_visited(serial9) == nodes_visited(parallel9)
        @test ccz_equivalent_function(R,only(search_solutions(parallel9))) == S
        tasks = [Threads.@spawn partition_refinement_automorphisms(gold_apn(3,1);relation,threaded=true)
                 for relation in (:ccz,:ea)]
        a,b = fetch.(tasks)
        @test a.complete && a.order == 40320
        @test b.complete && b.order == 1344
    end
end
