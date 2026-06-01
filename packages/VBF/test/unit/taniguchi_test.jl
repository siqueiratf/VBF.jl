@testitem "taniguchi" begin
using VBF
using Test

# Compute the family on F2^8 once (the expensive part) and reuse.
reps = taniguchi_apn_representatives(4)

@testset "Tan19 family on F2^8: three CCZ-classes, two of them new" begin
    # Tan19 reports three CCZ-classes (Γ-ranks 13642 / 13700 / 13798): the a=0 Zhou–Pott member and the two new a≠0 ones.
    @test length(reps) == 3
    @test count(r -> r.new, reps) == 2          # two new (a ≠ 0)
    @test count(r -> !r.new, reps) == 1         # one old (a = 0)
    # every representative is a genuine quadratic APN function in 8 variables
    for r in reps
        @test inputbits(r.sbox) == 8
        @test differential_uniformity(r.sbox) == 2
        @test algebraic_degree(r.sbox) == 2
    end
    # the three are pairwise EA-distinct (distinct ortho-derivative fingerprints)
    @test length(unique(apn_ea_mugshot(r.sbox) for r in reps)) == 3
end

@testset "taniguchi_apn: direct construction reproduces a representative" begin
    r = first(x for x in reps if x.new)
    F = taniguchi_apn(4, r.m, r.a, r.b)
    @test F.lut == r.sbox.lut
    @test differential_uniformity(F) == 2
    @test algebraic_degree(F) == 2
    @test apn_ea_mugshot(F) == apn_ea_mugshot(r.sbox)
end

@testset "taniguchi_apn: argument guards" begin
    @test_throws ArgumentError taniguchi_apn(4, 2, 1, 1)   # gcd(2,4) = 2 ≠ 1
    @test_throws ArgumentError taniguchi_apn(4, 1, 1, 0)   # b = 0
end
end
