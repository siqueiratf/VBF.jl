@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    # Conditions (1),(2) hold for the Gold instance F=x³, f=tr(x⁹) at n=5.
    n = 5
    F = gold_apn(n, 1)
    f_lut = [gf_trace(gf_pow(x, 9, n), n) for x = 0:((1 << n) - 1)]
    c1, c2 = theorem1_conditions(F, f_lut, ell_gold_x9(n); n)
    @test c1 && c2
    @test differential_uniformity(apn_x3_tr_x9(n)) == 2      # F+f is APN

    r = theorem1_report(devnull; n_max = 5)
    @test r.all_ok
end
