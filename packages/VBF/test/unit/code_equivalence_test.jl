@testitem "binary_code_equivalence" begin
    using VBF, Test, Random
    rng=Xoshiro(803204)

    # Independent tiny oracle: literal codeword closure and every coordinate
    # permutation. No row reduction, rank oracle or partial maps are used.
    function permutations(n)
        p=collect(1:n);result=Vector{Int}[]
        function visit(i)
            if i>n;push!(result,copy(p));return;end
            for j in i:n
                p[i],p[j]=p[j],p[i];visit(i+1);p[i],p[j]=p[j],p[i]
            end
        end
        visit(1);result
    end
    function words(G)
        rows=[sum((Int(G[i,j]) << (j-1) for j in axes(G,2));init=0) for i in axes(G,1)]
        result=Set([0])
        for row in rows;union!(result,Set(w ⊻ row for w in result));end
        result
    end
    permute_word(w,p)=sum((((w >> (p[j]-1)) & 1) << (j-1) for j in eachindex(p));init=0)
    function oracle(G,H)
        size(G,2)==size(H,2) || return false
        left,right=words(G),words(H)
        any(Set(permute_word(w,p) for w in left)==right for p in permutations(size(G,2)))
    end
    for n in 0:5,trial in 1:12
        G=rand(rng,Bool,rand(rng,0:4),n)
        H=rand(rng,Bool,rand(rng,0:4),n)
        expected=oracle(G,H)
        result=binary_code_equivalence(G,H;timeout_seconds=10,max_nodes=10000)
        @test !(result isa BudgetHit)
        @test (result isa Found)==expected
        @test are_codes_equivalent(G,H)==expected
        if expected
            p=only(search_solutions(result))
            @test Set(permute_word(w,p) for w in words(G))==words(H)
            @test verify_code_equivalence(G,H,p)
        else
            @test proves_emptiness(result)
        end
    end

    @testset "degenerate generators, multiplicities and equal invariant collision" begin
        G=Bool[1 0 1 0 1;0 1 1 0 1]
        redundant=vcat(G,G[1:1,:],falses(2,5))
        H=G[:,[5,4,3,1,2]]
        @test are_codes_equivalent(redundant,H)
        @test verify_code_equivalence(redundant,H,only(search_solutions(binary_code_equivalence(redundant,H))))
        @test are_codes_equivalent(falses(0,7),falses(20,7))
        @test are_codes_equivalent(falses(3,0),falses(0,0))
        @test !are_codes_equivalent(falses(3,0),falses(3,1))
        @test !are_codes_equivalent(G,falses(0,5))
        A=Bool[1 1 0;0 0 1];B=Bool[1 1 0;1 1 0]
        @test !are_codes_equivalent(A,B)
        @test !verify_code_equivalence(G,H,[1,1,3,4,5])
        @test !verify_code_equivalence(G,H,[0,2,3,4,5])
        @test !verify_code_equivalence(G,H,[1.0,2.0,3.0,4.0,5.0])
        @test !verify_code_equivalence(G,H,collect(1:4))
        code(cols)=Bool[isodd(c >> j) for j in 0:2,c in cols]
        C,D=code([1,1,1,3,5,7]),code([1,1,2,2,4,4])
        @test code_weight_enumerator(C)==code_weight_enumerator(D)==[1,0,3,0,3,0,1]
        @test !oracle(C,D)
        @test proves_emptiness(binary_code_equivalence(C,D))
        # Same length/rank/zero count and column-multiplicity multiset, but a
        # relation differs: e1+e2 is replaced by e1+e2+e3.
        E,F=code([1,2,3,4]),code([1,2,4,7])
        @test !oracle(E,F)
        result=binary_code_equivalence(E,F)
        @test proves_emptiness(result)
        @test nodes_visited(result)>0
    end

    @testset "arbitrary rank, with planted row and column changes" begin
        for r in (33,65)
            # Distinct multiplicities mark basis columns and keep this a small
            # exact high-rank test, without promising random-code performance.
            G=falses(r,sum(1:r)+3)
            j=1
            for i in 1:r
                G[i,j:j+i-1].=true;j+=i
            end
            p=randperm(rng,size(G,2))
            H=copy(G[:,p]);H[1,:].⊻=H[2,:]
            result=binary_code_equivalence(vcat(G,G[1:1,:]),H;timeout_seconds=30)
            @test result isa Found
            @test verify_code_equivalence(G,H,only(search_solutions(result)))
            mutated=vcat(H,falses(1,size(H,2)))
            mutated[end,findfirst(H[r,:])]=true
            @test proves_emptiness(binary_code_equivalence(G,mutated;timeout_seconds=30))
        end
    end

    @testset "budgets include preprocessing and preserve uncertainty" begin
        G=Bool[1 0 1 0;0 1 1 1];H=G[:,[4,3,2,1]]
        for kwargs in ((timeout_seconds=0,),(max_nodes=0,),(max_memory_bytes=0,),(max_nodes=1,))
            result=binary_code_equivalence(G,H;kwargs...)
            @test result isa BudgetHit
            @test !proves_emptiness(result)
        end
        @test_throws InconclusiveEquivalence are_codes_equivalent(G,H;max_nodes=0)
        @test ismissing(are_codes_equivalent(G,H;max_nodes=0,on_inconclusive=:missing))
        @test_throws ArgumentError binary_code_equivalence(G,H;max_nodes=-1)
        @test_throws ArgumentError binary_code_equivalence(G,H;timeout_seconds=NaN)
        @test_throws ArgumentError binary_code_equivalence(G,H;max_memory_bytes=-1)
        @test_throws ArgumentError are_codes_equivalent(G,H;on_inconclusive=:invalid)
    end

    @testset "CCZ graph-code decisions agree with native Kaleyski–Sunde" begin
        for trial in 1:24
            F=random_function_sbox(rng,Val(2));G=random_function_sbox(rng,Val(2))
            native=partition_refinement_equivalence(F,G;relation=:ccz)
            code=binary_code_equivalence(ccz_matrix(F),ccz_matrix(G))
            @test !(native isa BudgetHit) && !(code isa BudgetHit)
            @test (native isa Found)==(code isa Found)
            if code isa Found
                @test verify_code_equivalence(ccz_matrix(F),ccz_matrix(G),only(search_solutions(code)))
            end
        end
    end
end
