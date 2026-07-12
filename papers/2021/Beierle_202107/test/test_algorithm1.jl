using Test

@testset "Algorithm 1 APNSearch Entry Point" begin
    identity1 = reshape([1], 1, 1)

    solutions = APNSearch(
        1,
        identity1,
        identity1,
        max_solutions = 1,
        on_solution = sbox -> nothing,
    )

    @test solutions == [[0, 1]]
end

@testset "Algorithm 1 C reference n = 7 class 4" begin
    A, B = precomputed_tuple_matrices(7, 4)
    apply_A = linear_map_lut(A, 7)
    apply_B = linear_map_lut(B, 7)

    solutions = APNSearch(
        7,
        A,
        B,
        max_solutions = 1,
        on_solution = sbox -> nothing,
        class_index = 4,
        timeout_seconds = 30,
    )

    @test length(solutions) == 1

    sbox = solutions[1]
    @test sort(sbox) == collect(0:127)
    @test all(sbox[apply_B[x + 1] + 1] == apply_A[sbox[x + 1] + 1] for x in 0:127)
end
