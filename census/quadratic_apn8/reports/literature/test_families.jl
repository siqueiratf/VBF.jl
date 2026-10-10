using Test, VBF
include("check_families.jl")
using .FamilyCoverage

@testset "independent APN rejection certificates" begin
    gold=gf_monomial_lut(8,3;modulus=285)
    @test FamilyCoverage.non_apn_witness(gold)===nothing
    for d in (1,2,7,15,255)
        f=gf_monomial_lut(8,d;modulus=285)
        witness=FamilyCoverage.non_apn_witness(f)
        @test witness!==nothing
        a,b,xs...=witness
        @test a!=0 && length(unique(xs))==4
        @test all(f[x+1] ⊻ f[(x⊻a)+1]==b for x in xs)
    end
    @test_throws ErrorException FamilyCoverage.non_apn_witness(zeros(Int,255))
    @test_throws ErrorException FamilyCoverage.non_apn_witness(fill(256,256))
end

@testset "CLV formulas and admissible parameter domains" begin
    for k in (1,3)
        g=FamilyCoverage.Gologlu.biprojective_sbox(4,k,(1,0,1,1),2k,(1,1,0,1);modulus=19)
        @test FamilyCoverage.clv_lut(1,k,1)==g.lut
    end
    @test FamilyCoverage.clv_lut(2,1,1)==FamilyCoverage.Li.theorem2_sbox(4;modulus=19).lut
    @test_throws ErrorException FamilyCoverage.clv_lut(2,3,1)
    for (family,k) in ((1,1),(1,3),(2,1)), alpha in 0:15
        f=FamilyCoverage.clv_lut(family,k,alpha)
        rootless=all(x->gf_pow(x,(1<<k)+1,4;modulus=19) ⊻ x ⊻ alpha !=0,0:15)
        @test (FamilyCoverage.non_apn_witness(f)===nothing)==rootless
        @test differential_uniformity(SBox{8,UInt8}(f))==2 || !rootless
        @test algebraic_degree(SBox{8,UInt8}(f))==2
    end
end

@testset "coverage ledger connects every executable domain" begin
    ledger=FamilyCoverage.TOML.parsefile(joinpath(@__DIR__,"family_coverage.toml"))
    declared=Set(d for row in ledger["coverage"] for d in get(row,"domains",String[]))
    @test declared==Set(keys(FamilyCoverage.DOMAIN_COUNTS))
    @test !ledger["literature_complete"]
    @test any(r->r["status"]=="unresolved_data_availability",ledger["coverage"])
end
