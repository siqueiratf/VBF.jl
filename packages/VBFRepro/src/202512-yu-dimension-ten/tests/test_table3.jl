@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    # Tr(x^9) exponents for n=11: 11 distinct values, all nonzero mod 2047
    @test length(TR_X9_EXPS_N11) == 11
    @test allunique(TR_X9_EXPS_N11)
    @test all(e -> 1 <= e <= 2046, TR_X9_EXPS_N11)

    boxes = build_table3_sboxes(MOD11)

    # All 6 conjectured CCZ-reps are quadratic APN over GF(2^11)
    for (i, F) in enumerate(boxes)
        @test is_quadratic_apn(F)  # Table 3 F$i (n=11)
    end
    mugshots=apn_ea_mugshot.(boxes)
    @test length(Set(mugshots)) == 6
    # DDT-only ortho signatures collide for x^3/x^33; adding Walsh separates.
    @test differential_spectrum(ortho_derivative(boxes[1])) == differential_spectrum(ortho_derivative(boxes[5]))
    @test mugshots[1] != mugshots[5]

end
