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

    @testset "index binary round-trip" begin
        mktempdir() do d
            p = joinpath(d, "idx.bin")
            idx = sigma_index([F0, F1])
            save_index(idx, p)
            @test load_index(p) == idx
        end
    end
end
