@testitem "finite_field_trace" begin
using VBF
using Test

@testset "gf_trace: image, balance, parity with power-sum formula" begin
    for n in 2:8
        mod = primitive_polynomial(n)
        # the absolute trace maps into GF(2) = {0, 1}
        @test all(gf_trace(x, n; modulus = mod) in (0, 1) for x = 0:((1 << n) - 1))
        # a surjective F2-linear form is balanced: exactly half the field has trace 1
        @test count(x -> gf_trace(x, n; modulus = mod) == 1, 0:((1 << n) - 1)) == 1 << (n - 1)
        @test gf_trace(0, n; modulus = mod) == 0
        # parity with the explicit Frobenius power sum x ⊕ x² ⊕ … ⊕ x^{2^{n-1}}
        for x = 0:((1 << n) - 1)
            ref = reduce(xor, (gf_pow(x, 1 << j, n; modulus = mod) for j = 0:(n - 1)))
            @test gf_trace(x, n; modulus = mod) == ref
        end
    end
end

@testset "gf_relative_trace: lands in subfield, additive, k=n and k=1 edge cases" begin
    for (n, k) in ((4, 2), (6, 2), (6, 3), (8, 2), (8, 4))
        mod = primitive_polynomial(n)
        sub = Set(subfield_elements(n, k; modulus = mod))
        for x = 0:((1 << n) - 1)
            @test gf_relative_trace(x, n, k; modulus = mod) in sub
        end
        # Tr_{2^n/2^k} is F2-linear: additive over ⊕
        for x = 0:7, y = 0:7
            a = gf_relative_trace(x ⊻ y, n, k; modulus = mod)
            b = gf_relative_trace(x, n, k; modulus = mod) ⊻ gf_relative_trace(y, n, k; modulus = mod)
            @test a == b
        end
    end
    # Tr_{2^n/2^n} is the identity; Tr_{2^n/2} equals the absolute trace
    for n in 2:6
        mod = primitive_polynomial(n)
        @test all(gf_relative_trace(x, n, n; modulus = mod) == x for x = 0:((1 << n) - 1))
        @test all(gf_relative_trace(x, n, 1; modulus = mod) == gf_trace(x, n; modulus = mod)
                  for x = 0:((1 << n) - 1))
    end
end

@testset "in_subfield / subfield_elements: size, membership, nesting" begin
    for (n, k) in ((4, 2), (6, 2), (6, 3), (8, 2), (8, 4), (6, 6))
        mod = primitive_polynomial(n)
        elems = subfield_elements(n, k; modulus = mod)
        @test length(elems) == 1 << k                 # |GF(2ᵏ)| = 2ᵏ
        @test issorted(elems)
        @test 0 in elems && 1 in elems                # subfield contains 0 and 1
        # subfield_elements is exactly the in_subfield membership set
        @test elems == [x for x = 0:((1 << n) - 1) if in_subfield(x, k, n; modulus = mod)]
        # closed under addition and multiplication
        @test all(a ⊻ b in Set(elems) for a in elems, b in elems)
        @test all(gf_mul(a, b, n; modulus = mod) in Set(elems) for a in elems, b in elems)
    end
    # GF(2¹) = {0,1} sits inside every field
    for n in 2:8
        @test subfield_elements(n, 1) == [0, 1]
    end
end

@testset "gf_is_dth_power: cubes, bijective case, subgroup count" begin
    for n in 2:8
        mod = primitive_polynomial(n)
        m = (1 << n) - 1
        # 0 is a d-th power for every d
        @test gf_is_dth_power(0, 3, n; modulus = mod)
        # parity with the index-(2ⁿ-1, d) subgroup test on nonzero elements
        for x = 1:m
            g = gcd(3, m)
            @test gf_is_dth_power(x, 3, n; modulus = mod) == (gf_pow(x, m ÷ g, n; modulus = mod) == 1)
        end
        # the d-th powers of GF(2ⁿ)* number exactly (2ⁿ-1)/gcd(d, 2ⁿ-1)
        for d in (3, 5, 7)
            cnt = count(x -> gf_is_dth_power(x, d, n; modulus = mod), 1:m)
            @test cnt == m ÷ gcd(d, m)
        end
    end
    # gcd(d, 2ⁿ-1) = 1 ⇒ y↦yᵈ is a bijection ⇒ everything is a d-th power
    @test all(gf_is_dth_power(x, 7, 4) for x = 0:15)   # 7 ∤ 15
    @test all(gf_is_dth_power(x, 3, 5) for x = 0:31)   # 3 ∤ 31 (n odd)
end

@testset "argument validation" begin
    @test_throws ArgumentError gf_relative_trace(1, 6, 4)   # 4 ∤ 6
    @test_throws ArgumentError in_subfield(1, 4, 6)         # 4 ∤ 6
    @test_throws ArgumentError subfield_elements(6, 4)      # 4 ∤ 6
    @test_throws ArgumentError gf_trace(1, 0)               # n ≥ 1
end
end
