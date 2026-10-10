@testitem "wide_system" begin
using VBF, Test, Random
rng=Xoshiro(8030)
# Independent ordinary Boolean elimination, deliberately no VBF linear algebra.
function reference_rank(A)
    M=copy(A);r=0
    for c in axes(M,2)
        p=findfirst(i->M[i,c],(r+1):size(M,1));p===nothing && continue
        p+=r;r+=1;M[r,:],M[p,:]=copy(M[p,:]),copy(M[r,:])
        for i in (r+1):size(M,1);M[i,c] && (M[i,:] .⊻= M[r,:]);end
    end
    r
end
product(A,x)=BitVector(isodd(sum((A[i,j] & x[j] for j in axes(A,2));init=0)) for i in axes(A,1))
for (nr,nc) in ((0,0),(0,163),(12,0),(13,8),(64,64),(128,128),(34,163),(63,224))
    A=BitMatrix(rand(rng,Bool,nr,nc));saved=copy(A);x=BitVector(rand(rng,Bool,nc));b=product(A,x)
    rank=reference_rank(A)
    @test rank_f2(A)==rank
    result=solve_f2(A,b)
    @test result!==nothing
    @test product(A,result)==b
    K=kernel_f2(A)
    @test length(K)==nc-rank
    @test all(v->!any(product(A,v)),K)
    @test reference_rank(isempty(K) ? falses(0,nc) : reduce(vcat,permutedims.(K)))==length(K)
    @test A==saved
    reduced=copy(A);pivots,free=rref_f2!(reduced)
    @test length(pivots)==rank && length(free)==nc-rank
    @test rank_f2(reduced)==rank
    for (i,c) in enumerate(pivots)
        @test reduced[i,c] && count(view(reduced,:,c))==1
    end
    packed=VBF._pack_f2(A)
    @test rank_f2(packed;nbits=nc)==rank
    @test VBF._unpack_f2(solve_f2(packed,b;nbits=nc),nc)==result
end
@test solve_f2(falses(2,163),Bool[false,true])===nothing
@test_throws DimensionMismatch solve_f2(falses(2,163),Bool[false])
@test_throws ArgumentError rref_f2!(zeros(UInt64,1,2);nbits=65)
# Augmented RHS must survive the exact word-width boundary.
for T in (UInt8,UInt16,UInt32,UInt64,UInt128)
    n=8sizeof(T);A=T[T(1)<<(n-1)]
    @test solve_f2(A,T(1);nbits=n)==A[1]
    @test solve_f2(T[0],T(1);nbits=n)===nothing
end
# Ignore padding bits at the declared width, including RHS-independent masks.
@test solve_f2(UInt8[0x81],UInt8(1);nbits=1)==UInt8(1)
end
