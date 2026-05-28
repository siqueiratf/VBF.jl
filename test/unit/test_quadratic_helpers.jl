using BFA
using Test

@testset "ccz_equivalent_quadratic_function: returns a degree-2 CCZ member" begin
    # For quadratic APN, the function itself is degree 2, so the first
    # member of enumerate_ccz_class with degree 2 is returned. It must
    # share F's DDT multiset (a CCZ-invariant).
    for name in ("n4_Gold_x3", "n5_Gold_x3", "n5_Gold_x5")
        F = load_apn_function(name)
        q = ccz_equivalent_quadratic_function(F)
        @test q !== nothing
        @test algebraic_degree(q) == 2
        @test sort(vec(ddt(q))) == sort(vec(ddt(F)))
    end
end

@testset "ccz_equivalent_quadratic_function: member of the CCZ-class" begin
    F = load_apn_function("n5_Gold_x3")
    reps = enumerate_ccz_class(F)
    q = ccz_equivalent_quadratic_function(F)
    @test q !== nothing
    # q is drawn from enumerate_ccz_class, so it must appear there.
    @test any(r -> r.lut == q.lut, reps)
end
