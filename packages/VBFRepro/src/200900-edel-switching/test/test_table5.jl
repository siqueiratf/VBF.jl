using SHA
@testset "table5_test" begin
    include(joinpath(@__DIR__, "..", "table5.jl"))

    r = table5_report(devnull)
    @test r.count == 14
    @test r.all_apn                              # every representative is APN
    @test r.nonquad == ["2.11"]                  # exactly one non-quadratic entry
    @test r.degrees["2.11"] == 3                 # 2.11 is degree 3 (Theorem 11)
    @test r.degrees["1.1"] == 2                  # x^3 is quadratic
    @test all(v in (2, 3) for v in values(r.degrees))
    source = only(filter(row->row.name=="2.11",edelpott_table5())).sbox
    @test bytes2hex(sha256(UInt8[b for x in source.lut for b in (Int(x)&255,Int(x)>>8)]))==
        "172609f46c293810b2698896b817a0343b13676c1e0eb78af99f54b6dcfd75b9"

end
