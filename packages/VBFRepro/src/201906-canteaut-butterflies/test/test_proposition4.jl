@testset "proposition4_test" begin
    include(joinpath(@__DIR__, "..", "proposition4.jl"))

    # n=3: the iff holds non-vacuously — 3 α satisfy the trace condition,
    # each contributing 2 APN β values (β₁ and β₂)
    res3 = proposition4_build(3, 1)
    @test length(res3) == 6
    @test all(r.iff_holds for r in res3)
    @test all(r.bridge for r in res3)          # Prop 4 cond ↔ Prop 5 refined cond
    @test count(r.cond for r in res3) == 3
    @test sum(r.n_apn for r in res3) == 6

    # n=3, i=2 (the other gcd(i,3)=1 exponent)
    res32 = proposition4_build(3, 2)
    @test all(r.iff_holds for r in res32)
    @test all(r.bridge for r in res32)
    @test count(r.cond for r in res32) == 3

    # n=5: condition never satisfied, no APN — consistent with Prop 6
    res5 = proposition4_build(5, 1)
    @test length(res5) == 30
    @test all(r.iff_holds for r in res5)
    @test all(r.bridge for r in res5)
    @test count(r.cond for r in res5) == 0
    @test sum(r.n_apn for r in res5) == 0
end
