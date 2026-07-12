@testset "proposition2_1_test" begin
    include(joinpath(@__DIR__, "..", "proposition2_1.jl"))

    r = remark2_1_build()
    @test r.du_F == 4          # x^5 is NOT APN over GF(2^6)
    @test r.formula_matches    # F_L = zeta*x^12 + zeta^4*x^33 (closed form)
    @test r.du_FL == 2         # F_L is APN
end
