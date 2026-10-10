@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))

    luts = table1_luts()
    degs = table1_degrees()
    exps = table1_affine_exponents()
    mod5 = primitive_polynomial(5)

    @test length(luts) == 5

    # OCR reconstruction check: re-inserting the merged s(1)=1 makes every row a
    # permutation of 0..31 (Paper Issue 1).
    for F in luts
        @test sort(Int.(F.lut)) == collect(0:31)
        @test is_permutation(F)
        @test differential_uniformity(F) == 2
    end

    # The paper's degree column.
    @test [algebraic_degree(F) for F in luts] == degs

    # The paper's `Aff.` column.
    for (i, F) in enumerate(luts)
        P = SBox{5}(gf_monomial_lut(5, exps[i]; modulus = mod5))
        @test are_affine_equivalent(F, P)
    end

    # Table 1's five rows are pairwise affine-inequivalent (5 classes).
    for i in 1:5, j in (i+1):5
        @test !are_affine_equivalent(luts[i], luts[j])
    end
end
