"""Prepare a benchmark through the public command, with explicit bounded overrides."""
module RAMSeedPrepare
using TOML
include(joinpath(@__DIR__,"..","vbfsearch.jl"))

length(ARGS)==1 || error("usage: ram_seed_prepare.jl BENCHMARK.toml")
benchmark=TOML.parsefile(only(ARGS))
arguments=String.(benchmark["arguments"])
launch=VBFSearchCommand.plan(VBFSearchCommand.options(arguments);env=Dict{String,String}())
VBFSearchCommand.main(arguments;env=Dict{String,String}(),dispatch=_->nothing)
merge!(launch.config,get(benchmark,"overrides",Dict{String,Any}()))
command=joinpath(launch.config["workspace"],"command.toml")
open(io->TOML.print(io,launch.config;sorted=true),command,"w")
println("PREPARED ",command)
end
