using VBF
using Test

@testset "FBCT row/column 0 are 2^N" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        F = fbct(s)
        n = 1 << inputbits(s)
        for a in 1:n
            @test F[a, 1] == n      # column b=0
        end
        for b in 1:n
            @test F[1, b] == n      # row a=0
        end
    end
end

@testset "FBCT diagonal F[a, a] == 2^N (b = a ⇒ F(x) ⊕ F(x⊕a) ⊕ F(x⊕a) ⊕ F(x) = 0)" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        F = fbct(s)
        n = 1 << inputbits(s)
        for a in 1:n
            @test F[a, a] == n
        end
    end
end

@testset "FBCT symmetry: F[a, b] == F[b, a]" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        F = fbct(s)
        @test F == transpose(F)
    end
end

@testset "FBCT entries are even (N ≥ 2)" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        @test all(iseven, fbct(s))
    end
end

@testset "FBCT does NOT require a permutation" begin
    # Constant function: still well-defined; row 0, col 0, and diagonal still 2^N.
    s = SBox(UInt8[7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7])
    F = fbct(s)
    @test F[1, 1] == 16
    @test all(F .== 16)   # constant F gives F(anything) = 7, sum of 4 copies = 0
end

@testset "fbct_spectrum / fbct_uniformity catalog (locked)" begin
    # PRESENT: 4-bit S-box; computed and locked to current value.
    @test fbct_uniformity(load_literature_sbox("PRESENT"))  ≤ 16
    @test fbct_uniformity(load_literature_sbox("GIFT"))     ≤ 16
    @test fbct_uniformity(load_literature_sbox("SKINNY_4")) ≤ 16

    # Spectrum total mass excludes row 0, col 0, and the b = a diagonal:
    # (n-1)·(n-1) - (n-1) = (n-1)(n-2)
    n = 16
    @test total_mass(fbct_spectrum(load_literature_sbox("PRESENT"))) == (n - 1) * (n - 2)
end
