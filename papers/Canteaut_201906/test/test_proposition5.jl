@testset "proposition5_test" begin
    include(joinpath(@__DIR__, "..", "proposition5.jl"))

    res = proposition5_build(3, 1)
    @test length(res) == 6  # α ∈ GF(8)\{0,1}
    # APN ↔ refined_trace_cond for all α
    @test all(r.equiv for r in res)
    # Exactly 3 APN α values (β₁ only; each also has an APN β₂)
    @test count(r.apn for r in res) == 3
    # RTC and APN agree
    @test all(r.apn == r.rtc for r in res)

    # n=3, i=2 (the other gcd(i,3)=1 exponent)
    res32 = proposition5_build(3, 2)
    @test all(r.equiv for r in res32)
    @test count(r.apn for r in res32) == 3

    # n=5: equivalence holds with both sides false for every α
    res5 = proposition5_build(5, 1)
    @test length(res5) == 30
    @test all(r.equiv for r in res5)
    @test count(r.apn for r in res5) == 0
end
