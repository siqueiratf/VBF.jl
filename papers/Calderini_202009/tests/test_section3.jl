@testset "section3_test" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))

    # ZW(λ) and S_F for Gold x³ n=4
    F = power_sbox(4, 3)
    S = sf_set(F)
    @test 0 ∈ S
    @test length(S) > 1
    for λ in S
        λ == 0 && continue
        @test !isempty(zw_set(F, λ))
    end

    # Observation 1 as an equivalence, on a Procedure-2 admissible pair …
    pr = procedure2_admissible_pair(F)
    @test pr !== nothing
    @test !all(iszero, pr.A2_cols)                       # genuinely A₂ ≠ 0
    @test admissible_check(F, pr.A1_cols, pr.A2_cols)
    @test observation1_criterion(F, pr.A1_cols, pr.A2_cols)

    # … on the trivial admissible pair (A₁ invertible, A₂ = 0) …
    T4 = storage_type(F)
    A1c = random_invertible_cols(4, T4)
    A2c = zeros(T4, 4)
    @test admissible_check(F, A1c, A2c)
    @test observation1_criterion(F, A1c, A2c)

    # … and on random pairs (both sides must agree).
    for _ = 1:20
        rA1 = T4.(rand(0:15, 4))
        rA2 = T4.(rand(0:15, 4))
        @test admissible_check(F, rA1, rA2) == observation1_criterion(F, rA1, rA2)
    end

    # Corollary 1: exact simplex-code counts
    @test corollary1_upper_bound(power_sbox(4, 3); io = devnull) == 16
    @test corollary1_upper_bound(load_apn_function("n5_Gold_x3"); io = devnull) == 64
    @test corollary1_upper_bound(load_apn_function("n5_Kasami_x15"); io = devnull) == 2

    # Proposition 1: computed (not hardcoded) — L∘L₁ gives affine-equivalent output
    @test proposition1_check(load_apn_function("n5_Gold_x3"); io = devnull)
end