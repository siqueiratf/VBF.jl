# Fast unit tests for the quadratic APN census (target: under 2 minutes, 1 thread).
# The tests do not need the sigma index; the reproducibility test reads the legacy
# s1.tsv when it is present and is skipped otherwise.
using Test
using Random
using VBF

include(joinpath(@__DIR__, "..", "helpers.jl"))
include(joinpath(@__DIR__, "..", "sampler.jl"))
include(joinpath(@__DIR__, "..", "validate.jl"))

@testset "quadratic APN census (F_2^8)" begin
    include("test_exact_counts.jl")
    include("test_counters.jl")
    include("test_pipeline.jl")
    include("test_reproducibility.jl")
end
