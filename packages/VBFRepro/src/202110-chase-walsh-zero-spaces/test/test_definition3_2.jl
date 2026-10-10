@testset "definition3_2_test" begin
    include(joinpath(@__DIR__, "..", "definition3_2.jl"))

    r5 = definition3_2_build(5, 1)
    @test r5.ex33_i && r5.ex33_ii && r5.prop3_4
    @test !r5.applicable_3div

    r9 = definition3_2_build(9, 1)
    @test r9.ex33_i && r9.ex33_ii && r9.prop3_4
    @test r9.lemma3_5 && r9.cor3_6

    # Exhaustive 2-dim search: 0 witnesses when 3 does not divide n,
    # 2^n - 1 when it does — and then exactly the μ-scalings of the
    # 2-dim subspaces of F_8.
    c5 = count_2dim_icompatible(5, 1)
    @test c5.count == 0 && c5.matches_expected

    c3 = count_2dim_icompatible(3, 1)
    @test c3.count == 7 && c3.matches_expected && c3.scaled_match

    c9 = count_2dim_icompatible(9, 1)
    @test c9.count == 511 && c9.matches_expected && c9.scaled_match

    # A 2-dim subspace NOT inside a scaled F_8 copy must not be i-compatible.
    @test !is_icompatible([0, 1, 2, 3], 5, 1)
end
