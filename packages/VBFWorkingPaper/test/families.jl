using Test, VBF
include("../src/literature/family_coverage.jl")
using .FamilyCoverage

@testset "CLV formulas and admissible parameter domains" begin
    for k in (1,3)
        g=FamilyCoverage.Gologlu.biprojective_sbox(4,k,(1,0,1,1),2k,(1,1,0,1);modulus=19)
        @test FamilyCoverage.clv_lut(1,k,1)==g.lut
    end
    @test FamilyCoverage.clv_lut(2,1,1)==FamilyCoverage.Li.theorem2_sbox(4;modulus=19).lut
    @test_throws ArgumentError FamilyCoverage.clv_lut(2,3,1)
    for (family,k) in ((1,1),(1,3),(2,1)), alpha in 0:15
        f=FamilyCoverage.clv_lut(family,k,alpha)
        rootless=all(x->gf_pow(x,(1<<k)+1,4;modulus=19) ⊻ x ⊻ alpha !=0,0:15)
        @test (differential_uniformity(SBox{8}(f))==2)==rootless
        @test differential_uniformity(SBox{8,UInt8}(f))==2 || !rootless
        @test algebraic_degree(SBox{8,UInt8}(f))==2
    end
end

@testset "coverage ledger connects every executable domain" begin
    ledger=FamilyCoverage.TOML.parsefile(joinpath(@__DIR__, "../src/literature/family_coverage.toml"))
    declared=Set(d for row in ledger["coverage"] for d in get(row,"domains",String[]))
    @test declared==Set(keys(FamilyCoverage.DOMAIN_COUNTS))
    @test !ledger["literature_complete"]
    @test any(r->r["status"]=="unresolved_data_availability",ledger["coverage"])
end
