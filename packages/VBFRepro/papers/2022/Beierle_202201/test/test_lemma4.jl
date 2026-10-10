@testset "lemma4_test" begin
    include(joinpath(@__DIR__, "..", "lemma4.jl"))

    # fixed_point_count
    @test fixed_point_count([0, 1, 2, 3]) == 4       # identity: all fixed
    @test fixed_point_count([1, 0, 3, 2]) == 0        # 0↔1, 2↔3: no fixed points
    @test fixed_point_count([0, 0, 3, 2]) == 1        # only index 0 maps to 0
    @test fixed_point_count([0, 1, 3, 2]) == 2        # indices 0 and 1 fixed

    # lemma4_excludes: fix_B < fix_A and (fix_B, fix_A) not an allowed exception → exclude
    id4  = [0, 1, 2, 3]        # 4 fixed points
    one  = [0, 0, 3, 2]        # 1 fixed point
    two  = [0, 1, 3, 2]        # 2 fixed points

    @test lemma4_excludes(id4, one)    # fix_B=1 < fix_A=4, (1,4) not exception → exclude
    @test !lemma4_excludes(two, one)   # (1,2) is an allowed exception → do not exclude
    @test !lemma4_excludes(id4, two)   # (2,4) is an allowed exception → do not exclude
    @test !lemma4_excludes(one, id4)   # fix_B=4 ≥ fix_A=1 → lemma does not apply
    @test !lemma4_excludes(id4, id4)   # fix_B = fix_A → lemma does not apply
end