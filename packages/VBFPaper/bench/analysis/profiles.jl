"""Rebuild normalized summaries from trusted local Profile.retrieve artifacts.

Legacy artifacts remain inspectable but cannot be joined without provenance.
The SHA-256 of the artifact identifies each session, independently of its path.
"""
function read_profiles(directory)
    profiles = DataFrame(profile_id=String[], artifact_path=String[],
        measurement_protocol=String[], profile_protocol=String[], package=Union{Missing,String}[],
        paper_id=Union{Missing,String}[], algorithm=String[], approach=Union{Missing,String}[],
        mode=Union{Missing,String}[], n=Union{Missing,Int}[], case_parameters_json=String[],
        workload_parameters_json=String[], reference_scope_json=String[],
        source_tree_sha256=Union{Missing,String}[], julia_version=Union{Missing,String}[],
        cpu=Union{Missing,String}[], julia_threads=Union{Missing,Int}[], seed=String[],
        joinable=Bool[], recorded_at=String[], profiled_seconds=Float64[],
        sampling_delay=Union{Missing,Float64}[], samples_total=Int[],
        core_samples=Int[], paper_samples=Int[], other_samples=Int[])
    components = DataFrame(profile_id=String[], owner=String[], subsystem=String[],
        operation=String[], samples=Int[])
    seen = Set{String}()
    for (base, _, files) in (isdir(directory) ? walkdir(directory) : [])
        "profile_raw.jls" in files || continue
        path = joinpath(base, "profile_raw.jls")
        digest = open(sha256, path) |> bytes2hex
        digest in seen && continue
        push!(seen, digest)
        saved = deserialize(path)
        c = saved.case
        provenance = get(saved, :provenance, (;))
        g = isempty(saved.data) ? nothing : flamegraph(saved.data; lidict=saved.lidict)
        split = attribute_flamegraph(g)
        nullable(s) = s === nothing || ismissing(s) || s == "" ? missing : s
        source = get(provenance, :source_tree_sha256, missing)
        cpu = get(provenance, :cpu, missing)
        threads = get(provenance, :julia_threads, missing)
        approach = get(c, :approach, missing)
        seed = string(get(saved, :seed, ""))
        manifest_path = joinpath(base, "manifest.toml")
        manifest = isfile(manifest_path) ? TOML.parsefile(manifest_path) : nothing
        protocol = manifest === nothing ? "legacy sampling profile" : get(manifest, "measurement_protocol", "unknown")
        package = manifest === nothing ? missing : get(manifest, "package", missing)
        reference = manifest === nothing ? "null" : canonical_json(get(manifest, "inputs", nothing))
        manifest_source = manifest === nothing ? source : get(get(manifest, "provenance", Dict()), "source_tree_sha256", missing)
        protocol_matches = manifest === nothing || (get(manifest, "schema_version", 0) == 1 &&
            protocol == "Julia sampling profile v1" && !ismissing(package) &&
            !ismissing(manifest_source) && !ismissing(source) && manifest_source == source)
        joinable = protocol_matches && !any(ismissing, (source, cpu, threads, approach)) &&
                   haskey(c, :parameters) && !isempty(seed)
        parameters = canonical_json(get(c, :parameters, nothing))
        push!(profiles, (digest, abspath(path),
            manifest === nothing ? "legacy timed repetition" : "BenchmarkTools trial summary v1", protocol, package, nullable(c.paper_id),
            c.group * "/" * c.name, approach, nullable(c.mode), c.n == 0 ? missing : c.n,
            JSON3.write(get(c, :parameters, nothing)), parameters, reference, source, saved.julia_version,
            cpu, threads, seed, joinable, saved.recorded_at, saved.profiled_seconds,
            get(saved, :sampling_delay, missing), split.samples_total,
            split.core_samples, split.paper_samples, split.other_samples))
        rows = profile_components(g)
        if !isempty(rows)
            grouped = combine(groupby(DataFrame(rows), [:owner, :subsystem, :operation]), :samples => sum => :samples)
            grouped.profile_id = fill(digest, nrow(grouped))
            append!(components, grouped; cols=:setequal)
        end
    end
    for owner in (:core, :paper, :other)
        transform!(profiles, [Symbol(owner, :_samples), :samples_total] => ByRow(ratio) => Symbol(owner, :_fraction))
    end
    components = leftjoin(components, select(profiles, :profile_id, :samples_total);
        on=:profile_id, validate=(false, true))
    transform!(components, [:samples, :samples_total] => ByRow(ratio) => :fraction)
    profiles, components
end
