# Implements Section 3.2: Implementation and Results (six-bit census).
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.2 — Implementation and Results
#
# Pseudocode:
#   1. Load frozen known six-bit CCZ representatives via the catalog comparison layer.
#   2. Compute complete native orbits and check quadratic cases against ortho-derivatives.
#   3. Count degree classes, compare 691+25=716 and record exhaustive or stopped status.
# VBF API used: ea_class_orbits, ea_class_representatives, algebraic_degree
isdefined(@__MODULE__, :bgp_verify_graph_map) || include(joinpath(@__DIR__, "helpers.jl"))
isdefined(@__MODULE__, :section31) || include(joinpath(@__DIR__, "section31.jl"))
isdefined(@__MODULE__, :section32_inputs) || include(joinpath(@__DIR__, "catalog_validation.jl"))

"""Verify census-root CCZ distinctness using valid invariants or complete native decisions."""
function bgp_root_distinctness(rows, inputs; max_nodes, remaining_time,
    max_memory_bytes, seed)
    checks = Dict{String,Any}[]
    complete = true
    distinct = true
    quadratic_mugshots = Dict(i=>apn_ea_mugshot(inputs[i].function_value)
        for i in eachindex(rows) if rows[i].quadratic)
    spectra = Dict(i=>absolute_walsh_spectrum(inputs[i].function_value) for i in eachindex(rows))
    for i in eachindex(rows), j in (i+1):length(rows)
        record = Dict{String,Any}("first"=>rows[i].label,"second"=>rows[j].label)
        if rows[i].quadratic && rows[j].quadratic && quadratic_mugshots[i] != quadratic_mugshots[j]
            record["outcome"] = "inequivalent"
            record["proof"] = "ortho-derivative EA invariant mismatch; quadratic APN CCZ=EA (n>=4)"
        elseif spectra[i] != spectra[j]
            record["outcome"] = "inequivalent"
            record["proof"] = "absolute Walsh-spectrum CCZ invariant mismatch"
        else
            F,G = inputs[i].function_value,inputs[j].function_value
            decision = partition_refinement_equivalence(F,G; max_nodes,
                timeout_seconds=remaining_time(), max_memory_bytes,
                automorphisms=rows[j].result.automorphisms,rng=Xoshiro(seed+i+j))
            record["nodes"] = nodes_visited(decision)
            if decision isa Found
                A = only(search_solutions(decision))
                bgp_verify_graph_map(F,G,A) || error("root duplicate certificate failed validation")
                record["outcome"] = "equivalent"
                record["witness"] = bgp_witness(F,G,A;kind="duplicate_census_roots",
                    source_label=rows[i].label,target_label=rows[j].label)
                distinct = false
            elseif decision isa Exhausted && proves_emptiness(decision)
                record["outcome"] = "inequivalent"
                record["proof"] = "native CCZ search exhausted"
            else
                complete = false
                record["outcome"] = "undecided"
                record["stop_reason"] = string(decision.where_it_stopped.reason)
            end
        end
        push!(checks,record)
    end
    return (;complete,distinct,checks)
end

"""Run the six-bit census of Baudrin–Galissant–Perrin (2025), Section 3.2."""
function section32(; dimension=6, limit=1, max_evaluations=1 << 16,
    sample_size=1, max_nodes=10^6, timeout_seconds=30.0, max_subspaces=4096,
    max_memory_bytes=512 * 1024^2, save_results=false, seed=940,
    full_search=false, compare_legacy=true)
    bgp_validate_limits(; limit, max_evaluations, sample_size, max_nodes,
        timeout_seconds, max_subspaces, max_memory_bytes)
    dimension in (4,6,7) || throw(ArgumentError("dimension must be 4, 6 or 7"))
    full_search && dimension != 6 && throw(ArgumentError("full seven-bit census is not implemented"))
    started = time_ns()
    inputs = dimension == 6 ? section32_inputs() :
        [(; label="Gold x^3 ($(dimension) bits)", identifier="gold_x3_$(dimension)",
            function_value=gold_apn(dimension), provenance="VBF.gold_apn")]
    count_limit = min(length(inputs), limit, sample_size)
    full_search && count_limit != 14 && throw(ArgumentError("full census requires limit and sample_size at least fourteen"))
    rows = NamedTuple[]
    witnesses = Dict{String,Any}[]
    degrees = Dict{Int,Int}()
    quadratic_total = 0
    nonquadratic_total = 0
    crosschecks = true
    stop_reason = :none
    dataset_rows = Dict{String,Any}[]
    for (i,row) in enumerate(inputs)
        F = row.function_value
        push!(dataset_rows, Dict("label" => row.label, "identifier" => row.identifier,
            "provenance" => row.provenance, "lut" => Int.(F.lut),
            "lut_sha256" => bytes2hex(sha256(UInt8.(F.lut)))))
        i > count_limit && continue
        remaining = max(0.0, timeout_seconds - (time_ns() - started) * 1e-9)
        if remaining <= 0
            stop_reason = :time
            break
        end
        r = section31(; F, max_nodes, timeout_seconds=remaining, max_subspaces,
            max_memory_bytes, seed=seed+i-1, compare_legacy)
        reps = r.native.representatives
        row_degrees = Dict{Int,Int}()
        for G in reps
            differential_uniformity(G) == 2 || error("CCZ representative is not APN")
            d = algebraic_degree(G)
            row_degrees[d] = get(row_degrees, d, 0) + 1
            degrees[d] = get(degrees, d, 0) + 1
        end
        quadratic = algebraic_degree(F) == 2
        if quadratic
            quadratic_total += length(reps)
            r.exhaustive && get(row_degrees,2,0) != 1 && error("Corollary 1 quadratic EA class is not unique")
            crosschecks &= r.crosscheck_complete
        else
            nonquadratic_total += length(reps)
            r.exhaustive && length(reps) != 25 && error("six-bit nonquadratic class count differs from twenty-five")
        end
        push!(rows, (; label=row.label, identifier=row.identifier, quadratic,
            nspaces=r.native.orbit_result.nspaces, acting_maps=r.native.orbit_result.nauts,
            group_order=r.native.orbit_result.group_order, classes=length(reps),
            degrees=row_degrees, complete=r.exhaustive, crosscheck=r.legacy_agrees,
            crosscheck_complete=r.crosscheck_complete,
            stop_reason=r.native.stop_reason,
            elapsed_seconds=r.elapsed_seconds, result=r))
        append!(witnesses, [merge(c, Dict("source_label" => row.label)) for c in r.certificates])
        if !r.exhaustive
            stop_reason = r.native.stop_reason
            stop_reason === :none && (stop_reason = :time)
            break
        end
    end
    region_complete = length(rows) == count_limit && all(row -> row.complete, rows)
    root_distinctness = bgp_root_distinctness(rows,inputs;max_nodes,
        remaining_time=()->max(0.0,timeout_seconds-(time_ns()-started)*1e-9),
        max_memory_bytes,seed)
    closures_complete = dimension == 6 && count_limit == 14 && region_complete
    census_complete = closures_complete && root_distinctness.complete && root_distinctness.distinct
    exact_census = census_complete && crosschecks
    expected = Dict(2=>13,3=>521,4=>182)
    totals_match = census_complete ? quadratic_total == 691 && nonquadratic_total == 25 && degrees == expected : nothing
    census_complete && totals_match !== true && error("six-bit EA census differs from the paper")
    if stop_reason === :none && count_limit < length(inputs)
        stop_reason = :inputs
    elseif stop_reason === :none && !root_distinctness.complete
        stop_reason = :root_comparisons
    elseif stop_reason === :none && !root_distinctness.distinct
        stop_reason = :duplicate_roots
    end
    data = bgp_metadata("section32", seed, (; dimension, limit, max_evaluations,
        sample_size, max_nodes, timeout_seconds, max_subspaces, max_memory_bytes,
        full_search, compare_legacy))
    serial_rows = [Dict("label"=>r.label, "complete"=>r.complete,
        "automorphisms_complete"=>r.result.native.orbit_result.automorphisms_complete,
        "subspaces_complete"=>r.result.native.orbit_result.subspaces_complete,
        "actions_complete"=>r.result.native.orbit_result.actions_complete,
        "representatives_complete"=>r.result.native.complete,
        "spaces"=>r.nspaces, "classes"=>r.classes, "acting_maps"=>r.acting_maps,
        "group_order"=>string(r.group_order), "stop_reason"=>string(r.stop_reason),
        "degrees"=>Dict(string(k)=>v for (k,v) in r.degrees),
        "legacy_crosscheck_complete"=>r.crosscheck_complete,
        "elapsed_seconds"=>r.elapsed_seconds) for r in rows]
    merge!(data, Dict("census_complete"=>census_complete,
        "elapsed_seconds"=>(time_ns()-started)*1e-9,
        "roots_distinct"=>root_distinctness.complete && root_distinctness.distinct,
        "root_distinctness_complete"=>root_distinctness.complete,
        "root_distinctness_checks"=>root_distinctness.checks,
        "legacy_crosschecks_complete"=>crosschecks, "quadratic_classes"=>quadratic_total,
        "nonquadratic_classes"=>nonquadratic_total,
        "degree_counts"=>Dict(string(k)=>v for (k,v) in degrees),
        "stop_reason"=>string(stop_reason), "dataset"=>dataset_rows,
        "rows"=>serial_rows, "witnesses"=>witnesses))
    path = bgp_save("section32", data; save_results)
    return (; status=exact_census ? :exact_census : region_complete ? :exact_sample : :bounded,
        exhaustive=census_complete, exact_census, region_complete, seed,
        dimension, rows, degrees, quadratic_total, nonquadratic_total,
        crosschecks, totals_match, stop_reason, witnesses, root_distinctness, saved_path=path,
        elapsed_seconds=(time_ns()-started)*1e-9)
end

"""Report the Section 3.2 census of Baudrin–Galissant–Perrin (2025)."""
function section32_report(io::IO=stdout; kwargs...)
    r = section32(; kwargs...)
    print_section(io, "Section 3.2 — $(r.dimension)-bit known-class census")
    print_kv(io, "status", r.status)
    print_kv(io, "dimension / seed", (r.dimension,r.seed))
    for row in r.rows
        println(io, "  $(row.label): $(row.classes) EA classes, $(row.nspaces) spaces, complete=$(row.complete), legacy=$(row.crosscheck)")
    end
    print_kv(io, "complete six-bit census", r.exhaustive)
    print_kv(io, "CCZ roots independently distinct",
        r.root_distinctness.complete && r.root_distinctness.distinct)
    print_kv(io, "quadratic / nonquadratic closure totals", (r.quadratic_total,r.nonquadratic_total))
    print_kv(io, "degree counts", r.degrees)
    print_kv(io, "stop reason", r.stop_reason)
    return r
end
