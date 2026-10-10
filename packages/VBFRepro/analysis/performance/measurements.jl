"""Read BenchmarkTools trial summaries with adjacent immutable execution manifests.

A summary row represents one trial, not one independent execution per sample.
`elapsed_seconds` is its median per evaluation. Protocol identity participates in
all default grouping, so custom legacy repetitions are never silently pooled.
Raw BenchmarkTools JSON remains authoritative for within-trial distributions.
"""
function load_measurements(path)
    files = isfile(path) ? [abspath(path)] : sort([joinpath(base, f)
        for (base, _, names) in walkdir(path) for f in names if f == "timings.tsv"])
    isempty(files) && throw(ArgumentError("No timings.tsv measurements under $path"))
    tables = DataFrame[]
    nullable(x) = ismissing(x) || x === nothing || x == "" ? missing : x
    for file in files
        manifest = joinpath(dirname(file), "manifest.toml")
        isfile(manifest) || throw(ArgumentError("Missing measurement manifest: $manifest"))
        meta = TOML.parsefile(manifest)
        get(meta, "schema_version", 0) == 1 || throw(ArgumentError("Unsupported measurement schema in $manifest"))
        get(meta, "measurement_protocol", "BenchmarkTools trial summary v1") == "BenchmarkTools trial summary v1" ||
            throw(ArgumentError("Unsupported timing protocol in $manifest"))
        rows = CSV.read(file, DataFrame; delim='\t')
        required = [:package, :group, :workload, :case, :status, :samples,
                    :time_ns_min, :time_ns_median, :time_ns_mean, :memory_bytes, :allocations]
        all(k -> k in propertynames(rows), required) || throw(ArgumentError("Incomplete timing schema: $file"))
        # Failed rows remain in raw evidence; summaries consume only completed trials.
        rows = filter(:status => ==("ok"), rows)
        for row in eachrow(rows)
            row.samples > 0 && isfinite(row.time_ns_median) && row.time_ns_median > 0 ||
                throw(ArgumentError("Invalid completed timing in $file"))
        end
        n = nrow(rows)
        column(key, default=missing) = key in propertynames(rows) ? nullable.(rows[!, key]) : fill(default, n)
        config = get(meta, "configuration", get(meta, "config", Dict()))
        provenance = get(meta, "provenance", meta)
        function workload_spec(row)
            specs = filter(get(meta, "workloads", Any[])) do spec
                get(spec, "group", nothing) == row.group &&
                get(spec, "workload", nothing) == row.workload &&
                get(spec, "n", nothing) == (hasproperty(row, :n) ? row.n : nothing)
            end
            length(specs) <= 1 || throw(ArgumentError("Ambiguous workload metadata in $manifest"))
            isempty(specs) ? nothing : only(specs)
        end
        function case_identity(row)
            JSON3.write((; case=string(row.case), configuration=config, workload=workload_spec(row)))
        end
        data = DataFrame(id=collect(1:n),
            measurement_protocol=fill("BenchmarkTools trial summary v1", n),
            run_id=fill(string(get(meta, "run_id", get(meta, "run", basename(dirname(file))))), n),
            repetition=fill(1, n), package=String.(rows.package),
            paper_id=column(:paper_id), algorithm=string.(rows.group, "/", rows.workload),
            approach=column(:approach), mode=column(:mode),
            n=Union{Missing,Int}[ismissing(v) || v == 0 ? missing : v for v in column(:n)],
            case_parameters_json=String[case_identity(r) for r in eachrow(rows)],
            workload_parameters_json=String[canonical_json(get(something(workload_spec(r), Dict()), "parameters", nothing)) for r in eachrow(rows)],
            reference_scope_json=fill(canonical_json(get(meta, "inputs", nothing)), n),
            source_tree_sha256=fill(nullable(get(provenance, "source_tree_sha256", get(meta, "tree_sha256", missing))), n),
            julia_version=fill(nullable(get(provenance, "julia_version", missing)), n),
            cpu=fill(nullable(get(provenance, "cpu", missing)), n),
            julia_threads=fill(nullable(get(provenance, "julia_threads", get(meta, "threads", missing))), n),
            seed=String[string(get(something(workload_spec(r), Dict()), "seed",
                get(meta, "seed", get(config, "seed", "")))) for r in eachrow(rows)],
            elapsed_seconds=rows.time_ns_median ./ 1e9,
            trial_min_seconds=rows.time_ns_min ./ 1e9,
            trial_mean_seconds=rows.time_ns_mean ./ 1e9,
            trial_samples=rows.samples, memory_bytes=rows.memory_bytes, allocations=rows.allocations,
            known_apns_recovered=fill(missing, n), total_known_apns=fill(missing, n),
            candidates_processed=fill(missing, n), total_candidates=fill(missing, n), distinct_apns=fill(missing, n),
            measurement_path=fill(abspath(file), n),
            measurement_sha256=fill(bytes2hex(open(sha256, file)), n),
            execution_manifest_sha256=fill(bytes2hex(open(sha256, manifest)), n),
            raw_trial_sha256=fill(isfile(joinpath(dirname(file), "benchmarktools.json")) ?
                bytes2hex(open(sha256, joinpath(dirname(file), "benchmarktools.json"))) : missing, n))
        push!(tables, data)
    end
    reduce((a,b) -> vcat(a,b; cols=:union), tables)
end
