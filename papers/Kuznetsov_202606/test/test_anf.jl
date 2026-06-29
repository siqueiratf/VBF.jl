# Tests for the compact .anf quadratic-function storage (anf.jl).
include(joinpath(@__DIR__, "..", "anf.jl"))
using .ANF

# build a LUT from a chosen ANF over F2^8: f(x) bit b = XOR of monomials present
quad_lut(pairbit) = UInt8[ (((x & 3) == 3) ? 0x1 : 0x0) for x in 0:255 ]   # bit0 = x0·x1
cubic_lut()       = UInt8[ (((x & 7) == 7) ? 0x1 : 0x0) for x in 0:255 ]   # bit0 = x0·x1·x2

@testset "anf storage" begin
    @testset "pack/unpack round-trip (quadratic)" begin
        lut = quad_lut(true)
        c = anf_pack(lut)
        @test c !== nothing
        @test length(c) == 37
        @test anf_unpack(c) == lut
    end

    @testset "rejects non-quadratic" begin
        @test anf_pack(cubic_lut()) === nothing      # degree 3 ⇒ not storable
    end

    @testset "file format round-trip" begin
        mktempdir() do d
            txt = joinpath(d, "c.txt"); anf = joinpath(d, "c.anf")
            luts = [quad_lut(true),
                    UInt8[ (((x & 6) == 6) ? 0x2 : 0x0) for x in 0:255 ],   # bit1 = x1·x2
                    UInt8[ (((x & 5) == 5) ? 0x4 : 0x0) for x in 0:255 ]]   # bit2 = x0·x2
            open(txt, "w") do io
                for l in luts; println(io, "[" * join(Int.(l), ",") * "]"); end
            end
            count, skipped = ANF.pack_text_file(txt, anf)
            @test count == 3 && skipped == 0
            @test read_anf_luts(anf) == luts
            @test filesize(anf) < filesize(txt)          # compact
        end
    end
end
