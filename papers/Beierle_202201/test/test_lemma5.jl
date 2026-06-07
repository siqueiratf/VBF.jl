@testset "lemma5_test" begin
    include(joinpath(@__DIR__, "..", "lemma5.jl"))

    # cycle_count
    @test cycle_count([0, 1, 2, 3]) == 4      # identity: 4 fixed points = 4 cycles
    @test cycle_count([1, 2, 3, 0]) == 1      # single 4-cycle
    @test cycle_count([1, 0, 3, 2]) == 2      # two 2-cycles: 0↔1, 2↔3
    @test cycle_count([1, 0, 2, 3]) == 3      # one 2-cycle + two fixed points

    # lemma5_min_cycles: closed-form values from the paper
    @test lemma5_min_cycles(3) == 3    # (8+1)/3 = 3
    @test lemma5_min_cycles(4) == 6    # (16+2)/3 = 6
    @test lemma5_min_cycles(8) == 86   # (256+2)/3 = 86
    @test lemma5_min_cycles(9) == 171  # (512+1)/3 = 171

    # lemma5_excludes: identity on 8 elements has 8 cycles, n=3 needs ≥ 3 → not excluded
    id8 = collect(0:7)
    @test !lemma5_excludes(id8, 3)

    # Two 4-cycles has 2 cycles, n=3 needs ≥ 3 → excluded
    two4 = [1, 2, 3, 0, 5, 6, 7, 4]
    @test lemma5_excludes(two4, 3)

    # Identity on 16 elements has 16 cycles, n=4 needs ≥ 6 → not excluded
    id16 = collect(0:15)
    @test !lemma5_excludes(id16, 4)
end