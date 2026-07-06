@testset "section6_test" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    # Table 4, n=1: exact count
    @test count_apn_n1() == 4

    # Table 4, n=2: exact count
    @test count_apn_n2() == 192

    # n=3 full enumeration is ~2 min — omitted from fast test suite.
    # Run `make -C papers/Brinkmann_200812 section6_n3` for the exact count (688128).
    @test APN_COUNT_N3 == "688128"

    # Regression against Table 4 (tex lines 393-395). n=5 previously carried a
    # transcription bug: 23 digits (…146800) instead of the paper's 24-digit
    # …1468800 — a dropped '8', off by ~10x. Assert the exact digit strings.
    @test APN_COUNT_N4 == "18940805775360"
    @test APN_COUNT_N5 == "110823678910407691468800"
    @test length(APN_COUNT_N5) == 24
end
