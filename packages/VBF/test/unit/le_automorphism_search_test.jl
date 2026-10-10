@testitem "le_automorphism_search" begin
using VBF
using TOML
using Test

# Beierle–Leander 2022 reports quadratic APNs in these four n=7 canonical classes.
# Frozen tuples test the mathematical algorithm, independently of the catalog.
tuples = TOML.parsefile(joinpath(@__DIR__, "..", "support", "le_automorphism_n7.toml"))

@testset "BL22 n=7: classes 1, 7, 16, 19 each yield a quadratic APN" begin
    for cls in ("class1", "class7", "class16", "class19")
        t = tuples[cls]
        sols = search_quadratic_apn_le(Int.(t["A"]), Int.(t["B"]);
                                       pos = Int.(t["pos"]), fix = Int.(t["fix"]), limit = 1)
        @test !isempty(sols)
        F = sols[1]
        @test inputbits(F) == 7
        @test differential_uniformity(F) == 2          # APN
        @test algebraic_degree(F) == 2                 # quadratic
        # the solution genuinely satisfies the linear self-equivalence A∘F = F∘B
        A = Int.(t["A"]); B = Int.(t["B"])
        @test all(A[F.lut[x + 1] + 1] == F.lut[B[x + 1] + 1] for x in 0:127)
    end
end

@testset "argument guards" begin
    @test_throws ArgumentError search_quadratic_apn_le([0, 1, 2], [0, 1, 2]; pos = Int[])
    @test_throws ArgumentError search_quadratic_apn_le([0, 1], [0, 1, 2, 3]; pos = Int[])
end
end
