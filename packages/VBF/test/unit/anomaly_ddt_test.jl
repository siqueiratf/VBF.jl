@testitem "anomaly_ddt" begin

using VBF
using Test

@testset "ddt_coeff_probability: odd c returns 0" begin
    for n in 4:8, c in (1, 3, 5, 7)
        @test ddt_coeff_probability(n, n, c) == 0
    end
end

@testset "ddt_coeff_probability: negative c returns 0" begin
    @test ddt_coeff_probability(8, 8, -2) == 0
end

@testset "ddt_coeff_probability: PMF sums to ~1 over even c" begin
    # Σ_d P(DDT = 2d) for d = 0..2^(n-1) should be ~1 (some mass beyond the tail is truncated; for n=4 it's >0.999 typically).
    for n in (3, 4, 5, 6)
        s = sum(ddt_coeff_probability(n, n, 2d) for d in 0:1 << (n - 1))
        @test s > BigFloat("0.99")
        @test s ≤ BigFloat(1) + BigFloat("1e-30")
    end
end

@testset "ddt_coeff_probability: monotone decreasing in c for typical regimes" begin
    # For n=6, m=6: P(0) > P(2) > P(4) > … (heavy mass on 0).
    n = 6
    probs = [ddt_coeff_probability(n, n, 2d) for d in 0:6]
    @test issorted(probs; rev = true)
end

@testset "ddt_coeff_probability: Poisson regime matches reference" begin
    # n=8, m=8 → Poisson(λ=1/2). P(2k) = e^{-1/2} (1/2)^k / k!
    n = 8
    λ = BigFloat(1) / 2
    e_neg_half = exp(-λ)
    for k in 0:5
        observed = ddt_coeff_probability(n, n, 2k)
        expected = e_neg_half * λ^k / BigFloat(factorial(big(k)))
        @test abs(observed - expected) < BigFloat("1e-30")
    end
end

# --- expected_differential_uniformity_distribution ---------------------------

@testset "expected_max_distribution: PMF non-negative and sums close to 1" begin
    pmf = expected_differential_uniformity_distribution(8; vmax = 64)
    @test all(p ≥ 0 for p in values(pmf))
    s = sum(values(pmf))
    @test s > BigFloat("0.99")
    @test s ≤ BigFloat(1) + BigFloat("1e-20")
end

@testset "expected_max_distribution: peak DU(n=8 permutation) ≈ 8" begin
    # For a uniformly random function F₂⁸ → F₂⁸, expected DU is around 8 (Daemen-Rijmen; matches the well-known fact that 4-uniform S-boxes like AES are uncommon).
    pmf = expected_differential_uniformity_distribution(8; vmax = 32)
    peak = argmax(pmf)
    @test peak in 6:12
end

@testset "expected_max_distribution: smaller n → smaller expected max" begin
    # Smaller domains should have smaller expected maxima.
    peak4 = argmax(expected_differential_uniformity_distribution(4; vmax = 32))
    peak8 = argmax(expected_differential_uniformity_distribution(8; vmax = 32))
    @test peak4 ≤ peak8
end

end
