@testset "lemma2_1_test" begin
    include(joinpath(@__DIR__, "..", "lemma2_1.jl"))

    io = IOBuffer()
    r = lemma2_1_report(io; m_values = (3, 4))

    # The criterion must agree with the ground-truth DDT on every pair...
    @test isempty(r.disagreements)
    @test r.agree == r.checked
    # ...and the corpus must contain BOTH verdicts, or the agreement above could
    # be produced by a criterion that always answers the same thing.
    @test r.positives > 0
    @test r.negatives > 0
    @test r.all_ok

    # Spot-check the criterion directly against differential_uniformity.
    fld = BiField(4)
    F = family_f1(fld, 3)
    @test biprojective_is_apn(F)
    @test differential_uniformity(bipair_sbox(F)) == 2
    @test biprojective_apn_witness(F) === nothing

    # A deliberately inadmissible Taniguchi (d chosen so x^{q+1}+x+d has a root)
    # must be rejected by the criterion AND by the DDT.
    dbad = findfirst(x -> !taniguchi_valid(fld, 1, x), 0:15) - 1
    G = taniguchi(fld, 1, dbad)
    @test !biprojective_is_apn(G)
    @test differential_uniformity(bipair_sbox(G)) > 2
    w = biprojective_apn_witness(G)
    @test w !== nothing && w.count != 2      # the criterion names the failing u

    # Table 2.1's Gold row for even m: the reading b = Σ_{i<k} a^{2^i} (from the
    # PDF) is APN, while the OCR'd tex's b = Σ_{i<k} a^{2^{2i}} is not.
    a = findfirst(x -> gf_trace(x, 4; modulus = fld.modulus) == 1, 0:15) - 1
    @test biprojective_is_apn(gold_even(fld, 3, a))
    b_ocr = reduce(⊻, [frob(fld, a, 2i) for i = 0:2]; init = 0)
    gold_ocr = BiPair(BiProj(3, (1, 0, b_ocr, a)), BiProj(3, (0, 1, 1, b_ocr ⊻ 1)), fld, "ocr")
    @test !biprojective_is_apn(gold_ocr)
end
