# Phase-2 tests for the CCZ novelty oracle (novelty.jl). Self-contained: embeds two
# real BLP22 catalog LUTs so it needs no downloaded catalog.
include(joinpath(@__DIR__, "..", "novelty.jl"))

# two genuine Beierle–Leander–Perrin 2022 dim-8 APN look-up tables
const BLP_LUT0 = UInt8[0,230,6,188,104,236,135,95,140,35,135,116,22,219,244,101,66,220,98,160,80,172,153,57,2,213,47,164,226,87,38,207,80,34,188,146,141,157,136,196,118,77,151,240,89,0,81,84,90,80,144,198,253,149,222,234,176,243,119,104,229,196,203,182,220,192,69,5,6,120,118,84,149,192,1,8,189,138,192,171,11,111,180,140,171,173,253,167,142,163,60,77,220,147,135,148,197,77,182,98,170,64,48,134,38,231,88,197,187,24,44,211,90,170,15,163,79,221,243,61,117,204,45,200,146,73,35,164,0,71,169,178,175,138,239,150,48,62,148,198,109,1,32,16,96,95,239,140,181,232,211,210,156,234,30,52,187,175,208,152,91,136,24,151,65,240,235,6,193,91,143,73,41,209,142,42,115,216,22,225,19,218,159,10,37,199,77,243,183,55,54,234,97,220,87,182,124,163,163,32,148,96,175,7,123,237,169,99,148,81,132,29,243,84,10,241,173,33,176,96,56,214,204,126,115,90,175,218,219,144,238,249,44,76,253,193,118,116,78,16,206,159,52,57,28,47,15,96,93,69,170,238,125,7,99,69]
const BLP_LUT1 = UInt8[0,136,192,44,123,166,60,133,140,117,32,189,22,186,61,245,23,25,15,101,174,245,49,14,239,144,155,128,183,157,68,10,244,231,176,199,212,146,23,53,32,66,8,14,225,214,78,29,109,248,241,0,143,79,148,48,205,41,61,189,206,127,185,108,232,162,143,161,120,103,152,227,120,67,115,44,9,103,133,143,106,166,213,125,56,161,0,253,142,51,93,132,61,213,105,229,180,101,87,226,127,251,27,251,124,220,243,55,86,163,94,207,184,239,131,176,177,179,13,107,4,34,83,17,236,159,60,43,0,248,171,55,217,116,245,60,16,153,215,58,40,244,104,208,58,68,73,83,33,10,213,154,94,81,65,42,164,254,60,2,246,149,217,222,116,66,220,142,190,172,253,139,221,154,25,58,66,167,181,52,2,178,114,166,126,234,229,21,223,30,195,102,140,182,128,222,190,209,53,62,128,203,224,207,83,77,180,206,35,159,247,47,211,58,128,13,91,150,227,74,74,210,117,137,210,115,90,159,187,79,180,36,134,86,98,214,14,139,109,140,243,212,163,224,88,42,143,153,211,133,239,221,153,154,34,69]

@testset "novelty oracle" begin
    F0 = SBox{8}(BLP_LUT0); F1 = SBox{8}(BLP_LUT1)

    @testset "embedded catalog LUTs are APN & quadratic" begin
        @test differential_uniformity(F0) == 2
        @test differential_uniformity(F1) == 2
        @test algebraic_degree(F0) <= 2
    end

    @testset "sig_hash is deterministic" begin
        @test sig_hash(F0) == sig_hash(SBox{8}(BLP_LUT0))
        @test sig_hash(F0) != sig_hash(F1)
    end

    @testset "classify against / outside catalog" begin
        idx = sigma_index([F0, F1])
        @test classify_against_catalog(F0, idx) == :known        # in catalog
        @test classify_against_catalog(F1, idx) == :known
        @test classify_against_catalog(gold_apn(8, 1), idx) == :new   # Gold absent here
        idx2 = add_sigmas!(copy(idx), [gold_apn(8, 1), gold_apn(8, 3)])
        @test classify_against_catalog(gold_apn(8, 1), idx2) == :known  # now present
    end

    @testset "paper's new classes flagged novel vs small catalog" begin
        reps = representative_sboxes()
        idx = add_sigmas!(sigma_index([F0, F1]), [gold_apn(8, 1), gold_apn(8, 3)])
        # class A (a genuinely new Kuznetsov class) must be :new vs {BLP sample ∪ Gold}
        @test classify_against_catalog(reps.class_a, idx) == :new
        # class E == Gold x³ ⇒ :known
        @test classify_against_catalog(reps.class_e, idx) == :known
    end

    @testset "dim-7 catalog (generic over n)" begin
        # two genuine sboxU reprs7 dim-7 APN representatives
        R7_0 = UInt8[0,1,8,15,64,85,120,107,12,69,39,104,73,20,82,9,96,119,36,53,62,61,74,79,68,27,35,122,31,84,72,5,10,51,49,14,38,11,45,6,117,4,109,26,92,57,116,23,44,3,91,114,30,37,89,100,123,28,47,78,76,63,40,93,80,113,29,58,13,56,112,67,54,95,88,55,110,19,48,75,33,22,32,17,98,65,83,118,111,16,77,52,41,66,59,86,102,127,24,7,87,90,25,18,115,34,46,121,71,2,42,105,81,94,99,106,126,101,124,97,108,43,125,60,70,21,103,50]
        R7_1 = UInt8[0,1,32,51,24,27,116,101,10,99,106,17,39,76,11,114,70,67,72,95,110,105,44,57,123,22,53,74,102,9,100,25,115,20,80,37,54,83,89,46,109,98,14,19,29,16,50,45,66,33,79,62,55,86,118,5,107,96,38,63,43,34,42,49,68,125,15,36,60,7,59,18,87,6,92,31,26,73,93,28,13,48,104,71,69,122,108,65,41,124,12,75,84,3,61,120,112,47,56,117,85,8,81,30,119,64,127,90,103,82,35,4,78,21,40,97,91,2,113,58,126,77,88,121,94,111,52,23]
        G0 = SBox{7}(R7_0); G1 = SBox{7}(R7_1)   # distinct σ (rep 1 vs rep 3)
        @test differential_uniformity(G0) == 2          # dim-7 APN under VBF
        @test algebraic_degree(G0) <= 2
        idx7 = add_sigmas!(Set{UInt128}(), [G0])         # only G0 known
        @test classify_against_catalog(G0, idx7) == :known
        @test classify_against_catalog(G1, idx7) == :new # distinct CCZ class
    end

    @testset "index binary round-trip" begin
        mktempdir() do d
            p = joinpath(d, "idx.bin")
            idx = sigma_index([F0, F1])
            save_index(idx, p)
            @test load_index(p) == idx
        end
    end
end
