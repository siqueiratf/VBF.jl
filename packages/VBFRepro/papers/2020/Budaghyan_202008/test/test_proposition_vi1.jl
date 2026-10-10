@testset "Proposition VI.1 coefficient orbit and independent linear identities" begin
    include(joinpath(@__DIR__,"..","proposition_vi1.jl"))
    # All coefficient vectors and all transformations at n=3: tests arbitrary
    # linear maps, including non-APN shifts. Direct shift evaluation uses the
    # isotopic definition, independently of the transformed coefficient formula.
    for code in 0:511
        cs=[(code >> (3*j)) & 7 for j in 0:2]
        for k in 0:6,t in 0:2
            witness=proposition_vi1_witness(cs,3,1;k,t)
            @test witness.verified
        end
    end
    cs=[5,2,7,0,1]
    norm=proposition_vi1_normalize(cs,5)
    @test norm.complete && norm.evaluations==norm.space_size==155
    @test proposition_vi1_witness(cs,5,1;k=norm.k,t=norm.t).verified
    transformed=proposition_vi1_coefficients(cs,5;k=17,t=3)
    @test proposition_vi1_normalize(transformed,5).coefficients == norm.coefficients
    @test proposition_vi1_normalize(norm.coefficients,5).coefficients == norm.coefficients
    bounded=proposition_vi1_normalize(cs,5;max_evaluations=1)
    @test !bounded.complete && bounded.evaluations==1
    @test !proposition_vi1_normalize(cs,5;timeout_seconds=0).complete
    @test_throws ArgumentError proposition_vi1_coefficients([1,2],3)
    @test_throws ArgumentError proposition_vi1_coefficients([1,2,8],3)
    @test_throws ArgumentError proposition_vi1_witness([1,2,3,0],4,2)
    @test_throws ArgumentError proposition_vi1_normalize(cs,5;max_evaluations=-1)
    # The composition maps are invertible; a changed output witness breaks the
    # pointwise identity for this nonzero shift.
    w=proposition_vi1_witness(cs,5,1;k=4,t=2)
    bad=copy(w.output_lut); bad[2:end].⊻=1
    @test any(w.target_lut[x+1] != bad[w.source_lut[w.input_lut[x+1]+1]+1] for x in 0:31)
end
