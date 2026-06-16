@testset "section2_le_algorithm" begin
    include(joinpath(@__DIR__, "..", "section2.jl"))

    # LE is reflexive.
    g3 = load_apn_function("n5_Gold_x3")
    @test are_linear_equivalent(g3, g3)

    # Gold x^3 and x^5 (n=5) are in different linear classes.
    g5 = load_apn_function("n5_Gold_x5")
    @test !are_linear_equivalent(g3, g5)

    # linear_representative gives the same element for an equivalent pair.
    rep = linear_representative(g3)
    @test are_linear_equivalent(g3, rep.representative)

    # Both strategies agree.
    @test are_linear_equivalent(g3, g3; strategy = :lpp_backtracking)
    @test are_linear_equivalent(g3, g3; strategy = :stennes)
    @test !are_linear_equivalent(g3, g5; strategy = :lpp_backtracking)
    @test !are_linear_equivalent(g3, g5; strategy = :stennes)

    # Full report passes.
    @test section2_report(devnull)
end
