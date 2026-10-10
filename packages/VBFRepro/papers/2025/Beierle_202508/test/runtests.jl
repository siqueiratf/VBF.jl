using Test
using VBF

include(joinpath(@__DIR__, "..", "helpers.jl"))
include(joinpath(@__DIR__, "..", "paper_counts.jl"))
include(joinpath(@__DIR__, "..", "component_profiles.jl"))
include(joinpath(@__DIR__, "..", "extension_criteria.jl"))
include(joinpath(@__DIR__, "..", "estimators.jl"))
include(joinpath(@__DIR__, "..", "dataset_validation.jl"))
include(joinpath(@__DIR__, "..", "catalog_validation.jl"))

@testset "Beierle et al. 2025 reproduction" begin
    include("test_paper_counts.jl")
    include("test_component_profiles.jl")
    include("test_extension_criteria.jl")
    include("test_estimators.jl")
    include("test_dataset_validation.jl")
    include("test_catalog_validation.jl")
end
