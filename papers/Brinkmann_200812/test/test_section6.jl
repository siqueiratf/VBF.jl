@testset "section6_test" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    # Table 4, n=1: exact count
    @test count_apn_n1() == 4

    # Table 4, n=2: exact count
    @test count_apn_n2() == 192

    # n=3 full enumeration is ~2 min — omitted from fast test suite.
    # Run `make -C papers/Brinkmann_200812 section6_n3` for the exact count (688128).
end
