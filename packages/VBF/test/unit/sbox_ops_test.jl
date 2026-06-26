@testitem "sbox_ops" begin
using VBFCatalog
using VBF
using Test

@testset "is_permutation" begin
    @test is_permutation(SBox(UInt8[0, 1, 2, 3]))
    @test !is_permutation(SBox(UInt8[0, 0, 2, 3]))   # duplicate
    @test !is_permutation(SBox(UInt8[1, 1, 1, 1]))   # constant
end

@testset "compositional_inverse" begin
    # round-trip: s⁻¹∘s = s∘s⁻¹ = id, and the inverse is an involution under inversion
    for n in (3, 5, 7)
        s = gold_apn(n, 1)               # x³ is a permutation for odd n
        @test is_permutation(s)
        inv = compositional_inverse(s)
        @test all(inv(s(x)) == x for x = 0:((1 << n) - 1))
        @test all(s(inv(x)) == x for x = 0:((1 << n) - 1))
        @test compositional_inverse(inv) == s
        @test typeof(inv) == typeof(s)   # preserves {N,T}
    end
    # a known permutation S-box inverts to its functional inverse
    aes = load_literature_sbox("AES")
    ainv = compositional_inverse(aes)
    @test all(ainv(aes(x)) == x for x = 0:255)
    # non-permutations are rejected
    @test_throws ArgumentError compositional_inverse(gold_apn(6, 1))   # even n → 2-to-1
    @test_throws ArgumentError compositional_inverse(SBox(UInt8[0, 0, 2, 3]))
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

end
