# Fast unit tests for the quadratic APN census (target: under 2 minutes, 1 thread).
# Generated fixtures need no corpus downloads, archived controls or sigma index.
using Test
using Random
using VBF

include(joinpath(@__DIR__, "../../src/census/helpers.jl"))
include(joinpath(@__DIR__, "../../src/census/sampler.jl"))
include(joinpath(@__DIR__, "../../src/census/validate.jl"))

@testset "quadratic APN census (F_2^8)" begin
    include("test_pipeline.jl")
    include("test_reproducibility.jl")
    include("test_compact.jl")
end
