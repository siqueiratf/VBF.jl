@testset "section6_1_test" begin
    include(joinpath(@__DIR__, "..", "section6_1.jl"))

    r = section6_1_report(devnull)
    @test r.valid_count > 0
    @test r.ea_classes >= 1
    @test r.new_classes >= 1   # paper claims at least one new CCZ-class
    @test r.ok_new_vs_known    # distinct from Gold/hex/Taniguchi/Zhou-Pott
    @test r.ok_all_classified  # sweep produced no unknown class
    @test r.ok_new_case        # new class at F1 (h=2,k=0,r=0), b != 0
    @test r.ok_swap            # Remark 6.3 swap-equivalence
    @test r.ok_tan_f1          # F1 b=0 (h=3,r=2) -> Taniguchi
    @test r.ok_tan_f2          # F2 (k=1,r=2) -> Taniguchi
    @test r.ok_hex_000         # h=k=r=0 -> hexanomial class
    @test r.all_ok

    # n=12 structural identity (cheap part of Section 6.1.3)
    r12 = section6_1_n12_report(devnull; deep = false)
    @test r12.ok_struct
    @test r12.all_ok

    # rank-screen parity spot at n=12 (used by section6_1_n12_sweep)
    mod6 = primitive_polynomial(6)
    Fapn = theorem6_2_sbox(6, 1, 0, 6; modulus = mod6)
    Fnot = theorem6_2_sbox(6, 1, 0, 1; modulus = mod6)
    @test is_quadratic_apn_rank(Fapn)
    @test differential_uniformity(Fapn) == 2
    @test !is_quadratic_apn_rank(Fnot)
    @test differential_uniformity(Fnot) != 2
end
