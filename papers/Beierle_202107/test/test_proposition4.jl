using Test
using Nemo

@testset "Proposition 4 Direct Matrix Cases" begin
    F = GF(2)

    identity3 = identity_matrix(F, 3)
    transvection = matrix(F, 3, 3, [
        1, 1, 0,
        0, 1, 0,
        0, 0, 1,
    ])

    @test proposition4_filter(identity3, identity3, 3) == true
    @test proposition4_filter(transvection, transvection, 3) == false
end

@testset "Proposition 4 Precomputed n = 6 Classes" begin
    # 6, 9, 13, 16 and 17 should be filtered by Proposition 4
    classes_filtered_by_prop_4 = [6, 9, 13, 16, 17]
    for i in classes_filtered_by_prop_4
        A, B = precomputed_tuple_matrices(6, i)
        @test proposition4_filter(A, B, 6) == false
    end

    # 1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 14 and 15 should pass Proposition 4
    classes_that_pass_prop_4 = [1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 14, 15]
    for i in classes_that_pass_prop_4
        A, B = precomputed_tuple_matrices(6, i)
        @test proposition4_filter(A, B, 6) == true
    end
end

@testset "Proposition 4 Precomputed n = 7 Classes" begin
    # 12, 13, 14, 15, 20, 21, 25, 27 should be filtered by Proposition 4
    classes_filtered_by_prop_4 = [12, 13, 14, 15, 20, 21, 25, 27]
    for i in classes_filtered_by_prop_4
        A, B = precomputed_tuple_matrices(7, i)
        @test proposition4_filter(A, B, 7) == false
    end

    # 1:11, 16:19, 22:24, 26 should pass Proposition 4
    classes_that_pass_prop_4 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 16, 17, 18, 19, 22, 23, 24, 26]
    for i in classes_that_pass_prop_4
        A, B = precomputed_tuple_matrices(7, i)
        @test proposition4_filter(A, B, 7) == true
    end
end

@testset "Proposition 4 Precomputed n = 8 Classes" begin
    # 13, 18, 19, 20, 21, 25, 26, 28, 32 should be filtered by Proposition 4
    classes_filtered_by_prop_4 = [13, 18, 19, 20, 21, 25, 26, 28, 32]
    for i in classes_filtered_by_prop_4
        A, B = precomputed_tuple_matrices(8, i)
        @test proposition4_filter(A, B, 8) == false
    end

    # 1:12, 14:17, 22:24, 27, 29:31 should pass Proposition 4
    classes_that_pass_prop_4 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 22, 23, 24, 27, 29, 30, 31]
    for i in classes_that_pass_prop_4
        A, B = precomputed_tuple_matrices(8, i)
        @test proposition4_filter(A, B, 8) == true
    end
end
