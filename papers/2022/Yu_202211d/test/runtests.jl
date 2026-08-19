using Test
using VBF
using VBFCatalog

include(joinpath(@__DIR__, "..", "helpers.jl"))
include(joinpath(@__DIR__, "..", "qam_correspondence.jl"))
include(joinpath(@__DIR__, "..", "conjecture2_search.jl"))
include(joinpath(@__DIR__, "..", "proposition3_partitions.jl"))
include(joinpath(@__DIR__, "..", "theorem6_model.jl"))
include(joinpath(@__DIR__, "..", "paper_invariants.jl"))
include(joinpath(@__DIR__, "..", "small_searches.jl"))
include(joinpath(@__DIR__, "..", "catalog_validation.jl"))

@testset "Yu–Perrin 2022 (QAM method) reproduction" begin
    include("test_qam_correspondence.jl")
    include("test_conjecture2.jl")
    include("test_proposition3_partitions.jl")
    include("test_theorem6_model.jl")
    include("test_paper_invariants.jl")
    include("test_catalog_validation.jl")
    include("test_results_artifacts.jl")

    @testset "Small QAM search: n=4 full finds Gold class" begin
        r = small_search_full(4; limit = 5, max_evaluations = 1 << 24)
        @test r.n_classes >= 1
        @test r.gold_found
        # `exhaustive` is now measured by the search, not inferred from the
        # arguments. At n=4 with this budget the sweep really does complete.
        @test r.exhaustive
        @test is_exhausted(r.outcome)
    end

    @testset "Small QAM search: cyclic (n=4, m=2) finds Gold class" begin
        r = small_search_cyclic(4, 2; limit = 5, max_evaluations = 1 << 22)
        @test r.gold_found
    end
end
