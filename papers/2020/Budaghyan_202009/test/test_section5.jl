@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    F = gold_x3(5)

    # kernel dimension ≥ 1 (non-trivial solutions exist)
    res = single_shift_solutions(F, 1; limit = 128)
    @test res.kernel_dim ≥ 1

    # Empty set U (all-zero solution) always present
    @test UInt64(0) ∈ res.solutions

    # All non-trivial solutions give APN G
    for sol in res.solutions
        sol == 0 && continue
        U = [x for x = 0:31 if (sol >> x) & 1 == 1]
        V = fill(1, length(U))
        G = apply_modifications(F, U, V)
        @test differential_uniformity(G) == 2
    end

    # Round-trip: kernel vectors → APN check
    rows = build_single_shift_constraints(F, 1)
    basis = kernel_f2(rows; nbits = 32)
    @test length(basis) == res.kernel_dim
end
