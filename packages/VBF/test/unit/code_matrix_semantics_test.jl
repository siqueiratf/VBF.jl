@testitem "code_matrix_semantics" begin
using VBF, Test, Random
rng=Xoshiro(8032)
for n in 3:5
    F=gold_apn(n,1);C=ccz_matrix(F)
    for x in 0:((1<<n)-1),j in 0:(n-1)
        @test C[j+2,x+1]==((x>>j)&1==1)
        @test C[n+j+2,x+1]==((F(x)>>j)&1==1)
    end
    for _ in 1:3
        inner=random_affine_permutation(rng,Val(n))
        outer=random_affine_permutation(rng,Val(n))
        drift=random_linear_function(rng,Val(n))
        G=SBox{n}([outer(F(inner(x))) ⊻ drift(x) for x in 0:((1<<n)-1)])
        @test code_weight_enumerator(ea_matrix(F))==code_weight_enumerator(ea_matrix(G))
        @test code_weight_enumerator(ccz_matrix(F))==code_weight_enumerator(ccz_matrix(G))
    end
end
@testset "equal code invariants do not certify EA equivalence" begin
    K,D=kim_apn(),dillon_apn_permutation()
    @test code_weight_enumerator(ccz_matrix(K))==code_weight_enumerator(ccz_matrix(D))
    @test code_weight_enumerator(ea_matrix(K))==code_weight_enumerator(ea_matrix(D))
    @test algebraic_degree(K)==2
    @test algebraic_degree(D)==4
end
@testset "enumerate distinct codewords, independent of generator redundancy" begin
    A=Bool[1 0 1;0 1 1]
    redundant=vcat(A,A[1:1,:],falses(1,3))
    @test code_weight_enumerator(A)==code_weight_enumerator(redundant)==[1,0,3,0]
    @test code_weight_enumerator(falses(7,4))==[1,0,0,0,0]
    @test code_weight_enumerator(falses(0,4))==[1,0,0,0,0]
end
end
