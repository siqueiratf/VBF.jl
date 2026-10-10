using Test

@testset "Proposition 5 Direct Precomputed Cases" begin
    A_pass, B_pass = precomputed_tuple_matrices(6, 1)
    A_fail, B_fail = precomputed_tuple_matrices(6, 4)

    @test proposition5_filter(A_pass, B_pass, 6) == true
    @test proposition5_filter(A_fail, B_fail, 6) == false
end

@testset "Proposition 5 Precomputed n = 6 Classes" begin
    # 4, 8 and 12 should be filtered by Proposition 5
    classes_filtered_by_prop_5 = [4, 8, 12]
    for i in classes_filtered_by_prop_5
        A, B = precomputed_tuple_matrices(6, i)
        @test proposition5_filter(A, B, 6) == false
    end

    # 1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 16 and 17 should pass Proposition 5
    classes_that_pass_prop_5 = [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 16, 17]
    for i in classes_that_pass_prop_5
        A, B = precomputed_tuple_matrices(6, i)
        @test proposition5_filter(A, B, 6) == true
    end
end

@testset "Proposition 5 Precomputed n = 7 Classes" begin
    # 2, 3, 6, 11, 15, 19 and 21 should be filtered by Proposition 5
    classes_filtered_by_prop_5 = [2, 3, 6, 11, 15, 19, 21]
    for i in classes_filtered_by_prop_5
        A, B = precomputed_tuple_matrices(7, i)
        @test proposition5_filter(A, B, 7) == false
    end

    # 1, 4, 5, 7:10, 12:14, 16:18, 20, 22:27 should pass Proposition 5
    classes_that_pass_prop_5 = [1, 4, 5, 7, 8, 9, 10, 12, 13, 14, 16, 17, 18, 20, 22, 23, 24, 25, 26, 27]
    for i in classes_that_pass_prop_5
        A, B = precomputed_tuple_matrices(7, i)
        @test proposition5_filter(A, B, 7) == true
    end
end

@testset "Proposition 5 Precomputed n = 8 Classes" begin
    # 3, 7, 11, 12, 17, 21 and 24 should be filtered by Proposition 5
    classes_filtered_by_prop_5 = [3, 7, 11, 12, 17, 21, 24]
    for i in classes_filtered_by_prop_5
        A, B = precomputed_tuple_matrices(8, i)
        @test proposition5_filter(A, B, 8) == false
    end

    # 1, 2, 4:6, 8:10, 13:16, 18:20, 22, 23, 25:32 should pass Proposition 5
    classes_that_pass_prop_5 = [1, 2, 4, 5, 6, 8, 9, 10, 13, 14, 15, 16, 18, 19, 20, 22, 23, 25, 26, 27, 28, 29, 30, 31, 32]
    for i in classes_that_pass_prop_5
        A, B = precomputed_tuple_matrices(8, i)
        @test proposition5_filter(A, B, 8) == true
    end
end
