@testitem "partition_refinement_conformance" begin
    using VBF, Test, Random
    include(joinpath(@__DIR__,"..","support","kaleyski_sunde_reference.jl"))
    R = KSPaperReference
    cells(p) = [collect(view(p.order,p.starts[c]:(p.starts[c+1]-1))) for c in 1:(length(p.starts)-1)]
    encode(h) = (Int(h[1]) << 1) | Int(h[2])
    nativeplanes(h) = [(a,s<0) for (a,s) in zip(h.normals,h.signs)]
    snap(stage,pl,pr,hl,hr,lf,rt) = (stage,sort.(pl),sort.(pr),
        [sort(encode.(lf[c])) for c in hl],[sort(encode.(rt[c])) for c in hr])

    @testset "Algorithms 1–3, every intermediate ordered partition" begin
        rng = Xoshiro(94031)
        for (n,m) in ((1,2),(2,1),(2,2),(3,2)), seed in 1:6, floor in (1,8,128)
            F = VBFTable{n,m}(rand(rng,0:((1<<m)-1),1<<n))
            G = VBFTable{n,m}([F(x ⊻ 1) ⊻ 1 for x in 0:((1<<n)-1)])
            left,right = FunctionGraph(F).packed,FunctionGraph(G).packed
            wl,wr = VBF._pr_graph_walsh(left,n+m),VBF._pr_graph_walsh(right,n+m)
            hist = VBF._pr_intersection_histogram(wl,length(left))
            classes,nplanes = VBF._pr_select_classes(hist,floor;preserve_order=false)
            lf,hl = VBF._pr_build_planes(wl,length(left),classes,hist)
            rt,hr = VBF._pr_build_planes(wr,length(right),classes,hist)
            pl,pr = VBF._PRPartition(length(left)),VBF._PRPartition(length(right))
            VBF._pr_individualize!(pl,1,1); VBF._pr_individualize!(pr,1,2)
            rl,rhl = R.initialize(left,n+m,floor)
            rr,rhr = R.initialize(right,n+m,floor)
            rpl = [[1],collect(2:length(left))]
            rpr = [[2],vcat(1,collect(3:length(right)))]
            traces,reference = Any[],Any[]
            observer(stage,a,b,c,d) = push!(traces,snap(stage,cells(a),cells(b),cells(c),cells(d),nativeplanes(lf),nativeplanes(rt)))
            refobserver(stage,a,b,c,d) = push!(reference,snap(stage,a,b,c,d,rl,rr))
            work = VBF._PRWorkspace(n+m,length(left),nplanes;algorithm=:paper,rng=Xoshiro(seed),trace=observer)
            ok = VBF._pr_refine!(pl,pr,hl,hr,left,right,lf,rt,work,floor,
                VBF._PRBudget(time_ns(),120.0,10000,0,:none))
            reference_rng = Xoshiro(seed)
            expected,_,_,_,_ = R.refine(left,right,rl,rr,rpl,rpr,rhl,rhr,reference_rng,floor;trace=refobserver)
            @test ok == expected
            @test traces == reference
            @test rand(work.rng,UInt64) == rand(reference_rng,UInt64)
        end
    end

    @testset "paper and optimized profiles remain explicit and reproducible" begin
        F,G = gold_apn(3,1),gold_apn(3,2)
        for algorithm in (:paper,:optimized)
            a = partition_refinement_equivalence(F,G;algorithm,rng=Xoshiro(77))
            b = partition_refinement_equivalence(F,G;algorithm,rng=Xoshiro(77))
            @test typeof(a)==typeof(b) && nodes_visited(a)==nodes_visited(b)
        end
        @test_throws ArgumentError partition_refinement_equivalence(F,F;algorithm=:invalid)
        @test_throws ArgumentError partition_refinement_automorphisms(F;algorithm=:invalid)
        @test_throws ArgumentError are_ccz_equivalent(F,F;algorithm=:invalid)
        @test_throws ArgumentError are_ea_equivalent(F,F;algorithm=:invalid)
    end
end
