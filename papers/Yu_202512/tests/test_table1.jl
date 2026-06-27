@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))

    boxes = build_table1_sboxes(MOD10)

    # All 3 CCZ-reps are quadratic APN over GF(2^10)
    for (i, F) in enumerate(boxes)
        @test is_quadratic_apn(F)  # Table 1 F$i
    end

    # Pairwise CCZ-inequivalence: ortho-derivative differential spectra must differ
    spectra = [differential_spectrum(ortho_derivative(F)) for F in boxes]
    @test spectra[1] != spectra[2]
    @test spectra[1] != spectra[3]
    @test spectra[2] != spectra[3]
end
