using BFA
using Test

@testset "to_markdown(SBox): header + body, wrapped" begin
    s = SBox(UInt8[0, 1, 2, 3])
    md = to_markdown(s)
    @test occursin("| x | 0 | 1 | 2 | 3 |", md)
    @test occursin("| F(x) | 0 | 1 | 2 | 3 |", md)
    # wrapping: an 8-bit identity wraps into 2^8/16 = 16 blocks, each with
    # its own header row (distinct column indices); the first is 0..15.
    big = SBox{8}(collect(0:255))
    lines = split(to_markdown(big), '\n')
    @test count(l -> startswith(l, "| x | "), lines) == 16
    @test lines[1] == "| x | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |"
end

@testset "to_latex(SBox): array with x and F(x) rows" begin
    s = SBox(UInt8[3, 2, 1, 0])
    tex = to_latex(s)
    @test occursin("\\begin{array}{c|cccc}", tex)
    @test occursin("x & 0 & 1 & 2 & 3 \\\\", tex)
    @test occursin("F(x) & 3 & 2 & 1 & 0 \\\\", tex)
    @test occursin("\\end{array}", tex)
end

@testset "table_to_markdown / table_to_latex on a DDT" begin
    F = load_literature_sbox("PRESENT")
    D = ddt(F)
    md = table_to_markdown(D; corner = "a\\b")
    lines = split(md, '\n')
    @test startswith(lines[1], "| a\\b | 0 |")
    @test length(lines) == size(D, 1) + 2     # header + separator + one row per a
    # the (0,0) DDT entry is 2ⁿ
    @test occursin("| 0 | $(1 << inputbits(F))", md)

    tex = table_to_latex(D)
    @test occursin("\\begin{array}{c|", tex)
    @test occursin("\\end{array}", tex)
    @test count("\\\\", tex) == size(D, 1) + 1   # header + each row
end
