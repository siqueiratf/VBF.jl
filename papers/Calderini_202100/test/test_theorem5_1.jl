@testset "theorem5_1_test" begin
    include(joinpath(@__DIR__, "..", "theorem5_1.jl"))

    mod4 = primitive_polynomial(4)
    # GF(2^4)*: cubes have order 5 (b^5=1), non-cubes have b^5 != 1
    # i=1, j=0, m=4

    # One cube element: the primitive element alpha=2, 2^5 in GF(2^4)
    # Check: cube => not APN; non-cube => APN
    for alpha in 1:15
        is_cube = gf_is_dth_power(alpha, 3, 4; modulus = mod4)
        F  = zhou_pott_sbox(4, 1, 0, alpha; modulus = mod4)
        du = differential_uniformity(F)
        @test is_cube ? (du != 2) : (du == 2)
    end

    # Full report
    r = theorem5_1_report(devnull; m = 4)
    @test r.all_ok
    @test r.cube_failures == 0
    @test r.ok_cor57
end
