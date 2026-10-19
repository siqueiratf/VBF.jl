using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/flat_intersection_coloring.jl"))
const FIC=FlatIntersectionColoring
@testset "Exact graph coloring contradictions have independently replayable proofs" begin
    clique(n)=[[j for j in 1:n if i!=j] for i in 1:n]
    triangle=clique(3)
    @test isempty(FIC.three_core(triangle))
    @test FIC.coloring_obstruction(triangle).status=="two_degenerate"
    for n in 4:7
        graph=clique(n);result=FIC.coloring_obstruction(graph;max_seconds=Inf)
        @test result.status=="unsat"
        @test FIC.replay_unsat(graph,result.vertices,result.seeds,result.proof)
        corrupted=deepcopy(result.proof)
        pop!(corrupted["colors"])
        @test !FIC.replay_unsat(graph,result.vertices,result.seeds,corrupted)
        @test FIC.coloring_obstruction(graph;max_nodes=0).status=="unknown_nodes"
        @test FIC.coloring_obstruction(graph;max_seconds=0).status=="unknown_time"
    end
    bipartite=[i<=3 ? collect(4:6) : collect(1:3) for i in 1:6]
    @test FIC.coloring_obstruction(bipartite;max_seconds=Inf).status=="colorable"
    G=VBF.QuadraticExtensions.geometry(3)
    graph=FIC.intersection_graph(G,collect(eachindex(G.flats)))
    @test graph==clique(7)
    result=FIC.coloring_obstruction(graph;max_seconds=Inf)
    @test result.status=="unsat"
    @test FIC.replay_unsat(graph,result.vertices,result.seeds,result.proof)

    # The isotropic lines of a nondegenerate four-dimensional alternating form
    # give an obstruction without the seven-line Fano configuration.
    G4=VBF.QuadraticExtensions.geometry(4)
    indices=[i for (i,w) in enumerate(G4.flats) if !VBF.QuadraticExtensions.par(w&0x21)]
    graph4=FIC.intersection_graph(G4,indices)
    @test length(graph4)==15
    @test all(a->length(a)==6,graph4)
    result4=FIC.coloring_obstruction(graph4;max_seconds=Inf)
    @test result4.status=="unsat"
    @test FIC.replay_unsat(graph4,result4.vertices,result4.seeds,result4.proof)

    # A fixed nine-vertex induced core of the preceding graph is vertex-critical:
    # every vertex deletion is three-colorable, while this graph needs four.
    critical=[[2,3,7,9],[1,4,5,8],[1,4,6,8],[2,3,5,9],[2,4,6,7],
        [3,5,7,8],[1,5,6,9],[2,3,6,9],[1,4,7,8]]
    obstruction=FIC.coloring_obstruction(critical;max_seconds=Inf)
    @test obstruction.status=="unsat"
    @test FIC.replay_unsat(critical,obstruction.vertices,obstruction.seeds,obstruction.proof)
    for deleted in 1:9
        reduced=[v==deleted ? Int[] : filter(!=(deleted),critical[v]) for v in 1:9]
        @test FIC.coloring_obstruction(reduced;max_seconds=Inf).status in ("two_degenerate","colorable")
    end
end
