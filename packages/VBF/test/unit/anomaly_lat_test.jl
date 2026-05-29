@testitem "anomaly_lat" begin
using VBFCatalog
using VBF
using Test

@testset "lat_coeff_probability (permutation): c not divisible by 4 → 0" begin
    for n in 4:8, c in (1, 2, 3, 5, 6, 7)
        @test lat_coeff_probability(n, n, c; permutation = true) == 0
    end
end

@testset "lat_coeff_probability (function): odd c → 0" begin
    for n in 4:8, c in (1, 3, 5, 7)
        @test lat_coeff_probability(n, n, c; permutation = false) == 0
    end
end

@testset "lat_coeff_probability rejects m ≠ n" begin
    @test_throws ArgumentError lat_coeff_probability(8, 4, 0)
end

@testset "lat_coeff_probability (permutation, n=4): closed-form check" begin
    # C(2^(n-1), 2^(n-2))^2 / C(2^n, 2^(n-1)) = 70^2 / 12870 = 4900/12870.
    p0 = lat_coeff_probability(4, 4, 0; permutation = true)
    @test abs(p0 - BigFloat(4900) / 12870) < BigFloat("1e-30")

    # c = 4: 2 · C(8, 5)^2 / 12870 = 2·56² / 12870 = 6272/12870.
    p4 = lat_coeff_probability(4, 4, 4; permutation = true)
    @test abs(p4 - BigFloat(6272) / 12870) < BigFloat("1e-30")

    # c = 16: 2 · C(8, 8)^2 / 12870 = 2/12870.
    p16 = lat_coeff_probability(4, 4, 16; permutation = true)
    @test abs(p16 - BigFloat(2) / 12870) < BigFloat("1e-30")
end

@testset "lat_coeff_probability (permutation, n=4): PMF sums to 1" begin
    s = sum(lat_coeff_probability(4, 4, 4d; permutation = true) for d in 0:4)
    @test abs(s - BigFloat(1)) < BigFloat("1e-30")
end

@testset "lat_coeff_probability (function, n=4): PMF sums to ~1" begin
    s = sum(lat_coeff_probability(4, 4, 2d; permutation = false) for d in 0:8)
    @test s > BigFloat("0.99")
    @test abs(s - BigFloat(1)) < BigFloat("1e-20")
end

@testset "lat_coeff_probability: c too large for the support" begin
    # For permutations on F₂⁴, c > 16 has zero probability.
    @test lat_coeff_probability(4, 4, 20; permutation = true) == 0
    @test lat_coeff_probability(4, 4, 32; permutation = false) == 0
end

# --- expected_linearity_distribution ----------------------------------------

@testset "expected_linearity_distribution: non-negative + sums close to 1" begin
    pmf = expected_linearity_distribution(8; permutation = true, vmax = 96)
    @test all(p ≥ 0 for p in values(pmf))
    s = sum(values(pmf))
    @test s > BigFloat("0.99")
    @test s ≤ BigFloat(1) + BigFloat("1e-20")
end

@testset "expected_linearity_distribution: AES linearity (32) is in the tail" begin
    # For random permutations of F₂⁸ the linearity peaks at 64+; AES's 32
    # is in the *left* tail (it's much better than random).
    pmf = expected_linearity_distribution(8; permutation = true, vmax = 128)
    p_below_32 = sum(p for (k, p) in pmf if k ≤ 32; init = BigFloat(0))
    @test p_below_32 < BigFloat("0.01")    # extremely unlikely under random
    peak = argmax(pmf)
    @test peak > 32                        # most random permutations have Lin > 32
end
end
