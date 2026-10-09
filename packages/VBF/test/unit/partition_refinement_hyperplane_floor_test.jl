@testitem "partition_refinement_hyperplane_floor" begin
    using VBF, Test

    @testset "exhausting available cells preserves paired order" begin
        for preserve_order in (false,true), floor in (6,7,typemax(Int))
            left = VBF._PRPartition(collect(1:6),[1,4,5,7])
            right = VBF._PRPartition(collect(101:106),[1,4,5,7])
            VBF._pr_trim_pair!(left,right,floor;preserve_order)
            expected = preserve_order ? collect(1:6) : [4,5,6,1,2,3]
            @test left.order == expected
            @test right.order == expected .+ 100
            @test left.starts == right.starts == (preserve_order ? [1,4,5,7] : [1,2,4,7])
            @test length(left.order)==6
        end
        for preserve_order in (false,true)
            left,right = VBF._PRPartition(Int[],[1]),VBF._PRPartition(Int[],[1])
            VBF._pr_trim_pair!(left,right,typemax(Int);preserve_order)
            @test isempty(left.order) && isempty(right.order)
            @test left.starts == right.starts == [1]
        end
    end

    @testset "a floor exceeding the whole ambient hyperplane set" begin
        F,G = VBFTable{1,1}([0,0]),VBFTable{1,1}([1,1])
        walsh = VBF._pr_graph_walsh(FunctionGraph(F).packed,2)
        hist = VBF._pr_intersection_histogram(walsh,2)
        @test sum(hist)==6 # two translates of each of the three nonzero normals
        for algorithm in (:paper,:optimized), floor in (6,7,typemax(Int))
            classes,total = VBF._pr_select_classes(hist,floor;
                preserve_order=algorithm!==:paper)
            @test total==6 && length(classes)==count(!iszero,hist)
            for relation in (:ccz,:ea)
                result = partition_refinement_equivalence(F,G;relation,algorithm,
                    min_active_hyperplanes=floor)
                @test result isa Found
                @test ccz_equivalent_function(F,only(search_solutions(result)))==G
                H = partition_refinement_automorphisms(F;relation,algorithm,
                    min_active_hyperplanes=floor)
                @test H.complete && H.graph_order==2 && H.order==(relation===:ccz ? 4 : 2)
            end
        end
    end
end
