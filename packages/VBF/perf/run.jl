using VBF, Random, TOML
isdefined(@__MODULE__, :PerfSupport) || include(joinpath(@__DIR__, "support.jl"))
using .PerfSupport
const SUITE = suite()
register_suites!(SUITE, joinpath(@__DIR__, "suites"), @__MODULE__)
abspath(PROGRAM_FILE) == (@__FILE__) && PerfSupport.main(SUITE, "VBF")
