# Optional exploratory Plots.jl helpers; load after BenchAnalysis. No live workloads.
using Plots, DataFrames

"""Runtime curves retain case, mode, run, and configuration strata by default."""
function plot_runtime_vs_dimension(df; by=intersect(BenchAnalysis.GROUP_KEYS, propertynames(df)),
                                   metric=:elapsed_seconds, statistic=:median)
    stats = dropmissing(runtime_statistics(df; by, metric), [:n, statistic])
    plt = plot(xlabel="Dimension n", ylabel="$(statistic) $(metric)", legend=:outertopright)
    series = setdiff(by, [:n, :seed])
    for group in groupby(stats, series)
        sub = sort(DataFrame(group), :n)
        label = join((string(sub[1, k]) for k in intersect([:paper_id, :algorithm, :approach, :mode, :run_id], series)), " / ")
        plot!(plt, sub.n, sub[!, statistic]; marker=:circle, label)
    end
    plt
end

"""One exploratory plot per approach, distinguishing cases and runs."""
plot_runtime_by_approach(df) = Dict(string(first(sub.approach)) => plot_runtime_vs_dimension(DataFrame(sub))
    for sub in groupby(df, :approach))

"""Structured subsystem shares for individual profile sessions."""
function plot_profile_subsystems(components)
    stats = combine(groupby(components, [:profile_id, :owner, :subsystem]), :fraction => sum => :fraction)
    labels = ["$(first(r.profile_id, 8)) / $(r.subsystem)" for r in eachrow(stats)]
    bar(1:length(labels), stats.fraction; orientation=:h,
        yticks=(1:length(labels), labels), xlabel="Estimated sample fraction",
        legend=false, size=(1000, max(350, 40 * nrow(stats))),
        left_margin=10 * Plots.PlotMeasures.mm,
        bottom_margin=10 * Plots.PlotMeasures.mm, xlims=(0, 1))
end
