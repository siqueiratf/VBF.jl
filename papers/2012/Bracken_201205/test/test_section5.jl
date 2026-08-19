@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    # Table 1 — known highly nonlinear differentially 4 uniform permutations.
    # Every prior row is recomputed at its smallest instance (BTT-4).
    rows = Dict(l => table1_row(l, n, d) for (l, n, d, _, _) in TABLE1_MONOMIALS)
    @test length(TABLE1_MONOMIALS) == 4
    for (_, r) in rows
        @test r.perm                     # every Table 1 entry is a permutation
        @test r.du == 4                  # …and differentially 4 uniform
    end

    gold = rows["Gold  x^5  (i=2)"]
    kasami = rows["Kasami x^13 (i=2)"]
    inv = rows["Inverse x^62"]
    bl = rows["Bracken–Leander x^73 (k=3)"]

    @test gold.walsh == [-16, 0, 16] && gold.nl == 24 && gold.deg == 2
    @test kasami.walsh == [-16, 0, 16] && kasami.nl == 24 && kasami.deg == 3
    # The inverse function's Walsh set is NOT symmetric at n=6: +16 occurs,
    # −16 does not. Recorded as measured, not as {0,±4,±8,±12,±16}.
    @test inv.walsh == [-12, -8, -4, 0, 4, 8, 12, 16] && inv.nl == 24 && inv.deg == 5
    @test bl.walsh == [-128, -64, 0, 64, 128] && bl.nl == 1984 && bl.deg == 3

    # This paper's own row.
    frow = table1_row_F(2, 4)
    @test frow.perm && frow.du == 4 && frow.walsh == [-16, 0, 16] && frow.deg == 2

    # Section 5's separation argument, verbatim: the inverse function's Walsh
    # spectrum is not a subset of {0, ±2^{n/2}, ±2^{(n+2)/2}} while F's is,
    # hence F is CCZ-inequivalent to the inverse function.
    allowed = Set([0, 8, -8, 16, -16])
    @test !issubset(Set(inv.walsh), allowed)
    @test issubset(Set(frow.walsh), allowed)

    # Paper Issue 2 (a defect of the publication, recorded not "fixed"): at n=6
    # the Theorem 1.1 instance degenerates to the monomial (α+α⁴)x¹⁷, and since
    # 17 = 5·2⁴ mod 63 it is linear-equivalent to Table 1's FIRST row. The n=6
    # instance therefore cannot support the paper's novelty claim.
    @test mod(5 * (1 << 4), 63) == 17
    F6 = bracken_binomial_sbox(2, 4)
    c = 2 ⊻ gf_pow(2, 1 << 2, 6)                      # α + α^{2^k} = 18
    @test F6.lut == [gf_mul(c, gf_pow(gf_pow(x, 16, 6), 5, 6), 6) for x = 0:63]
    @test are_linear_equivalent(F6, SBox{6}(gf_monomial_lut(6, 5)))

    # The markdown emitter produces one row per function plus a header.
    md = table1_markdown(vcat(collect(values(rows)), frow))
    @test count(==('\n'), md) == 6
    @test occursin("| Function | n | perm | du |", md)
end
