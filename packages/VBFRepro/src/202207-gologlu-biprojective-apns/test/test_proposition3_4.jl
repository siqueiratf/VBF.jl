@testset "proposition3_4_test" begin
    include(joinpath(@__DIR__, "..", "proposition3_4.jl"))

    # Prop III.4 i: Gold x^3 n=10 (m=5, odd): η_m = (2^5+1)/3 = 11
    G10 = gold_apn(10, 1)
    @test eta_m(G10, 5) == 11

    # Prop III.4 i: Gold x^3 n=6 (m=3, odd): η_m = (2^3+1)/3 = 3
    G6 = gold_apn(6, 1)
    @test eta_m(G6, 3) == 3

    # Prop III.4 iii: F3 (m=5): η_m = 2
    F3 = f3_sbox()
    @test eta_m(F3, 5) == 2

    # Prop III.4 v: F2 m=5 i=1: η_m ≥ 1
    F2_5 = f2_sbox(5, 1)
    @test eta_m(F2_5, 5) >= 1

    # Prop III.4 v: F2 m=5 i=2: η_m ≥ 1
    F2_5b = f2_sbox(5, 2)
    @test eta_m(F2_5b, 5) >= 1
    # Source explicitly defines kappa = X^3+X^10+U X^24 (U root of
    # X^6+X^4+X^3+X+1). Independent Walsh summation and span enumeration
    # count every 3-dimensional subspace, not a disjoint packing convention.
    K=kim_apn()
    @test differential_uniformity(K)==2 && algebraic_degree(K)==2
    independent_nb=Set([0])
    for b in 1:63
        bent=true
        for a in 0:63
            coefficient=sum(isodd(count_ones(b&Int(K.lut[x+1]))+count_ones(a&x)) ? -1 : 1 for x in 0:63)
            if abs(coefficient)!=8
                bent=false
                break
            end
        end
        bent || push!(independent_nb,b)
    end
    @test independent_nb == Set(nonbent_components(K))
    points=sort(collect(setdiff(independent_nb,Set([0]))))
    spaces=Set{NTuple{7,Int}}()
    for ia in 1:length(points), ib in ia+1:length(points), ic in ib+1:length(points)
        a,b,c=points[ia],points[ib],points[ic]
        span=sort(unique([a,b,a⊻b,c,a⊻c,b⊻c,a⊻b⊻c]))
        length(span)==7 && all(x->x!=0 && x in independent_nb,span) && push!(spaces,Tuple(span))
    end
    @test length(spaces)==3
    @test eta_m(K,3)==length(spaces)
    @test eta_m(K,3)!=2 # the printed Proposition III.4(ii) contradiction
    @test nonbent_signature(K)==nonbent_signature(G6)
    @test apn_ea_mugshot(K)!=apn_ea_mugshot(G6) # nevertheless separated quadratic CCZ classes
    result=proposition3_4_report(io=devnull)
    @test result.kim_eta==3 && !result.all_ok
    @test !result.n14_checked

end
