@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))

    # Field sanity: u = x is primitive of order 63 over GF(2^6), modulus 91.
    @test ep_pow(EP_U, 63) == 1
    @test all(ep_pow(EP_U, d) != 1 for d in (1, 3, 7, 9, 21))

    r = proposition2_report(devnull; max_n = 6)
    @test r.all_apn
    @test all(c.du == 2 for c in r.checked)
    @test any(c.n == 6 for c in r.checked)
end
