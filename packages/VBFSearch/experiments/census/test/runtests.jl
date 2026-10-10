# Fast unit tests for the quadratic APN census (target: under 2 minutes, 1 thread).
# The tests do not need the sigma index. The reproducibility and compact-data tests read
# the committed data/ files; the legacy s1.tsv byte test runs only when that file exists.
using Test
using Random
using VBF

include(joinpath(@__DIR__, "../helpers.jl"))
include(joinpath(@__DIR__, "../sampler.jl"))
include(joinpath(@__DIR__, "../validate.jl"))

@testset "quadratic APN census (F_2^8)" begin
    include("test_pipeline.jl")
    include("test_reproducibility.jl")
    include("test_compact.jl")
end
