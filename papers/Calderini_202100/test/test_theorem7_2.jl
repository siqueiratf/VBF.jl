@testset "theorem7_2_test" begin
    include(joinpath(@__DIR__, "..", "theorem7_2.jl"))

    r = theorem7_2_report(devnull)
    @test r.all_ok

    # Gologlu F2 at (m=5,i=2) is the Proposition 7.5 comparison target
    F = _gologlu_f2(5, 2; modulus = primitive_polynomial(5))
    @test differential_uniformity(F) == 2
end
