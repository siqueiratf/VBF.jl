@testset "section3_test" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))

    # Theorem 1.2 / Lemma 3.1: the differential SPECTRUM of F is {0, 2^t}, not
    # merely differential_uniformity(F) == 2^t (BTT-2). The set claim is what the
    # paper makes, and a maximum would not exclude a stray DDT entry of 1 or 3.
    #
    # Grid (BTT-10): 9 of the 12 feasible instances run by default; the three
    # skipped ones ((5,4), (5,7), (5,13)) only repeat (5,1)'s t=1 shape and cost
    # 1.7 s each here. t ∈ {1,2,4,5} is covered, so the exponent in "2^t" is
    # pinned down — with only t ∈ {1,2} it could equally read "4 or 2".
    @test length(SECTION3_CASES) == 12
    @test count(c -> !c[4], SECTION3_CASES) == 9

    # Each instance is scanned once and the result reused (an n=15 scan is 1.7 s).
    observed = Dict{Tuple{Int,Int},Vector{Int}}()
    for (k, s, expected, heavy) in SECTION3_CASES
        heavy && continue
        t = gcd(3k, s)
        F = bracken_binomial_sbox(k, s)
        vals = differential_value_set(F)
        observed[(k, s)] = vals
        @test vals == expected
        @test vals == [0, 1 << t]                 # the paper's {0, 2^t}
    end

    # t = 4 and t = 5 are the only feasible witnesses that the exponent is 2^t
    # rather than a hard-coded 4 or 2.
    @test observed[(4, 8)] == [0, 16]
    @test observed[(5, 10)] == [0, 32]

    # The weaker assertion this reproduction used to make, kept where it is cheap.
    @test differential_uniformity(bracken_binomial_sbox(2, 4)) == 4
    @test differential_uniformity(bracken_binomial_sbox(4, 8)) == 16

    # The streaming and Dict-backed paths must agree where both are affordable.
    F12 = bracken_binomial_sbox(4, 2)
    @test differential_value_set(F12; streaming = true) ==
          differential_value_set(F12; streaming = false)
end
