@testitem "classification keys are mathematical filters with stable encoding" begin
    using VBF
    using Test

    F = gold_apn(5, 1)
    # Regression constants preserve the encoding used by existing catalog indexes.
    @test sigma_hash(F) == "36db60f3f69fca081579254e2215c820e946202d5c462d65c334662370641af1"
    pi=ortho_derivative(F)
    @test VBF.sigma_key_from_ortho_derivative(pi)==sigma_key(F)
    @test VBF.sigma_hash_from_ortho_derivative(pi)==sigma_hash(F)
    @test ccz_fingerprint_hash(F) == "e0d37a657d16075654a0318a7419114a27995cbd25a9a7b3a198788d01add282"
    # Adding an affine output term preserves the EA and hence CCZ class.
    G = SBox{5,UInt8}(UInt8[F.lut[x+1] ⊻ UInt8(x) ⊻ 0x13 for x in 0:31])
    @test sigma_key(F) == sigma_key(G)
    @test ccz_fingerprint_key(F) == ccz_fingerprint_key(G)
    @test_throws ErrorException sigma_key(SBox{5,UInt8}(UInt8.(0:31)))
end
