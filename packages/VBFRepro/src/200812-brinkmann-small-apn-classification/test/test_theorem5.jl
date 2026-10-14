@testset "theorem5_test" begin
    include(joinpath(@__DIR__, "..", "theorem5.jl"))

    F1, F2 = table2_luts()
    mod4 = primitive_polynomial(4)
    G3_4 = SBox{4}([gf_pow(x, 3, 4; modulus = mod4) for x in 0:15])

    # n=4: both APN
    @test differential_uniformity(F1) == 2
    @test differential_uniformity(F2) == 2

    # n=4: distinct algebraic degrees (EA invariant)
    @test algebraic_degree(F1) == 2
    @test algebraic_degree(F2) == 3

    # n=4: EA-inequivalent, and F1 is the Gold class. Every verdict below must be
    # a *decided* one — `ea_verdict` returns `missing` rather than a best-effort
    # `false` when the bounded search is capped.
    @test ea_verdict(F1, F2)[1] === false
    @test ea_verdict(F1, G3_4)[1] === true
    @test ea_verdict(F2, G3_4)[1] === false

    # n=4: F2 IS EA-equivalent to the closed-form BCP eq. (5) construction. The
    # non-permutation EA route is a complete inner-affine enumeration and settles
    # this outright, so the old CCZ workaround is unnecessary.
    F5 = formula5_n4()
    @test ea_verdict(F2, F5)[1] === true
    @test ea_verdict(F1, F5)[1] === false

    # n=5: every one of the 21 pairs among the 7 EA representatives is decided,
    # and all 21 come out inequivalent. Since the native EA refinement in VBF,
    # the EA oracle decides all 21 directly; CCZ separation stays as a fallback.
    fns = n5_all_seven()
    classes = [n5_ccz_class(F) for F in fns]
    @test all(c !== nothing for c in classes)
    n_ccz = 0
    for i in 1:7, j in (i+1):7
        v, why = ea_verdict(fns[i], fns[j]; class_F = classes[i], class_G = classes[j])
        @test v === false          # decided, and inequivalent
        startswith(why, "CCZ") && (n_ccz += 1)
    end
    @test n_ccz == 0

    # The two pairs that the old capped EA search could not settle, (x⁷,x¹¹) and
    # (f6(1),f6(2)): the EA oracle now decides them ...
    @test are_ea_equivalent(fns[3], fns[4]; on_inconclusive = :missing) === false
    @test are_ea_equivalent(fns[6], fns[7]; on_inconclusive = :missing) === false
    # ... and the CCZ separation independently agrees.
    @test classes[3] != classes[4]
    @test classes[6] != classes[7]

    # n=5: formula6 functions are APN
    mod5 = primitive_polynomial(5)
    f6_1 = formula6_n5(1; modulus = mod5)
    f6_2 = formula6_n5(2; modulus = mod5)
    @test differential_uniformity(f6_1) == 2
    @test differential_uniformity(f6_2) == 2
end
