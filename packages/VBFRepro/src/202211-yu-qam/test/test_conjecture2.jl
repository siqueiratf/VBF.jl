using Test

@testset "Conjecture 2: H_8 reproduces the QAM of x^3" begin
    # The normal-basis (γ = g^11) QAM of x^3 must match the literal g-power
    # block of Conjecture 2, and the whole seed matrix must be a QAM.
    @test base_matches_paper()
    @test is_qam(h8_base())
end

@testset "Conjecture 2: seed recovery" begin
    s = conjecture2_recovers_seed()
    @test s.matches_paper_block
    @test s.base_is_qam
    @test s.sbox_is_apn
    @test s.sbox_is_quadratic
    @test s.is_gold_class
end

@testset "Conjecture 2: h8_from_vars round-trips the seed" begin
    @test h8_from_vars(h8_base_vars()) == h8_base()
    # variable layout: x_13 sits at H_8[1,7], x_1 at H_8[7,8]
    @test H8_VAR_POSITION[13] == (1, 7)
    @test H8_VAR_POSITION[1] == (7, 8)
end

@testset "Conjecture 2: bounded search recovers the Gold class" begin
    r = conjecture2_search(; vary = [13], max_evaluations = 1 << 16)
    @test r.exhaustive            # 256 candidates < budget
    @test r.qam_hits == 1         # only the seed value of x_13 keeps H_8 a QAM
    @test r.n_classes == 1
    gold_mug = apn_ea_mugshot(gold_apn(8, 1))
    @test any(apn_ea_mugshot(F) == gold_mug for F in r.found)
end
