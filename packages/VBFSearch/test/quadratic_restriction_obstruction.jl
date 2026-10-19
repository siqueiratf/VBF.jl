using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/quadratic_restriction_obstruction.jl"))
const QRO=QuadraticRestrictionObstruction
@testset "Restriction-rank witnesses exclude only impossible two-coordinate completions" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4)
    fano=QRO.validate_given_H(G,UInt32[4,16],UInt16[1,2,4])
    @test fano.violation
    @test fano.restricted_rank==0
    @test fano.minimum_required_rank==1
    bent=QRO.validate_given_H(G,UInt32[0x21],UInt16[1,2,4,8])
    @test bent.violation
    @test bent.restricted_rank==1
    @test bent.minimum_required_rank==2
    @test Q.form_rank(G,only(bent.restricted_basis))==4
    @test QRO.validate_given_H(G,UInt32[],UInt16[1,2,4]).violation
    for n in (4,6)
        F=gold_apn(n);Gn=Q.geometry(n);a=anf(F)
        coefficients=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:n-1 for j in i+1:n-1]
        U=Q.coord_forms(coefficients,n)[1:n-2]
        for k in 3:n
            witness=QRO.validate_given_H(Gn,U,UInt16[1<<i for i in 0:k-1])
            @test !witness.violation
            @test witness.status=="no_certificate"
            @test witness.restricted_rank>=k-2
        end
        for normal in 1:(1<<n)-1
            H=VBF.QuadraticRestrictions.hyperplane_basis(normal,n)
            @test !QRO.validate_given_H(Gn,U,H).violation
        end
    end
    @test_throws ArgumentError QRO.validate_given_H(G,[1],[1,1,2])
    @test_throws ArgumentError QRO.validate_given_H(G,[1],[1,2,16])
    @test_throws ArgumentError QRO.validate_given_H(G,[64],[1,2,4])
    @test_throws ArgumentError QRO.validate_given_H(G,[1],[1,2])
end
