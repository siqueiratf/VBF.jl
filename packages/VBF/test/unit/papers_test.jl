@testitem "papers" begin
using VBFCatalog
using VBF
using Test

const PAPERS_DIR = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "papers"))

function _run_paper(filename::AbstractString)
    m = Module(Symbol(replace(filename, '.' => '_')))
    Base.include(m, joinpath(PAPERS_DIR, filename))
    # read the freshly-defined binding and call it, both in the latest world (Julia ≥ 1.12 world-age semantics for new global bindings).
    fn = Base.invokelatest(getfield, m, :reproduce)
    return Base.invokelatest(fn)
end

@testset "CidEtAl2018: boomerang uniformity matches published" begin
    r = _run_paper("CidEtAl2018_boomerang.jl")
    @test r.AES == 6
    @test r.PRESENT == 16
    @test r.GIFT == 16
end

@testset "BonnetainPerrinTian2019: AES DDT anomaly ≫ 1000 bits" begin
    a = _run_paper("BonnetainPerrinTian2019_anomaly.jl")
    @test a > 1000
end

@testset "CanteautCouvreurPerrin2022: ortho-derivative EA-distinction" begin
    r = _run_paper("CanteautCouvreurPerrin2022_orthoderivative.jl")
    @test r.gold3_quadratic_apn
    @test r.gold5_quadratic_apn
    @test r.x3_self_ea                 # a function is EA-equivalent to itself
    @test r.x3_ea_equiv_x5 == false    # distinct Frobenius orbits
end

@testset "Taniguchi2019: family on F2^8 — three CCZ-classes, two new" begin
    r = _run_paper("Taniguchi2019_construction.jl")
    @test r.n_classes == 3
    @test r.n_new == 2
    @test r.all_quadratic_apn
    @test r.distinct_mugshots == 3
    @test r.corpus_matches             # the two new classes == the re-housed corpus
end

@testset "EdelPott2009: Table 9 recomputed from formulas + switching" begin
    r = _run_paper("EdelPott2009_switching.jl")
    @test r.n_polynomials == 23
    @test r.all_apn
    @test r.n_quadratic_polynomials == 22
    @test r.all_quadratic_apn
    @test r.matches_corpus             # quadratic formulas → functions == re-housed corpus
    @test r.corpus == 22
    @test r.apn_neighbors > 0          # switching a small APN yields APN neighbours
end

@testset "WengTanGong2013: APN-algebra (derivative matrix is a QAM)" begin
    r = _run_paper("WengTanGong2013_apn_algebra.jl")
    @test r.corpus == 10
    @test r.all_quadratic_apn
    @test r.all_qam
end

@testset "YuWangLi2014: QAM↔F correspondence + guess-and-determine search" begin
    r = _run_paper("YuWangLi2014_qam.jl")
    @test r.corpus == 8179
    @test r.gd_search_n4_gold           # Algorithm 1 (search_qam_full) recovers Gold
    @test r.cyclic_gold
    @test r.qam_correspondence
end

@testset "YuPerrin2022: ortho-derivative CCZ bucketing on secondQAM" begin
    r = _run_paper("YuPerrin2022_qam_orthoderivative.jl")
    @test r.corpus == 5412
    @test r.all_qam
    @test r.distinct_buckets > 1
end

@testset "BeierleLeander2022: tree search (incl. n=7 LE-automorphism) + corpus" begin
    r = _run_paper("BeierleLeander2022_tree_search.jl")
    @test r.corpus == 12923
    @test r.search_finds_quadratic_apn
    @test r.le_search_n7_apn            # the real BL22 method at n=7 (class 1)
    @test r.quad_apn
end

@testset "BeierleLeanderPerrin2022: trims/extensions" begin
    r = _run_paper("BeierleLeanderPerrin2022_trims.jl")
    @test r.corpus == 6368
    @test r.extension_is_apn
    @test r.trim_spectrum_nonempty
    @test r.quad_apn
end

@testset "8-bit quadratic-APN landscape: 7 corpora, raw total 32,916" begin
    # The fast totals; the full ortho-derivative dedup (→ the literature's 32,892) runs standalone (`distinct_up_to_ea()`), too slow for the suite.
    r = _run_paper("quadratic_apn_8bit_landscape.jl")
    @test r.n_corpora == 7
    @test r.raw == 32916
    @test sum(c for (_, c) in r.per_family) == 32916
end

end
