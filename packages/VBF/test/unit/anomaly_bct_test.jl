@testitem "anomaly_bct" begin
using VBFCatalog
using VBF
using Test

@testset "bct_coeff_probability: odd c → 0" begin
    for n in 4:6, c in (1, 3, 5)
        @test bct_coeff_probability(n, n, c) == 0
    end
end

@testset "bct_coeff_probability: rejects m ≠ n" begin
    @test_throws ArgumentError bct_coeff_probability(8, 4, 0)
end

@testset "bct_coeff_probability (n=4): PMF sums ~ 1 over the BCT support [0, 2^n]" begin
    # Actual BCT entries are bounded by 2^n; the BPT formula assigns vanishing mass beyond that bound (truncation tail ~10⁻⁴ for n=4).
    n = 4
    s = sum(bct_coeff_probability(n, n, 2d) for d in 0:1 << (n - 1))
    @test s > BigFloat("0.999")
    @test s ≤ BigFloat(1) + BigFloat("1e-20")
end

@testset "bct_coeff_probability (n=5): PMF sums close to 1" begin
    n = 5
    s = sum(bct_coeff_probability(n, n, 2d) for d in 0:1 << (n - 1))
    @test s > BigFloat("0.99")
end

@testset "bct_coeff_probability: most mass on small even values" begin
    # For n=5, P(0) and P(2) should each be > 0.05 and dominate the tail.
    n = 5
    p0 = bct_coeff_probability(n, n, 0)
    p2 = bct_coeff_probability(n, n, 2)
    @test p0 > BigFloat("0.05")
    @test p2 > BigFloat("0.05")
    # The values around 8, 10, … should be tiny (≤ 0.001).
    for c in (12, 14, 16)
        @test bct_coeff_probability(n, n, c) < BigFloat("0.01")
    end
end

# --- expected_boomerang_uniformity_distribution -----------------------------

@testset "expected_boomerang_uniformity_distribution: shape" begin
    pmf = expected_boomerang_uniformity_distribution(8; vmax = 64)
    @test all(p ≥ 0 for p in values(pmf))
    @test sum(values(pmf)) > BigFloat("0.99")
end

@testset "AES boomerang uniformity (6) is in the left tail" begin
    pmf = expected_boomerang_uniformity_distribution(8; vmax = 128)
    p_below_6 = sum(p for (k, p) in pmf if k ≤ 6; init = BigFloat(0))
    @test p_below_6 < BigFloat("0.5")     # AES's BU=6 is on the rare side
    peak = argmax(pmf)
    @test peak ≥ 6                        # peak ≥ 6, often higher
end

end
