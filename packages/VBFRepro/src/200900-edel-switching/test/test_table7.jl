using SHA
@testset "Edel-Pott Table 7 entry 14.3" begin
    include(joinpath(@__DIR__, "..", "table7.jl"))
    r = table7_report(; io=devnull)
    @test r.differential_uniformity == 2
    @test r.degree == 2
    @test r.gamma_rank == 4046
    @test r.delta_rank == 212
    source = edelpott_table7_14_3()
    @test bytes2hex(sha256(UInt8[b for x in source.lut for b in (Int(x)&255,Int(x)>>8)]))==
        "40026b6e90962e0772cea3376ac57b2c4c70c224a6b72b2de1104e4f97e8b119"

end
