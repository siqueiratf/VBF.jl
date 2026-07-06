@testset "theorem11_test" begin
    include(joinpath(@__DIR__, "..", "theorem11.jl"))

    r = theorem11_report(devnull; check_ccz = true)
    @test r.du == 2                       # APN
    @test r.deg == 3                      # NOT quadratic — the central claim
    @test r.gamma == 1300                 # Table 6, entry 2.11
    @test r.delta == 152
    @test r.not_crooked                   # Δ-rank 152 > 2^(n+1)=128 (Theorem 7)
    @test r.same_class                    # eq.(9) rep ≡ Table-5 2.11 (invariants)
    @test r.ccz_to_gold == false          # CCZ-inequivalent to power map x^3

    # The eq.(9) representative really is APN of degree 3 as built.
    F = theorem11_function()
    @test differential_uniformity(F) == 2
    @test algebraic_degree(F) == 3
end
