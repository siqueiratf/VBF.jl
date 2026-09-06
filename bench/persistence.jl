"""Persist individual timed calls; all hashing and database work is outside timing."""
module BenchPersistence

using VBF, VBFCatalog, JSON3, SHA, Dates, UUIDs
import VBFCatalog: SQLite, DBInterface

export execution_writer

"""Input dimension used by the catalog's exact-LUT identity."""
dimension(::SBox{N}) where {N} = N

"""Collect APN-producing API outputs without counting APN inputs or recognition results."""
function apn_outputs(value)
    value isa SBox && return [value]
    value isa SearchOutcome && return apn_outputs(search_solutions(value))
    value isa AbstractDict && return apn_outputs(collect(values(value)))
    value isa NamedTuple && haskey(value, :sbox) && return apn_outputs(value.sbox)
    (value isa AbstractVector || value isa Tuple) && return reduce(vcat, (apn_outputs(v) for v in value); init = SBox[])
    return SBox[]
end

const PRODUCERS = Set([
    "gold_apn", "kasami_apn", "welch_apn", "niho_apn", "inverse_apn",
    "dobbertin_apn", "known_apn_monomials", "bcp_apn", "bcl_apn", "kim_apn",
    "taniguchi_apn", "taniguchi_apn_representatives", "apn_trims",
    "switching_neighbors", "search_quadratic_apn", "search_quadratic_apn_le",
    "search_qam", "search_qam_full", "extend_quadratic_apn",
])

"""Hash the actual source tree, including local edits, for run provenance."""
function source_hashes(root)
    out = Dict{String,String}()
    for dir in ("bench", "packages/VBF/src", "packages/VBFCatalog/src")
        for (base, _, files) in walkdir(joinpath(root, dir)), file in files
            endswith(file, ".jl") || endswith(file, ".sql") || continue
            path = joinpath(base, file)
            out[relpath(path, root)] = bytes2hex(sha256(read(path)))
        end
    end
    for file in ("Project.toml", "Manifest.toml")
        path = joinpath(root, file)
        isfile(path) && (out[file] = bytes2hex(sha256(read(path))))
    end
    out
end

"""
Create an append-only writer for one invocation. Reference scope is the distinct
exact LUTs in first-class catalog rows marked APN, optionally restricted by family.
Side corpora and EA/CCZ equivalence are deliberately not part of this scope.
"""
function execution_writer(db; options = (;), reference_family = nothing,
                          root = dirname(@__DIR__))
    run_id = string(uuid4())
    reference = Set((r.n, r.lut_sha256) for r in
        list_functions(db; is_apn = true, family = reference_family))
    reference_digest = bytes2hex(sha256(JSON3.write(sort!(collect(reference)))))
    provenance = (; options, julia_version = string(VERSION),
        cpu = Sys.cpu_info()[1].model, cpu_threads = Sys.CPU_THREADS,
        julia_threads = Threads.nthreads(),
        source_tree_sha256 = bytes2hex(sha256(JSON3.write(sort!(collect(source_hashes(root)); by = first)))),
        git_commit = readchomp(`git -C $root rev-parse HEAD`),
        git_dirty = !isempty(readchomp(`git -C $root status --porcelain`)),
        reference_digest)

    return function (c, payload, value, seconds, repetition, reps, seed)
        produces = c.group == "constructions" && c.name in PRODUCERS
        measured = c.metrics(payload, value, seconds)
        outputs = produces ? get(measured, :apns, apn_outputs(value)) : SBox[]
        identities = Set((dimension(F), lut_sha256_hex(F)) for F in outputs)
        output_dims = isempty(outputs) ? [c.name == "apn_trims" ? c.n - 1 :
                         c.name == "extend_quadratic_apn" ? c.n + 1 : c.n] :
                         unique(first.(collect(identities)))
        scoped = Set(key for key in reference if key[1] in output_dims)
        region = value isa SearchOutcome ? value.region : nothing
        processed = if c.name in ("search_qam", "search_qam_full") && value isa SearchOutcome
            # Cyclic QAM exits on its solution limit before incrementing evals.
            nodes_visited(value) + (c.name == "search_qam" && value isa Found ? 1 : 0)
        else
            nothing
        end
        defaults = (; time_to_first_apn_seconds = produces && value isa SBox ? seconds : nothing,
            search_space_size = region === nothing ? nothing : region.size,
            candidates_processed = processed, candidates_final_apn_test = nothing,
            total_apns = produces ? length(outputs) : nothing,
            distinct_apns = produces ? length(identities) : nothing,
            known_apns_recovered = produces ? length(intersect(identities, scoped)) : nothing,
            total_known_apns = produces ? length(scoped) : nothing)
        metrics = merge(defaults, measured)
        scope = produces ? JSON3.write((; table = "functions", is_apn = true,
            family = reference_family, dimensions = output_dims,
            identity = "(n, SHA-256(canonical_lut_bytes))", reference_digest)) : nothing
        params = JSON3.write((; provenance, case_parameters = c.parameters,
            payload_after_call = c.group == "catalog" ? nothing :
                payload isa NamedTuple && haskey(payload, :observation) ? payload.input : payload,
            note = c.note, cost = c.cost, reps, seed,
            warmup_calls = 1, allocation_calls = 1,
            search_region = region,
            metric_semantics = "Candidates are complete objects reaching the terminal stage, not partial tree nodes. Observed APNs are counted before algorithm deduplication; otherwise returned outputs are counted. NULL means unavailable or inapplicable.",
            observed_search = haskey(measured, :apns)))
        fields = (:time_to_first_apn_seconds, :search_space_size, :candidates_processed,
            :candidates_final_apn_test, :total_apns, :distinct_apns,
            :known_apns_recovered, :total_known_apns)
        vals = Any[run_id, repetition, string(now(UTC)) * "Z", c.group * "/" * c.name,
                   c.approach, c.n == 0 ? nothing : c.n, seconds]
        append!(vals, [f == :search_space_size && metrics[f] !== nothing ?
                       string(metrics[f]) : metrics[f] for f in fields])
        append!(vals, [scope, produces ? JSON3.write(sort!(collect(identities))) : nothing, params])
        sql = "INSERT INTO benchmark (run_id,repetition,recorded_at,algorithm,approach,n,elapsed_seconds," *
              join(string.(fields), ",") * ",reference_scope_json,apn_identities_json,parameters_json) VALUES (" *
              join(fill("?", length(vals)), ",") * ")"
        SQLite.execute(db, sql, Tuple(v === nothing ? missing : v for v in vals))
        nothing
    end
end

end
