@testitem "ortho_derivative_rank" begin
using VBF, Test, Random
rng=Xoshiro(8009)
for n in 3:6
    F=gold_apn(n,1);pi=ortho_derivative(F)
    drift=random_linear_function(rng,Val(n));constant=rand(rng,0:((1<<n)-1))
    G=SBox{n}([F(x) ⊻ drift(x) ⊻ constant for x in 0:((1<<n)-1)])
    @test differential_uniformity(G)==2
    @test ortho_derivative(G).lut==pi.lut
    # Independent brute annihilation over the entire image, not only basis bits.
    for a in 1:((1<<n)-1)
        image=unique([G(x⊻a) ⊻ G(x) ⊻ G(a) ⊻ G(0) for x in 0:((1<<n)-1)])
        @test length(image)==1<<(n-1)
        normals=[b for b in 1:((1<<n)-1) if all(v->iseven(count_ones(UInt(b)&UInt(v))),image)]
        @test normals==[pi(a)]
    end
end
@test ortho_derivative(inverse_apn(5))===nothing # APN, but degree four
@test ortho_derivative(SBox{4}(collect(0:15)))===nothing
for _ in 1:40
    M=zeros(Int,4,4)
    for i in 1:4,j in (i+1):4;M[i,j]=M[j,i]=rand(rng,0:15);end
    F=qam_to_sbox(M)
    @test (ortho_derivative(F)!==nothing)==(differential_uniformity(F)==2)
end
end
