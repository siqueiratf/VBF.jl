@testitem "apn_extensions_test" begin
    using VBF

    G = VBFTable{3,2}(Int.(gold_apn(3).lut) .>> 1)
    exact = apn_extensions(G;normalize=false,max_nodes=10^5,max_solutions=1000)
    brute = Set{Vector{UInt8}}()
    for mask in 0:255
        F = SBox{3}([(Int(G(x))<<1)|((mask>>x)&1) for x in 0:7])
        differential_uniformity(F) == 2 && push!(brute,F.lut)
    end
    @test exact isa Exhausted
    @test Set(F.lut for F in search_solutions(exact)) == brute
    space = only(search_solutions(apn_extension_space(G;normalize=false)))
    @test length(brute) == big(1)<<space.kernel_dimension
    @test all(count(space.particular[x+1] for x in flat)%2 == 1 for flat in space.flats)
    @test all(all(count(v[x+1] for x in flat)%2 == 0 for flat in space.flats)
        for v in space.kernel)

    normalized = apn_extensions(G;max_solutions=1000)
    @test normalized isa Exhausted
    ns = only(search_solutions(apn_extension_space(G)))
    @test ns.normalized_dimension == ns.kernel_dimension-length(ns.normalization_points)
    @test all(all(iszero(F(x)&1) for x in ns.normalization_points)
        for F in search_solutions(normalized))
    @test length(search_solutions(normalized)) == 1<<ns.normalized_dimension

    impossible = VBFTable{3,2}(zeros(Int,8))
    @test proves_emptiness(apn_extensions(impossible))
    @test !only(search_solutions(apn_extension_space(impossible))).consistent
    @test apn_extensions(G;max_nodes=0) isa BudgetHit
    @test apn_extension_space(G;timeout_seconds=0) isa BudgetHit
    @test apn_extensions(G;max_solutions=1) isa BudgetHit
    @test length(search_solutions(apn_extensions(G;max_solutions=1))) == 1
    @test_throws ArgumentError apn_extensions(G;max_nodes=-1)
    @test_throws ArgumentError apn_extensions(VBFTable{3,1}(zeros(Int,8)))
end
