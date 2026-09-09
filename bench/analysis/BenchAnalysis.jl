"""DataFrames-based analysis of immutable benchmark rows and saved Julia profiles."""
module BenchAnalysis

using SQLite, DBInterface, DataFrames, JSON3, Statistics
using SHA, Serialization, FlameGraphs, Dates
include("../profiling/attribution.jl")
using .ProfileAttribution

export load_benchmarks, load_benchmark, load_paper_benchmarks, load_core_benchmarks,
       load_profile_summaries, load_profile_components, derive_metrics, join_profiles,
       group_by_approach, group_by_dimension, group_by_mode, runtime_statistics,
       runtime_by_dimension, runtime_by_approach, mode_comparison,
       with_known_coverage, with_search_space_coverage, with_apns_per_second,
       with_profile_split, core_vs_paper_fractions, consolidate, load_dataset

const RAW_DATABASE = get(ENV, "BFA_CATALOG_PATH",
    normpath(joinpath(@__DIR__, "../../packages/VBFCatalog/BFA_catalog.sqlite")))
const ANALYSIS_DATABASE = joinpath(@__DIR__, "generated", "analysis.sqlite")
const PROFILE_KEYS = [:paper_id, :algorithm, :approach, :mode, :n,
    :case_parameters_json, :source_tree_sha256, :julia_version, :cpu,
    :julia_threads, :seed]
const GROUP_KEYS = [:run_id, :paper_id, :algorithm, :approach, :mode, :n,
    :case_parameters_json, :reference_scope_json, :source_tree_sha256,
    :julia_version, :cpu, :julia_threads, :seed]

"""Read an existing SQLite database with query-only protection and bound parameters."""
function query(path, sql, params=())
    isfile(path) || error("Database does not exist: $path")
    db = SQLite.DB(path)
    try
        DBInterface.execute(db, "PRAGMA query_only = ON")
        DataFrame(DBInterface.execute(db, sql, params))
    finally
        close(db)
    end
end

"""Load repetitions with SQL JSON projection; `where` uses bound `params`.

Large raw JSON payloads stay in SQLite by default. Set `include_raw=true` to
include them; `id` always links back to the full immutable row. Projection avoids
materializing gigabytes of repeated provenance just to compute a few ratios.
"""
function load_benchmarks(path::AbstractString=RAW_DATABASE; where="", params=(), include_raw=false)
    columns = query(path, "PRAGMA table_info(benchmark)").name
    selected = include_raw ? columns : setdiff(columns, ["parameters_json", "apn_identities_json"])
    expressions = ["\"$c\"" for c in selected]
    push!(expressions, "COALESCE(json_extract(parameters_json, '\$.case_parameters'), 'null') AS case_parameters_json")
    for key in (:source_tree_sha256, :julia_version, :cpu, :julia_threads)
        push!(expressions, "json_extract(parameters_json, '\$.provenance.$key') AS $key")
    end
    push!(expressions, "CAST(COALESCE(json_extract(parameters_json, '\$.seed'), '') AS TEXT) AS seed")
    query(path, "SELECT " * join(expressions, ", ") * " FROM benchmark" *
        (isempty(where) ? "" : " WHERE " * where), params)
end
const load_benchmark = load_benchmarks
"""Load paper workloads, including workloads classified as core_only."""
load_paper_benchmarks(path=RAW_DATABASE) = load_benchmarks(path; where="paper_id IS NOT NULL")
"""Load the public API benchmark suite (paper_id IS NULL)."""
load_core_benchmarks(path=RAW_DATABASE) = load_benchmarks(path; where="paper_id IS NULL")

"""Undefined ratios, including zero denominators, remain missing."""
ratio(a, b) = ismissing(a) || ismissing(b) || b <= 0 ? missing : Float64(a / b)
with_known_coverage(df) = transform(df, [:known_apns_recovered, :total_known_apns] => ByRow(ratio) => :known_coverage)
with_search_space_coverage(df) = transform(df, [:candidates_processed, :total_candidates] => ByRow(ratio) => :search_space_coverage)
with_apns_per_second(df) = transform(df, [:distinct_apns, :elapsed_seconds] => ByRow(ratio) => :distinct_apns_per_second)

"""Compute APN ratios without replacing raw counters or treating missing as zero."""
derive_metrics(df) = with_apns_per_second(with_search_space_coverage(with_known_coverage(df)))

"""Aggregate observed values; empty groups stay missing, singletons have no std."""
function runtime_statistics(df; by=intersect(GROUP_KEYS, propertynames(df)), metric=:elapsed_seconds)
    observed(f, x) = (v = collect(skipmissing(x)); isempty(v) ? missing : f(v))
    combine(groupby(df, by),
        metric => (x -> observed(minimum, x)) => :min,
        metric => (x -> observed(median, x)) => :median,
        metric => (x -> observed(mean, x)) => :mean,
        metric => (x -> count(!ismissing, x) < 2 ? missing : std(skipmissing(x))) => :std,
        metric => (x -> count(!ismissing, x)) => :n_observations)
end
"""Retain provenance/case strata by default; pass `by` to deliberately pool them."""
group_by_approach(df; kwargs...) = runtime_statistics(df; kwargs...)
group_by_dimension(df; kwargs...) = runtime_statistics(df; kwargs...)
group_by_mode(df; kwargs...) = runtime_statistics(df; kwargs...)
const runtime_by_dimension = group_by_dimension
const runtime_by_approach = group_by_approach
const mode_comparison = group_by_mode

"""Load a known derived table from a previously consolidated database."""
function load_dataset(name, path=ANALYSIS_DATABASE)
    name in ("benchmarks", "core", "papers", "profiles", "profile_components", "runtime", "provenance") ||
        throw(ArgumentError("Unknown dataset: $name"))
    query(path, "SELECT * FROM \"$name\"")
end
load_profile_summaries(path=ANALYSIS_DATABASE) = load_dataset("profiles", path)
load_profile_components(path=ANALYSIS_DATABASE) = load_dataset("profile_components", path)

"""Join compatible sessions after pooling their sample counts, never multiplying repetitions.

Only profiles with source/configuration provenance are eligible. Repeated sessions
are sample-weighted; their sample total is evidence per case, not per repetition.
"""
function join_profiles(df, profiles)
    eligible = filter(:joinable => x -> x == true, profiles)
    counts = combine(groupby(eligible, PROFILE_KEYS),
        [:core_samples, :paper_samples, :other_samples, :samples_total] .=> sum .=>
        [:core_samples, :paper_samples, :other_samples, :profile_samples_total],
        nrow => :profile_sessions)
    for owner in (:core, :paper, :other)
        transform!(counts, [Symbol(owner, :_samples), :profile_samples_total] =>
            ByRow(ratio) => Symbol(owner, :_fraction))
    end
    out = leftjoin(df, counts; on=PROFILE_KEYS, matchmissing=:equal, validate=(false, true))
    for owner in (:core, :paper, :other)
        out[!, Symbol(owner, :_seconds)] = out.elapsed_seconds .* out[!, Symbol(owner, :_fraction)]
    end
    out.runtime_fraction = out.other_fraction
    out
end

"""Compatibility loader for historical embedded summaries; prefer join_profiles."""
function with_profile_split(df)
    out = copy(df)
    for owner in (:core, :paper, :other)
        out[!, Symbol(owner, :_fraction)] = map(df.parameters_json) do raw
            p = get(JSON3.read(raw), :profile_split, nothing)
            p === nothing ? missing : get(p, Symbol(owner, :_fraction), missing)
        end
    end
    out
end
"""Mean fractions from already joined data; sample counts are not summed over repetitions."""
function core_vs_paper_fractions(df; by=intersect(GROUP_KEYS, propertynames(df)))
    combine(groupby(df, by), [:core_fraction, :paper_fraction, :runtime_fraction] .=>
        (x -> all(ismissing, x) ? missing : mean(skipmissing(x))) .=>
        [:mean_core_fraction, :mean_paper_fraction, :mean_runtime_fraction])
end

include("profiles.jl")
include("consolidate.jl")

end
