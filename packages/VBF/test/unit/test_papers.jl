using VBF
using Test

# Each paper-reproduction notebook in `papers/` is a standalone script
# exposing `reproduce()`. We evaluate each in a fresh anonymous module so
# their top-level `reproduce`/`report` definitions don't collide, then
# check the reproduced result against the published (frozen) values.

const PAPERS_DIR = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "papers"))

function _run_paper(filename::AbstractString)
    m = Module(Symbol(replace(filename, '.' => '_')))
    Base.include(m, joinpath(PAPERS_DIR, filename))
    # read the freshly-defined binding and call it, both in the latest
    # world (Julia ≥ 1.12 world-age semantics for new global bindings).
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
