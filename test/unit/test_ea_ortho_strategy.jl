using BFA
using Test

@testset ":ortho_derivative strategy: quadratic APN reflexivity" begin
    # F ~_EA F via the ortho-derivative path.
    for name in ("n5_Gold_x3", "n5_Gold_x5")
        F = load_apn_function(name)
        @test are_ea_equivalent(F, F; strategy = :ortho_derivative)
    end
end

@testset ":ortho_derivative strategy: distinguishes Frobenius orbits" begin
    # The SHARP result of Phase 10: n5_Gold_x3 and n5_Gold_x5 are NOT
    # EA-equivalent (different Frobenius orbits). Phase 8's :heggebakk
    # short-circuits because the k=4 partition is degenerate; the
    # ortho-derivative path decides correctly in milliseconds.
    F3 = load_apn_function("n5_Gold_x3")
    F5 = load_apn_function("n5_Gold_x5")
    @test !are_ea_equivalent(F3, F5; strategy = :ortho_derivative)
end

@testset ":ortho_derivative strategy: returns false for non-quadratic-APN inputs" begin
    F = load_apn_function("n5_Kasami_x15")   # non-quadratic APN
    P = load_literature_sbox("PRESENT")       # non-APN
    @test !are_ea_equivalent(F, P; strategy = :ortho_derivative)
    @test !are_ea_equivalent(P, F; strategy = :ortho_derivative)
end

@testset ":auto routes quadratic APN to :ortho_derivative" begin
    # The auto-router picks :ortho_derivative for quadratic-APN
    # permutations. Verify by checking that the result agrees with
    # explicitly calling :ortho_derivative.
    F3 = load_apn_function("n5_Gold_x3")
    F5 = load_apn_function("n5_Gold_x5")
    @test are_ea_equivalent(F3, F5; strategy = :auto) ==
          are_ea_equivalent(F3, F5; strategy = :ortho_derivative)
end

@testset ":auto still uses :heggebakk for non-quadratic inputs" begin
    # n=4 PRESENT is a permutation with non-degenerate partition; auto
    # routes to :heggebakk. F ~_EA F always.
    F = load_literature_sbox("PRESENT")
    @test are_ea_equivalent(F, F; strategy = :auto)
end
