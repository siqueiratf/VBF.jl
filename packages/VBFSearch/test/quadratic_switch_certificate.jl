using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/quadratic_switch_certificate.jl"))
const QSC=QuadraticSwitchCertificate
@testset "Quadratic switching sufficient certificates preserve Boolean coverage" begin
    G=VBF.QuadraticExtensions.geometry(4)
    @test QSC.cubic_symbol_dimension(G,UInt32[])==4
    @test QSC.cubic_symbol_dimension(G,UInt32[1])==2
    @test QSC.cubic_symbol_dimension(G,UInt32[1<<i for i in 0:5])==0
    for n in (4,6)
        F=gold_apn(n)
        k=QSC.quadratic_kernels(F)
        @test length(k.dimensions)==(1<<n)-1
        @test sum(k.flat_counts)==VBF.QuadraticExtensions.gauss_binom(n,2)
        @test all(d->d>=n-1,k.dimensions)
        comparison=QSC.compare_boolean(F,k)
        @test comparison["all_certificates_match"]
        @test !isempty(comparison["checked_directions"])
        for u in comparison["checked_directions"]
            @test comparison["boolean_dimensions"][u]==n+1+k.dimensions[u]
        end
    end
    @test_throws ArgumentError QSC.quadratic_kernels(SBox{4}(UInt8.(0:15)))
end
