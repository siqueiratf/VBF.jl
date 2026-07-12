@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # n=4: both Table 2 representatives are APN but NOT permutations (Theorem 3)
    for F in [table2_luts()...]
        @test differential_uniformity(F) == 2
        @test !is_permutation(F)
    end

    # n=5: x³, x⁵, x⁷, x¹¹, x¹⁵ are all APN permutations (Theorem 3)
    for F in n5_power_sboxes()
        @test differential_uniformity(F) == 2
        @test is_permutation(F)
    end

    # n=5: all 5 power functions are pairwise EA-inequivalent (→ affine-inequivalent)
    powers = n5_power_sboxes()
    for i in 1:length(powers), j in i+1:length(powers)
        @test !are_ea_equivalent(powers[i], powers[j])
    end
end
