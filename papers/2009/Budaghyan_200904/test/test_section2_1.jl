@testset "section2_1_test" begin
    include(joinpath(@__DIR__, "..", "section2_1.jl"))

    # n=5 example: x⁵+tr(x³) APN and CCZ-equivalent to Gold.
    F5 = gold_plus_trace(5, 5, 3)
    @test differential_uniformity(F5) == 2                    # APN
    @test are_ccz_equivalent(F5, gold_apn(5, 1))             # CCZ-equiv Gold

    # Opt-in dependence search at n=5: nonzero kernel, every basis vector gives
    # APN (exhaustive over the kernel basis, not just a sample).
    r = dependence_search(devnull; n = 5, r = 1)
    @test r.kdim ≥ 1
    @test r.checks == r.kdim
    @test r.verified == r.checks

    # Theorem-1 kernel-membership oracle predicts APN-ness exactly, including the
    # negative case x⁹+tr(x³) at n=7 (out-of-kernel, du=4 — the paper claims that
    # function only at n=8). (n, r, i, gold_exp, trace_exp):
    for (n, rr, i, ge, te) in [
        (5, 1, 3, 3, 9), (7, 1, 3, 3, 9), (8, 1, 3, 3, 9),   # x³+tr(x⁹): APN ∀n
        (5, 2, 1, 5, 3),                                     # x⁵+tr(x³): APN n=5
        (8, 3, 1, 9, 3), (7, 3, 1, 9, 3),                    # x⁹+tr(x³): APN n=8, not n=7
    ]
        @test g_in_kernel(n, rr, i, 0) ==
              (differential_uniformity(gold_plus_trace(n, ge, te)) == 2)
    end
    @test !g_in_kernel(7, 3, 1, 0)                            # x⁹+tr(x³) out-of-kernel at n=7
    @test differential_uniformity(gold_plus_trace(7, 9, 3)) == 4
end
