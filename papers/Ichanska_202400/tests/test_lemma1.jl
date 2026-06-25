@testset "lemma1_test" begin
    include(joinpath(@__DIR__, "..", "lemma1.jl"))

    n = 8; m = 2; mod_n = conway_polynomial(n)
    cat1, cat_ind = compute_categories(n, m; modulus = mod_n)

    # |Cat₁| = 3 = |F₄ \ {0}| for (n=8, m=2)
    @test length(cat1) == 3

    # |Cat_Ind| = 252 = 255 - 3
    @test length(cat_ind) == 252

    # Together partition F₂⁸ \ {0}
    @test length(cat1) + length(cat_ind) == (1 << n) - 1

    # Cat₁ = {1, a^85, a^170} (elements of F₄ \ {0})
    a85  = gf_pow(2, 85,  n; modulus = mod_n)
    a170 = gf_pow(2, 170, n; modulus = mod_n)
    @test Set(cat1) == Set([1, a85, a170])

    # a (= 2) is NOT in Cat₁
    @test !is_in_cat1(2, n, m; modulus = mod_n)

    # Linear perms with F₂² coefficients preserve Cat₁
    @test verify_lemma1_preservation(n, m; modulus = mod_n, num_perms = 20)
end
