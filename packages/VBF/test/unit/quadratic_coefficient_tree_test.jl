@testitem "quadratic_coefficient_tree_test.jl" begin
using Test,Random,VBF
T=VBF.QuadraticAPNTree
R=VBF.QuadraticRestrictions
P=VBF.QuadraticProfiles
@testset "Quadratic APN coefficient tree" begin
    total=0
    for a in 0:7,b in 0:7,c in 0:7
        C=UInt16[0 a b;a 0 c;b c 0]
        lut=T.lut(C,3)
        apn=differential_uniformity(SBox{3}(UInt8.(lut)))==2
        @test (T.images(C,3,3)!==nothing)==apn
        total+=apn
        @test T.decode_coeffs(T.encode_coeffs(C,3),3)==C
        @test T.coeff_matrix_from_lut(lut)==C
    end
    @test total==168==T.exact_count(3,3)
    for m in 3:5
        @test T.exact_count(3,m)==(2^m-1)*(2^m-2)*(2^m-4)
    end
    for c in 1:7
        C=UInt16[0 c;c 0]
        count,sols=T.count_completions(C,2,3;want_solution=true)
        raw=0
        for x in 0:7,y in 0:7
            D=UInt16[0 c x;c 0 y;x y 0]
            raw+=differential_uniformity(SBox{3}(UInt8.(T.lut(D,3))))==2
        end
        @test count==raw==T.reference_completions(C,2,3)[1]
        @test count==4length(sols)
    end
    @test_throws T.EnumerationLimitError T.exact_count(3,3;max_nodes=0)
    @test_throws T.EnumerationLimitError T.count_completions(UInt16[0 1;1 0],2,3;max_nodes=0)
    @test_throws ArgumentError T.count_completions(zeros(UInt16,9,9),9,8)
    @test_throws ArgumentError T.images(UInt16[1 1;1 0],2,3)
    @test_throws ArgumentError T.images(UInt16[0 8;8 0],2,3)
    @test T.count_completions(zeros(UInt16,3,3),3,4;want_solution=true)==(0,Vector{Vector{UInt16}}())
end
@testset "Restrictions and component profiles" begin
    F=gold_apn(4);C=T.coeff_matrix_from_lut(F.lut)
    for u in 1:15
        basis=R.hyperplane_basis(u,4)
        @test all(x->iseven(count_ones(x&u)),basis)
        D=R.restrict_coeffs(F.lut,basis)
        count,sols=T.count_completions(D,3,4;want_solution=true)
        @test count==T.reference_completions(D,3,4)[1]
        W=R.annihilators(D,3,4);kd=R.ker_phi_dim(W,3,4)
        @test count==(1<<kd)*R.distinct_pi(W,sols,3)
        admissible,exact,_=R.count_admissible(D,3,4)
        @test exact && admissible>=count÷(1<<kd)
        lower,full,_=R.count_admissible(D,3,4;cap=0)
        @test !full && lower==0
    end
    @test_throws ArgumentError R.hyperplane_basis(0,4)
    @test_throws ArgumentError R.restrict_coeffs(F.lut,[1,1])
    @test_throws ArgumentError R.count_admissible(zeros(UInt16,8,8),8,8)
    G=gold_apn(8); D=P.coeff_matrix_from_lut(G.lut);ranks=P.component_ranks(D)
    for b in 1:255
        # A quadratic Boolean component has Walsh amplitudes 2^(n-rank/2).
        values=[iseven(count_ones(b&Int(y))) ? 1 : -1 for y in G.lut]
        for bit in 0:7,first in 0:255
            first&(1<<bit)==0 || continue
            last=first|(1<<bit);x,y=values[first+1],values[last+1]
            values[first+1]=x+y;values[last+1]=x-y
        end
        @test maximum(abs,values)==1<<(8-ranks[b+1]÷2)
    end
    alpha=P.component_alphas(ranks)
    @test sum(alpha)==510
    hom=P.lut_from_matrix(D)
    for x in 0:255
        lin=foldl(xor,(G.lut[(1<<i)+1]⊻G.lut[1] for i in 0:7 if x&(1<<i)!=0);init=UInt8(0))
        @test hom[x+1]==G.lut[x+1]⊻G.lut[1]⊻lin
    end
    key(a)=(Int(a==1),a)
    brute=maximum((key(alpha[a+1]),(Int(alpha[a+1]==1)+Int(alpha[b+1]==1)+Int(alpha[(a⊻b)+1]==1),alpha[a+1]+alpha[b+1]+alpha[(a⊻b)+1])) for a in 1:255,b in 1:255 if a!=b)
    @test Tuple(P.profile_pk(alpha,2)[1][2:3])==brute
    @test T.exact_count(4,4)==1_128_960
    @test_throws ArgumentError P.profile_pk(alpha,9)
end

@testset "Bent-subspace counting and bounds" begin
    C=zeros(UInt16,8,8)
    for i in 1:2:7
        C[i,i+1]=C[i+1,i]=1
    end
    alpha=P.component_alphas(P.component_ranks(C))
    @test P.max_bent_subspace_dim(alpha)==(1,128)
    @test P.max_bent_subspace_dim(alpha;count_top=false)==(1,-1)
    @test_throws T.EnumerationLimitError P.max_bent_subspace_dim(alpha;max_nodes=0)
    @test_throws ArgumentError T.exact_count(100_000,8)
    @test_throws ArgumentError T.free_values!(falses(2),zeros(UInt16,2),[[UInt16(0)]],0,1)
end

end
