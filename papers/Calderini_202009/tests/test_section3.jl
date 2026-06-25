@testset "section3_test" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))

    # ZW(λ) and S_F for Gold x³ n=4
    F = power_sbox(4, 3)
    S = sf_set(F)
    @test 0 ∈ S
    @test length(S) > 1

    # ZW(λ) for λ ∈ S_F is non-empty (excluding λ=0)
    for λ in S
        λ == 0 && continue
        zw = zw_set(F, λ)
        @test !isempty(zw)
    end

    # Corollary 1: upper bound ≥ 1 for Gold x³ n=4
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, 4; max_bits = 8)
    @test length(bases) >= 1

    # Corollary 1: n=5 Gold x³ — known to have 3 CCZ-class representatives via subspaces
    F5 = load_apn_function("n5_Gold_x3")
    Z5 = walsh_zeroes(F5)
    bases5 = extract_linear_subspaces(Z5, 5; max_bits = 10)
    @test length(bases5) >= 2
end
