using VBF, Random, TOML, VBFCatalog, VBFRepro
isdefined(@__MODULE__, :PerfSupport) || include(joinpath(@__DIR__, "..", "..", "VBF", "perf", "support.jl"))
using .PerfSupport
const SUITE = suite()
register_suites!(SUITE, joinpath(@__DIR__, "suites"), @__MODULE__)
abspath(PROGRAM_FILE) == (@__FILE__) && PerfSupport.main(SUITE, "VBFRepro")
