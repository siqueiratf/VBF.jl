@testset "remark4_test" begin
    include(joinpath(@__DIR__, "..", "remark4.jl"))

    r = remark4_check(; sample_size = 500, seed = 42)
    @test r.violations == 0
    @test r.tested == 500

    # different seed still finds no violations
    r2 = remark4_check(; sample_size = 200, seed = 137)
    @test r2.violations == 0

    # Definitive reproduction of Remark 4's computer-check: EXHAUSTIVE over all
    # 2^25 linear maps L on GF(2^5) (not a sample). Confirms no F'+L is a
    # permutation — the counterexample to the "AB ⇒ EA-equivalent to a
    # permutation" conjecture. Runs in ~2s via aliased-SBox `is_permutation`.
    r_full = remark4_check(; full_search = true)
    @test r_full.exhaustive
    @test r_full.tested == 1 << 25        # 33_554_432 maps
    @test r_full.violations == 0
end
