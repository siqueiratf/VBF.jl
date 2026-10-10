@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # n=4: both Table 2 representatives are APN but NOT permutations (Theorem 3)
    for F in [table2_luts()...]
        @test differential_uniformity(F) == 2
        @test !is_permutation(F)
        # Stronger, and what actually closes the n=4 statement: neither is even
        # CCZ equivalent to a permutation. With Theorem 6's single n=4 CCZ class
        # this proves no APN permutation exists in F(F₂⁴,F₂⁴).
        @test !is_ccz_equivalent_to_permutation(F)
    end

    # n=5: x³, x⁵, x⁷, x¹¹, x¹⁵ are all APN permutations (Theorem 3)
    powers = n5_power_sboxes()
    for F in powers
        @test differential_uniformity(F) == 2
        @test is_permutation(F)
    end

    # n=5: family attribution. The Kasami exponent 2^{2k}−2^k+1 at k=2 is 13, so
    # x¹¹ (same cyclotomic coset) is Kasami; x¹⁵ is Inverse, whose coset holds
    # 2⁵−2 = 30 and the Dobbertin exponent 29.
    mod5 = primitive_polynomial(5)
    @test are_affine_equivalent(powers[4], kasami_apn(5, 2; modulus = mod5))
    @test are_affine_equivalent(powers[5], inverse_apn(5; modulus = mod5))
    @test gamma_rank(powers[4]) != gamma_rank(powers[5])

    # n=5: all 5 power functions are pairwise affine-inequivalent. Theorem 3 is a
    # classification up to *affine* equivalence and all five are permutations, so
    # `are_affine_equivalent` decides every pair exactly — unlike the EA oracle,
    # which caps on the degenerate monomial partition for (x⁷, x¹¹).
    for i in 1:length(powers), j in (i+1):length(powers)
        @test !are_affine_equivalent(powers[i], powers[j])
    end

    # Theorem 3's inverse relations, on the Table 1 representatives.
    T1 = table1_luts()
    @test are_affine_equivalent(T1[1], compositional_inverse(T1[1]))
    @test are_affine_equivalent(T1[2], compositional_inverse(T1[4]))
    @test are_affine_equivalent(T1[3], compositional_inverse(T1[5]))
end
