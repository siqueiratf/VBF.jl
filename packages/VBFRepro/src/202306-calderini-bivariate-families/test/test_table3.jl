@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    # Fast structural checks only: every cheap known-family builder yields a
    # quadratic APN function over F_{2^12}. The N_F recomputation of all
    # Table 3 rows (~10 min) runs via `make table3` / table3_build(full_search=true).
    mod12 = primitive_polynomial(12)
    mod6  = primitive_polynomial(6)

    for (builder, modulus) in ((table3_family1, mod12),   # Gold
                               (table3_family2, mod12),   # BCL binomials
                               (table3_family9, mod6),    # Zhou-Pott
                               (table3_family10, mod6),   # Taniguchi
                               (table3_family11, mod6),   # CBC bivariate
                               (table3_family12, mod6))   # Gologlu-Kolsch
        reps = builder(modulus)
        @test !isempty(reps)
        for (F, _) in reps
            @test differential_uniformity(F) == 2
            @test algebraic_degree(F) == 2
        end
    end

    # The skip gate stays intact for the default (fast) report path
    @test table3_build().skipped
end
