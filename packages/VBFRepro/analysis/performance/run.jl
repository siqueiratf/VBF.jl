#!/usr/bin/env julia
# Explicit consolidation/export/plot CLI over persisted data.
include("BenchAnalysis.jl")
using .BenchAnalysis
using CSV, Arrow, DataFrames, VBFRepro

action = isempty(ARGS) ? "inspect" : first(ARGS)
options = Dict(split(a[3:end], '='; limit=2) for a in ARGS[2:end])
raw = get(options, "database", BenchAnalysis.RAW_DATABASE)
output = get(options, "output", dirname(BenchAnalysis.ANALYSIS_DATABASE))
derived = joinpath(output, "analysis.sqlite")
dataset = get(options, "dataset", "all")

if action == "consolidate"
    tables = consolidate(raw; output=derived, profiles=get(options, "profiles", joinpath(VBFRepro.repo_root(), "data/perf")))
    for name in sort(collect(keys(tables)))
        println(name, ": ", nrow(tables[name]), " rows")
    end
elseif action == "export"
    export_tables(output; dataset)
elseif action == "plots"
    ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
    include("plots.jl")
    if dataset in ("all", "runtime")
        savefig(plot_runtime_vs_dimension(load_dataset("benchmarks", derived)), joinpath(output, "runtime.png"))
    end
    if dataset in ("all", "approach")
        for (i, (_, p)) in enumerate(sort(collect(plot_runtime_by_approach(load_dataset("benchmarks", derived))); by=first))
            savefig(p, joinpath(output, "approach_$(i).png"))
        end
    end
    if dataset in ("all", "profiles")
        savefig(plot_profile_subsystems(load_profile_components(derived)), joinpath(output, "profiles.png"))
    end
elseif action == "inspect"
    for name in ("benchmarks", "core", "papers", "profiles", "profile_components", "runtime")
        println(name, ": ", nrow(load_dataset(name, derived)), " rows")
    end
else
    error("Actions: consolidate, export, plots, inspect")
end
