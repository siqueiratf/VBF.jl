@testitem "biprojective evaluator and admissible sampling" begin
    using VBF, Random
    F=biprojective_sbox(4,1,(1,0,1,1),2,(1,1,0,1);modulus=19)
    @test is_quadratic_apn(F)
    @test F==biprojective_sbox(4,5,(1,0,1,1),6,(1,1,0,1);modulus=19)
    @test F(0)==0
    @test_throws ArgumentError biprojective_sbox(4,1,(16,0,1,1),2,(1,1,0,1);modulus=19)
    @test_throws ArgumentError biprojective_sbox(1,1,(1,0,1,1),2,(1,1,0,1))
    Q=gold_apn(4)
    C=VBF.QuadraticRestrictions.restrict_coeffs(Q.lut,VBF.QuadraticRestrictions.hyperplane_basis(1,4))
    count,exact,_=VBF.QuadraticRestrictions.count_admissible(C,3,4)
    @test exact
    mean,se=VBF.QuadraticRestrictions.estimate_admissible(C,3,4;probes=500,rng=Xoshiro(12))
    @test abs(mean-count)<=5se
    @test_throws ArgumentError VBF.QuadraticRestrictions.estimate_admissible(C,3,4;probes=1)
end
