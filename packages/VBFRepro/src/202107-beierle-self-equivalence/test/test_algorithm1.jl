using Test

@testset "Algorithm 1 APNSearch Entry Point" begin
    identity1 = reshape([1], 1, 1)

    outcome = APNSearch(
        1,
        identity1,
        identity1,
        max_solutions = 1,
        on_solution = sbox -> nothing,
    )

    @test search_solutions(outcome) == [[0, 1]]
    @test outcome isa Found          # stopped at max_solutions = 1
end

@testset "Algorithm 1 C reference n = 7 class 4" begin
    A, B = precomputed_tuple_matrices(7, 4)
    apply_A = linear_map_lut(A, 7)
    apply_B = linear_map_lut(B, 7)

    outcome = APNSearch(
        7,
        A,
        B,
        max_solutions = 1,
        on_solution = sbox -> nothing,
        class_index = 4,
        timeout_seconds = 30,
    )

    # With a timeout in play the outcome type is what says whether the empty
    # case would have meant anything. Here a solution is expected.
    @test !(outcome isa BudgetHit)
    solutions = search_solutions(outcome)
    @test length(solutions) == 1

    sbox = solutions[1]
    @test sort(sbox) == collect(0:127)
    @test all(sbox[apply_B[x + 1] + 1] == apply_A[sbox[x + 1] + 1] for x in 0:127)
end

@testset "Algorithm1 negative search preserves scope and budgets" begin
    identity1 = reshape([1],1,1)
    exhausted = APNSearch(1, identity1, identity1; on_solution = _ -> nothing)
    @test exhausted isa Exhausted
    @test length(search_solutions(exhausted)) == 1
    @test !proves_emptiness(exhausted)
    timed = APNSearch(1, identity1, identity1; timeout_seconds = 0, on_solution = _ -> nothing)
    @test timed isa BudgetHit
    @test !proves_emptiness(timed)
end
