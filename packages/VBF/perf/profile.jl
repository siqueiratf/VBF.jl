include(joinpath(@__DIR__, "run.jl"))
include(joinpath(@__DIR__, "profile_support.jl"))
using .PerfProfiles
profile_main(SUITE,"VBF")
