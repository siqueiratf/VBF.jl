@testset "Section 3.2 resumable census drivers" begin
    include(joinpath(@__DIR__,"..","section32_switching.jl"))
    include(joinpath(@__DIR__,"..","section32_sevenbit.jl"))
    edges = falses(4,4)
    edges[1,2] = true
    edges[3,4] = true
    @test bgp_connection_components(4,edges) == [[1,2],[3,4]]
    mktempdir() do directory
        path = joinpath(directory,"census.toml")
        bgp_atomic_toml(path,Dict("census_complete"=>false,"roots_distinct"=>true))
        @test_throws ArgumentError bgp_saved_census(path)
        @test !isfile(path*".tmp")
        @test TOML.parsefile(path)["census_complete"] == false
        bgp_atomic_toml(path,Dict("census_complete"=>true,"roots_distinct"=>false))
        @test_throws ArgumentError bgp_saved_census(path)
    end
    @test_throws ArgumentError section32_switching(limit=-1)
    @test_throws ArgumentError section32_switching(result_name="../outside")
    @test_throws ArgumentError section32_sevenbit(group_algorithm=:unknown)
    @test_throws ArgumentError section32_sevenbit(per_root_timeout_seconds=NaN)
    # No search and no filesystem writes; test the full pinned input selection.
    roots = section32_seven_inputs()
    @test length(roots)==488
    @test count(r->occursin("Gold",r.label),roots)==3
    @test length(unique(Tuple(r.function_value.lut) for r in roots))==488
    @test all(r->occursin("sboxu@7066b82",r.provenance),roots)
    stopped = section32_sevenbit(limit=0,save_results=false)
    @test isempty(stopped.rows)
    @test !stopped.complete
    @test stopped.summary["total_classes"]==0
    @test stopped.summary["algorithm_profile"]=="optimized"
    buffer = IOBuffer()
    TOML.print(buffer,stopped.summary)
    @test TOML.parse(String(take!(buffer)))["parameters"]["group_algorithm"]=="optimized"
end
