@testset "theoremC_3_test" begin
    include(joinpath(@__DIR__, "..", "theoremC_3.jl"))

    io = IOBuffer()
    r = theoremC_3_report(io; m = 6, sample_size = 1)

    @test r.triplicate_identity
    @test r.three_to_one
    @test r.image_ok
    @test r.walsh_matches_corrected == r.sampled
    @test r.walsh_matches_paper == 0       # the printed multiplicities never match
    @test r.all_ok

    # Calibration on Gold, whose spectrum IS the classical one by definition:
    # the corrected multiset matches, the printed one does not.
    @test r.gold_calibration_corrected
    @test !r.gold_calibration_paper

    # The printed multiset is internally impossible: it has more entries than
    # there are pairs (b ≠ 0, a). This is checked against the ARITHMETIC, not
    # against a transcription of itself.
    for n in (6, 8, 10, 12)
        npairs = ((1 << n) - 1) * (1 << n)
        @test sum(values(classical_spectrum_paper(n))) != npairs
        @test sum(values(classical_spectrum_corrected(n))) == npairs
    end

    fld = BiField(6)
    F = family_f4(fld, 1, 2, 1)
    @test f4_triplicate_identity(F)
    S = bipair_sbox(F)
    @test is_3_to_1(S)
    @test length(image_set(S)) == (4096 - 1) ÷ 3 + 1

    # negative: a Gold function on F_2^6 is a PERMUTATION for gcd(k,6)=1? no —
    # x^3 on F_2^6 is 3-to-1 as well, so use a genuinely non-3-to-1 APN instead:
    # the Taniguchi biprojective at m=3 (n=6) is APN but not 3-to-1.
    f3 = BiField(3)
    d = findfirst(x -> taniguchi_valid(f3, 1, x), 0:7) - 1
    T = bipair_sbox(taniguchi(f3, 1, d))
    @test differential_uniformity(T) == 2
    @test !is_3_to_1(T)                    # so `is_3_to_1` is discriminating here
end
