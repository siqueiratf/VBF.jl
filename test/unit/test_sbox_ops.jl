using BFA
using Test

@testset "is_permutation" begin
    @test is_permutation(SBox(UInt8[0, 1, 2, 3]))
    @test !is_permutation(SBox(UInt8[0, 0, 2, 3]))   # duplicate
    @test !is_permutation(SBox(UInt8[1, 1, 1, 1]))   # constant
end

@testset "is_permutation: literature catalog" begin
    for name in literature_sbox_names()
        meta = literature_sbox_metadata(name)
        @test is_permutation(load_literature_sbox(name)) == meta["is_permutation"]
    end
end

@testset "inv: involutive" begin
    # inv(inv(s)) == s for every permutation
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        if is_permutation(s)
            @test inv(inv(s)) == s
        end
    end
end

@testset "inv: s ∘ inv(s) is identity" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        is_permutation(s) || continue
        sinv = inv(s)
        n = 1 << inputbits(s)
        for x in 0:n - 1
            @test s(sinv(x)) == x
            @test sinv(s(x)) == x
        end
    end
end

@testset "inv: AES_inv from catalog equals inv(AES)" begin
    @test load_literature_sbox("AES_inv") == inv(load_literature_sbox("AES"))
end

@testset "inv: rejects non-permutation" begin
    @test_throws ArgumentError inv(SBox(UInt8[0, 0, 2, 3]))
end
