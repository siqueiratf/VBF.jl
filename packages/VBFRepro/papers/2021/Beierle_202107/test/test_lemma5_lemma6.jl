@testset "Lemma5 commutant prefix pruning preserves complete small classes" begin
    identity3=Matrix{Int}(I,3,3)
    proof=lemma6_extensions(identity3,3)
    @test proof.k == 3
    @test length(proof.extensions) == length(unique(proof.restrictions)) == 168
    raw=APNSearch(3,identity3,identity3; timeout_seconds=30)
    pruned=APNSearch(3,identity3,identity3; C_A=proof.extensions,
                     pruning_depth=typemax(Int),timeout_seconds=30)
    @test raw isa Exhausted
    # Independent enumeration of all 7! normalized permutations, using the
    # public full DDT rather than Algorithm1's even-weight partial DDT.
    independent=Set{Tuple}()
    candidate=collect(0:7)
    function visit_permutations!(i)
        if i==9
            differential_uniformity(SBox{3}(candidate))==2 && push!(independent,Tuple(candidate))
            return
        end
        for j in i:8
            candidate[i],candidate[j]=candidate[j],candidate[i]
            visit_permutations!(i+1)
            candidate[i],candidate[j]=candidate[j],candidate[i]
        end
    end
    visit_permutations!(2)
    @test length(independent)==1344
    @test Set(Tuple.(search_solutions(raw)))==independent
    G=Int.(gf_monomial_lut(3,3))
    linear_orbit=Set(Tuple(co[G[ci[x]+1]+1] for x in 1:8)
                     for ci in proof.restrictions,co in proof.restrictions)
    @test linear_orbit==independent
    @test pruned isa Exhausted
    transformations=[(l,collect(0:7)) for l in proof.restrictions]
    key(F)=minimum(Tuple(co[F[ci[x]+1]+1] for x in 1:8) for (ci,co) in transformations)
    @test Set(key.(search_solutions(raw))) == Set(key.(search_solutions(pruned)))
    @test length(search_solutions(pruned)) < length(search_solutions(raw))
    @test pruned.region.params["pruned_nodes"] > 0
    @test isSmallest([-1,3,-1,0],[(collect(0:3),[0,2,1,3])])
    @test !isSmallest([0,2,-1,-1],[(collect(0:3),[0,2,1,3])])
    @test_throws ArgumentError validated_commutant_luts([zeros(Int,3,3)],identity3,3)
    A,B=precomputed_tuple_matrices(6,14)
    bad=Matrix{Int}(I,6,6);bad[1,3]=1
    @test_throws ArgumentError validated_commutant_luts([bad],A,6)
end

@testset "Definition5 verified lifts and Lemma6 fixed-space seeding" begin
    A,B=precomputed_tuple_matrices(6,14)
    lift=lemma6_extensions(A,6)
    @test lift.extendability_proved
    @test lift.k==3
    @test length(unique(lift.restrictions))==168
    seed=fill(-1,64)
    evidence=lemma6_seed!(seed,A,B,6)
    @test count(!=(-1),seed)==8
    @test seed[1]==0
    # This compatible assignment lies outside the fixed space. Lemma6 can
    # normalize the restriction, but need not preserve this extra constraint.
    outside=findfirst(==(-1),seed)
    y=first(setdiff(collect(0:63),filter(!=(-1),seed)))
    constrained=fill(-1,64); constrained[outside]=y
    @test_throws ArgumentError APNSearch(6,A,B;sbox=constrained,
        extendability_seeding=true,timeout_seconds=0)
    zero_only=fill(-1,64); zero_only[1]=0
    @test APNSearch(6,A,B;sbox=zero_only,extendability_seeding=true,timeout_seconds=0) isa BudgetHit
    @test differential_uniformity(SBox{3}(evidence.restriction_lut))==2
    outcome=APNSearch(6,A,B;extendability_seeding=true,timeout_seconds=0)
    @test outcome isa BudgetHit
    @test !proves_emptiness(outcome)
    @test outcome.region.params["extendability_seeding"]
    @test count(!=(-1),outcome.region.params["initial_partial_lut"])==8
    path=joinpath(mktempdir(),"scoped.toml")
    batch=APNSearchClasses(6,[14];save_results=false,save_evidence=true,
        evidence_output=path,timeout_seconds=0,commutant_pruning=true,extendability_seeding=true)
    saved=TOML.parsefile(path)
    @test saved["classes"]["14"]["outcome"]=="budget_hit"
    @test saved["classes"]["14"]["region"]["extendability_evidence"]["input_extensions"]==168
    @test batch[14] isa BudgetHit
    # Exhaustible identity3 validates seeded/unseeded existence parity.
    identity3=Matrix{Int}(I,3,3)
    seeded=APNSearch(3,identity3,identity3;extendability_seeding=true)
    @test seeded isa Exhausted
    @test length(search_solutions(seeded))==1
    @test differential_uniformity(SBox{3}(only(search_solutions(seeded))))==2
    @test_throws ArgumentError lemma6_extensions([1 1 0; 0 1 0; 0 0 1],3)
end

@testset "Definition3 prime-order canonical keys agree with original similarity" begin
    matrices=filter(has_prime_multiplicative_order,get_rcfs(4))
    pairs=candidate_pairs_with_same_cycle_structure(matrices)
    key(pair)=extended_power_class_key(prime_order_power_signatures(pair[1]),prime_order_power_signatures(pair[2]))
    for a in pairs,b in pairs
        @test (key(a)==key(b)) == is_extended_power_similar(a,b)
    end
    identity3=identity_matrix(GF(2),3)
    @test_throws ArgumentError prime_order_power_signatures(identity3)
end
