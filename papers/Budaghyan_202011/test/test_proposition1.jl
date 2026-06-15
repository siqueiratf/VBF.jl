@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    # Proposition 1: E_i trivial ↔ C_i APN, for a sample of i-values in n=10
    # (full check over all i=1..9 runs in ~8s; test checks a balanced sample)
    apn_i_vals     = [3, 7]   # Theorem 4 cases (should be trivial)
    non_apn_i_vals = [1, 2]   # non-Theorem-4 cases (should have non-trivial solutions)

    for i in apn_i_vals
        @test system_Ei_trivial(10, i)
        @test differential_uniformity(build_ci_sbox(10, i)) == 2
    end

    for i in non_apn_i_vals
        @test !system_Ei_trivial(10, i)
        @test differential_uniformity(build_ci_sbox(10, i)) != 2
    end
end
