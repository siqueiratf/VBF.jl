@testset "conjecture21_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    include(joinpath(@__DIR__, "..", "conjecture21.jl"))
    using VBFCatalog

    r = conjecture21_report(; io = devnull)
    @test r.all_match

    # README R7: Conjecture 21 claims BOTH Σ_y Δ(y,F(y)+1) and Σ_y Δ(y+1,F(y))
    # equal the x^3 value. The old code only computed S1.
    for row in r.rows
        @test row.s1 == formula34(row.n)
        @test row.s2 == formula34(row.n)
        @test row.s1 == row.s2
    end

    # README R6: power functions are now selected by a mathematical monomial test,
    # not by the presence of a `monomial_exponent` TOML key. The catalog stores its
    # n=4/n=5 power APN as raw LUTs, so the old metadata proxy silently dropped
    # every dimension below 6. 24 entries carry the key; 4 more are genuine power
    # functions without it.
    dims = sort(unique(row.n for row in r.rows))
    @test 5 in dims
    @test issubset([4, 5, 6, 7, 8, 9, 10], dims)
    @test length(r.rows) == 28
    names = [row.name for row in r.rows]
    for nm in ["n4_Gold_x3", "n5_Gold_x3", "n5_Gold_x5", "n5_Kasami_x15"]
        @test nm in names                     # dropped by the old TOML-key filter
        @test !haskey(apn_catalog_metadata(nm), "monomial_exponent")
    end

    # The monomial test recovers the exponent, and rejects non-monomials.
    @test power_exponent(load_apn_function("n5_Gold_x5")) == 5
    @test power_exponent(load_apn_function("n7_Inverse_x126")) == 126
    @test !is_power_function(swap_points(load_apn_function("n5_Gold_x3"), 0, 1))
end
