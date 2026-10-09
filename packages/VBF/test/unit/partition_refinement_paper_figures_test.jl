@testitem "partition_refinement_paper_figures" begin
    using VBF,Test,Random
    include(joinpath(@__DIR__,"..","support","kaleyski_sunde_reference.jl"))
    R = KSPaperReference
    F,G = gold_apn(7,1),gold_apn(7,2)
    left,right = FunctionGraph(F).packed,FunctionGraph(G).packed
    wl,wr = VBF._pr_graph_walsh(left,14),VBF._pr_graph_walsh(right,14)
    hist = VBF._pr_intersection_histogram(wl,128)
    classes,np = VBF._pr_select_classes(hist,32766;preserve_order=false)
    lf,hl = VBF._pr_build_planes(wl,128,classes,hist)
    rt,hr = VBF._pr_build_planes(wr,128,classes,hist)
    pl,pr = VBF._PRPartition(128),VBF._PRPartition(128)
    work = VBF._PRWorkspace(14,128,np;algorithm=:paper,rng=Xoshiro(940))
    budget = VBF._PRBudget(time_ns(),60.0,1000,0,:none)
    @test VBF._pr_refine!(pl,pr,hl,hr,left,right,lf,rt,work,32766,budget)
    @test diff(pl.starts)==[128]
    @test sort(diff(hl.starts))==[8128,8128,16510]
    VBF._pr_individualize!(pl,1,1); VBF._pr_individualize!(pr,1,1)
    @test VBF._pr_refine!(pl,pr,hl,hr,left,right,lf,rt,work,32766,budget)
    @test diff(pl.starts)==[1,127]
    # Figure 1 leaves the 16,510 zero-Walsh hyperplanes together, but
    # Algorithm 2 splits them by their incidence with the singleton.
    @test sort(diff(hl.starts))==[3556,3556,4572,4572,8255,8255]
    a = UInt32(findfirst(j -> j>1 && wl[j]==0,eachindex(wl))-1)
    planes = [(a,false),(a,true)]
    @test R.plane_signature(left,planes,[collect(1:128)],[1])==[64,64]
    @test R.plane_signature(left,planes,[[1],collect(2:128)],[7,2])==[133,128]
    H = partition_refinement_automorphisms(G)
    r = partition_refinement_equivalence(F,G;automorphisms=H)
    @test H.complete && H.order==113792
    @test r isa Exhausted && nodes_visited(r)==21 # Example 2 / Figure 2
end
