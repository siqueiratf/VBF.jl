@testset "section6_test" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    rl = section6_check_lemmaVI6()
    @test rl.ok_i
    @test rl.ok_ii
    @test rl.ok_iv

    rt = section6_check_theoremVI3()
    @test rt.is_apn
    @test rt.du == 2

    # Round-trip: isotopic_shift of G_1 by zero map is the zero function
    n  = 9
    G1 = gold_lut(n, 1)
    @test is_zero_map(isotopic_shift_lut(G1, zero_map_lut(n)))
end
