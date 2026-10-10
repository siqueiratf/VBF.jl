@testitem "polynomial" begin

using VBF
using Test
import GaloisFields

@testset "CONWAY_POLYNOMIALS match the authoritative GaloisFields database" begin
    encode(coeffs) = foldl((acc, ic) -> acc | ((Int(ic[2]) & 1) << (ic[1] - 1)),
                           enumerate(coeffs); init = 0)
    for (n, modulus) in CONWAY_POLYNOMIALS
        @test encode(GaloisFields.conwaypolynomial(2, n)) == modulus
    end
    # also exercise the accessor
    @test conway_polynomial(8) == CONWAY_POLYNOMIALS[8]
end

@testset "primitive_polynomial: lookup + range check" begin
    @test primitive_polynomial(4) == 0b10011         # x^4 + x + 1
    @test primitive_polynomial(8) == 0b100011011     # Rijndael
    @test primitive_polynomial(5) == 0b100101        # matches catalog n=5 convention

    @test_throws ArgumentError primitive_polynomial(1)
    @test_throws ArgumentError primitive_polynomial(17)
end

@testset "gf_mul: small cases by hand" begin
    # GF(4) with x² + x + 1.  Elements: {0, 1, x, x+1}. x · x = x² = x + 1 (since x² + x + 1 = 0)
    @test gf_mul(0b10, 0b10, 2) == 0b11
    # x · (x+1) = x² + x = (x+1) + x = 1
    @test gf_mul(0b10, 0b11, 2) == 0b01
    # (x+1) · (x+1) = x² + 1 = (x+1) + 1 = x
    @test gf_mul(0b11, 0b11, 2) == 0b10
end

@testset "gf_mul: GF(2^4) reproduces existing n=4 Gold APN" begin
    # Direct check that gf_mul matches the conventions used by the hand-written n4_Gold_x3 LUT (modulus x⁴ + x + 1).
    @test gf_mul(2, 2, 4) == 4        # x · x = x²
    @test gf_mul(2, 8, 4) == 3        # x · x³ = x⁴ = x + 1 (reduces)
    @test gf_mul(3, 3, 4) == 5        # (x+1)² = x² + 1
end

@testset "gf_mul: identity and zero" begin
    for n in 2:8
        for a in 0:(1 << n) - 1
            @test gf_mul(a, 0, n) == 0
            @test gf_mul(0, a, n) == 0
            @test gf_mul(a, 1, n) == a
            @test gf_mul(1, a, n) == a
        end
    end
end

@testset "gf_mul: commutative + closed" begin
    for n in 2:6
        mask = (1 << n) - 1
        for a in 0:mask, b in 0:mask
            r = gf_mul(a, b, n)
            @test 0 ≤ r ≤ mask          # closed in n bits
            @test gf_mul(a, b, n) == gf_mul(b, a, n)
        end
    end
end

@testset "gf_pow: basic identities" begin
    for n in 2:6
        @test gf_pow(0, 0, n) == 1
        @test gf_pow(0, 5, n) == 0
        @test gf_pow(1, 100, n) == 1
        # a^1 = a
        for a in 0:(1 << n) - 1
            @test gf_pow(a, 1, n) == a
        end
        # a^(2^n - 1) = 1 for nonzero a (Fermat)
        for a in 1:(1 << n) - 1
            @test gf_pow(a, (1 << n) - 1, n) == 1
        end
    end
end

@testset "gf_pow: rejects negative exponent" begin
    @test_throws ArgumentError gf_pow(2, -1, 4)
end

@testset "gf_inv: round-trip a · a⁻¹ = 1" begin
    for n in 2:8
        for a in 1:(1 << n) - 1
            inv = gf_inv(a, n)
            @test gf_mul(a, inv, n) == 1
        end
    end
end

@testset "gf_inv: rejects zero" begin
    @test_throws ArgumentError gf_inv(0, 4)
end

@testset "gf_monomial_lut: matches the committed n=4 Gold x³ LUT" begin
    expected = [0, 1, 8, 15, 12, 10, 1, 1, 10, 15, 15, 12, 8, 10, 8, 12]
    @test gf_monomial_lut(4, 3) == expected
end

@testset "gf_monomial_lut: matches the committed n=5 entries" begin
    # n=5 LUTs committed in src/entries/apn_catalog/n5_apn.toml were computed with x⁵ + x² + 1 = 37 as the modulus.
    @test gf_monomial_lut(5, 3)  == [0, 1, 8, 15, 10, 31, 23, 4, 26, 25, 3, 6, 9, 30, 5, 20,
                                       14, 18, 22, 12, 24, 16, 21, 27, 2, 28, 11, 19, 13, 7, 17, 29]
    @test gf_monomial_lut(5, 5)  == [0, 1, 5, 22, 17, 25, 4, 30, 31, 24, 18, 7, 20, 26, 9, 21,
                                       12, 6, 23, 15, 16, 19, 27, 10, 14, 2, 29, 3, 8, 13, 11, 28]
    @test gf_monomial_lut(5, 15) == [0, 1, 31, 21, 18, 28, 10, 17, 29, 2, 22, 4, 24, 11, 25, 16,
                                       9, 23, 27, 20, 14, 12, 19, 3, 5, 8, 7, 15, 26, 30, 6, 13]
end

@testset "gf_monomial_lut: x^(2^n - 2) is the multiplicative inverse on nonzeros" begin
    for n in 2:7
        d = (1 << n) - 2          # Fermat inverse exponent
        lut = gf_monomial_lut(n, d)
        @test lut[1] == 0          # 0^d = 0 by convention
        for a in 1:(1 << n) - 1
            @test gf_mul(a, lut[a + 1], n) == 1
        end
    end
end

@testset "explicit modulus override" begin
    # Use the AES modulus explicitly; should match the default for n=8.
    rijndael = 0b100011011
    @test gf_mul(0x53, 0xca, 8; modulus = rijndael) == gf_mul(0x53, 0xca, 8)
end

@testset "quadratic coefficient encoding round-trips" begin
    n = 8; mod = conway_polynomial(n)
    # n=8 quadratic support: 1 constant + 8 linear + 28 quadratic = 37 exponents
    @test length(quadratic_exponents(8)) == 37
    @test all(count_ones(e) ≤ 2 for e in quadratic_exponents(8))
    # a degree-2 polynomial (Simon-Berg shape): encode → 37 bytes → decode == LUT
    expr = "a^85*X^160 + a^170*X^132 + X^130 + X^3"
    terms = polynomial_terms(expr, n, mod)
    bytes = encode_quadratic(terms, n)
    @test length(bytes) == 37                       # cld(8,8)=1 byte per coeff
    @test decode_quadratic_lut(bytes, n, mod) == polynomial_to_lut(expr, n, mod)
    # a power table speeds decode and gives the same answer
    powtab = monomial_power_table(n, mod)
    @test decode_quadratic_lut(bytes, n, mod; powtab = powtab) ==
          polynomial_to_lut(expr, n, mod)
    # non-quadratic exponent (weight 3 = 7 = 1+2+4) is rejected
    @test_throws ErrorException encode_quadratic([(1, 7)], n)
end

@testset "quadratic coefficient encoding from a LUT (interpolation)" begin
    n = 8; mod = conway_polynomial(n)
    # Gold x³ over this field is quadratic APN; recover its coefficients from the LUT
    gold = SBox{n}(gf_monomial_lut(n, 3; modulus = mod))
    bytes = encode_quadratic(gold; modulus = mod)
    @test length(bytes) == 37
    @test decode_quadratic_lut(bytes, n, mod) == Int.(gold.lut)
    # LUT-interpolation agrees with the term-based encoding of the same polynomial, and recovers exactly X³ (only the weight-2 exponent 3 is set)
    @test bytes == encode_quadratic(polynomial_terms("X^3", n, mod), n)
    @test decode_quadratic_lut(bytes, n, mod) == terms_to_lut([(1, 3)], n, mod)
    # a higher-degree map (inverse x^(2ⁿ-2), degree n-1) is rejected, not truncated
    apninv = SBox{n}(gf_monomial_lut(n, (1 << n) - 2; modulus = mod))
    @test_throws ErrorException encode_quadratic(apninv; modulus = mod)
    # a shared power table yields the identical encoding
    powtab = monomial_power_table(n, mod)
    @test encode_quadratic(gold; modulus = mod, powtab = powtab) == bytes
    # a smaller field round-trips too (n=6 Gold x³)
    m6 = conway_polynomial(6)
    g6 = SBox{6}(gf_monomial_lut(6, 3; modulus = m6))
    @test decode_quadratic_lut(encode_quadratic(g6; modulus = m6), 6, m6) == Int.(g6.lut)
end

end
