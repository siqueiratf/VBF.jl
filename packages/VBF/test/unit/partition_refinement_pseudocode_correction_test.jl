@testitem "partition_refinement_pseudocode_correction" begin
    using VBF,Test,Random
    include(joinpath(@__DIR__,"..","support","kaleyski_sunde_reference.jl"))
    R = KSPaperReference
    F = SBox{2}([0,0,0,1])
    points = FunctionGraph(F).packed
    spectrum = VBF._pr_graph_walsh(points,4)
    hist = VBF._pr_intersection_histogram(spectrum,4)
    classes,np = VBF._pr_select_classes(hist,64;preserve_order=false)
    planes,hp = VBF._pr_build_planes(spectrum,4,classes,hist)
    pl,pr = VBF._PRPartition(4),VBF._PRPartition(4)
    for p in (pl,pr)
        VBF._pr_individualize!(p,1,2)
        VBF._pr_individualize!(p,2,3)
    end
    A = VBF._PRAffineMap(2)
    for p in points[1:3]
        @test VBF._pr_insert!(A,p,p,2,false)
    end
    work = VBF._PRWorkspace(4,4,np;algorithm=:paper,rng=Xoshiro(940))
    @test VBF._pr_refine!(pl,pr,hp,copy(hp),points,points,planes,planes,work,64,
        VBF._PRBudget(time_ns(),60.0,1000,0,:none))
    free = [count(j -> VBF._pr_image(A,points[pl.order[j]])===nothing,
                  pl.starts[c]:(pl.starts[c+1]-1)) for c in 1:(length(pl.starts)-1)]
    @test free == [0,0,1]
    @test !any(>(1),free) # no cell satisfies the printed branching condition
    @test VBF._pr_prepare_node!(pl,pr,points,points,A,work,2,false,Int[]) == (3,4)
    printed,_ = R.automorphisms(points,4,2;quadratic=true,printed_condition=true)
    corrected,_ = R.automorphisms(points,4,2;quadratic=true)
    @test length(printed)==4
    @test length(corrected)==24
    H = partition_refinement_automorphisms(F)
    @test H.complete && H.graph_order==24 && H.order==192
end
