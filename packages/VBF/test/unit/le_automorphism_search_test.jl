@testitem "le_automorphism_search" begin
using VBF
using VBFCatalog
using TOML
using Test

# Beierle–Leander 2022's n=7 LE-automorphism canonical-class tuples (re-housed from the upstream into VBFCatalog data). The paper reports quadratic APN found in classes 1, 7, 16, 19; the constrained search must reproduce that.
tuples = TOML.parsefile(joinpath(pkgdir(VBFCatalog), "data-raw",
                                 "le_automorphism_tuples", "n7.toml"))

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
