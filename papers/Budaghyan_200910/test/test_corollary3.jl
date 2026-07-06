@testset "corollary3_test" begin
    include(joinpath(@__DIR__, "..", "corollary3.jl"))
    r = corollary3_report(devnull; full_search = false)
    @test r.all_ok
    # New-class claim: n=6 x³+trₙ(x⁹) CCZ-inequivalent to x³+α⁻¹trₙ(α³x⁹).
    @test all(nc -> nc[2], r.newclass)
    s1 = od_signature(apn_eq6(6, 1), 6)
    sa = od_signature(apn_eq6(6, primitive_element(6)), 6)
    @test s1 != sa

    # Frozen ortho-derivative signatures (the quadratic-APN CCZ invariant behind
    # the new-class inequivalence) — exact regression anchors from the full
    # exhaustive search, at n=6 and n=8, for a=1 (x³+trₙ(x⁹)) and a=α.
    @test s1 == [0 => 2205, 2 => 1764, 8 => 63]
    @test sa == [0 => 2583, 2 => 1008, 4 => 378, 8 => 63]
    @test od_signature(apn_eq6(8, 1), 8) ==
          [0 => 38004, 2 => 22614, 4 => 4008, 6 => 630, 10 => 24]
    @test od_signature(apn_eq6(8, primitive_element(8)), 8) ==
          [0 => 38592, 2 => 21426, 4 => 4590, 6 => 654, 8 => 18]
end
