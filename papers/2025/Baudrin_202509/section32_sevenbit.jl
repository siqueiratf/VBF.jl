# Implements Section 3.2's quadratic seven-bit CCZ-closure census.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.2 — Implementation and Results
#
# Pseudocode:
#   1. Load the pinned 488 quadratic APN representatives.
#   2. Discover each CCZ group; enumerate Walsh-zero subspaces and their orbits.
#   3. Construct an admissible graph map for each orbit and count EA degrees.
#   4. Checkpoint each completed root; report partial totals with exact coverage.
# VBF API used: ea_class_representatives, partition_refinement_automorphisms
isdefined(@__MODULE__, :bgp_verify_graph_map) || include(joinpath(@__DIR__, "helpers.jl"))
isdefined(@__MODULE__, :section32_seven_inputs) || include(joinpath(@__DIR__, "catalog_validation.jl"))

function bgp_seven_checkpoint(path,data)
    mkpath(dirname(path))
    open(path*".tmp","w") do io
        TOML.print(io,data;sorted=true)
    end
    mv(path*".tmp",path;force=true)
    return path
end

"""Run or resume the seven-bit known-root closure census, with explicit limits.

The optimized subspace enumerator is an independently tested implementation
choice; it preserves the reference basis order and the paper's orbit algorithm.
Root distinctness is inherited from the pinned input collection and is labelled
separately from the completeness of the independently computed closures.
"""
function section32_sevenbit(; limit=1, timeout_seconds=60.0,
    per_root_timeout_seconds=120.0, max_nodes=typemax(Int),max_subspaces=10^6,
    max_memory_bytes=512*1024^2, save_results=false,resume=true,
    result_name="section32_sevenbit",group_algorithm=:optimized,seed=940,io::IO=stdout)
    all(x->x>=0,(limit,timeout_seconds,per_root_timeout_seconds,max_nodes,max_subspaces,max_memory_bytes)) ||
        throw(ArgumentError("limits must be nonnegative"))
    any(isnan,(timeout_seconds,per_root_timeout_seconds)) && throw(ArgumentError("timeout must not be NaN"))
    group_algorithm in (:paper,:optimized) || throw(ArgumentError("unknown group algorithm"))
    occursin(r"^[A-Za-z0-9_-]+$",result_name) || throw(ArgumentError("invalid result name"))
    inputs = section32_seven_inputs()
    started = time_ns()
    remaining() = max(0.0,timeout_seconds-(time_ns()-started)*1e-9)
    directory = joinpath(@__DIR__,"results",result_name)
    rows = Dict{String,Any}[]
    counts = Dict("2"=>0,"3"=>0,"4"=>0)
    for (index,input) in enumerate(inputs)
        index > limit && break
        F = input.function_value
        path = joinpath(directory,"root_$(lpad(index,3,'0')).toml")
        identity = Dict("source_lut"=>Int.(F.lut),"schema"=>"vbf-sevenbit-closure-v1",
            "source_hashes"=>BGP_SOURCE_CAPTURE.hashes,"seed"=>seed+index-1,
            "subspace_algorithm"=>"optimized","algorithm_profile"=>string(group_algorithm))
        row = resume && save_results && isfile(path) ? TOML.parsefile(path) : nothing
        if row !== nothing
            all(get(row,k,nothing)==v for (k,v) in identity) ||
                throw(ArgumentError("checkpoint provenance differs: $(path); use a new result_name"))
        end
        if row === nothing || !row["complete"]
            remaining() <= 0 && break
            root_started = time_ns()
            r = ea_class_representatives(F;backend=:partition_refinement,
                max_nodes,max_subspaces,max_memory_bytes,
                timeout_seconds=min(remaining(),per_root_timeout_seconds),
                subspace_algorithm=:optimized,algorithm=group_algorithm,prefer_permutations=false,
                rng=Xoshiro(seed+index-1))
            degrees = Dict{String,Int}()
            witnesses = Dict{String,Any}[]
            for (i,(G,A)) in enumerate(zip(r.representatives,r.mappings))
                differential_uniformity(G)==2 || error("seven-bit representative is not APN")
                degree = string(algebraic_degree(G))
                degrees[degree] = get(degrees,degree,0)+1
                push!(witnesses,bgp_witness(F,G,A;kind="orbit_representative",target=i,
                    source_label=input.label,target_label="EA orbit $(r.orbit_indices[i])"))
            end
            H = r.orbit_result.automorphisms
            row = merge(identity,Dict{String,Any}("root_index"=>index,"label"=>input.label,
                "identifier"=>input.identifier,"provenance"=>input.provenance,
                "complete"=>r.complete,"stop_reason"=>string(r.stop_reason),
                "group_order"=>H===nothing ? "unavailable" : string(H.order),"automorphisms_complete"=>r.orbit_result.automorphisms_complete,
                "subspaces_complete"=>r.orbit_result.subspaces_complete,
                "actions_complete"=>r.orbit_result.actions_complete,
                "spaces"=>r.orbit_result.nspaces,"classes"=>length(r.representatives),
                "degrees"=>degrees,"witnesses"=>witnesses,
                "nodes"=>r.orbit_result.nodes_visited,
                "bases"=>[Int.(b) for b in r.orbit_result.bases],
                "orbits"=>r.orbit_result.orbits,
                "generators"=>[Dict("linear_columns"=>Int.(A.linear.cols),"constant"=>Int(A.constant)) for A in (H===nothing ? [] : H.generators)],
                "elapsed_seconds"=>(time_ns()-root_started)*1e-9))
            save_results && bgp_seven_checkpoint(path,row)
        else
            for witness in row["witnesses"]
                G = SBox{7,UInt8}(UInt8.(witness["target_lut"]))
                A = F2AffineMap(F2LinearMap{14,UInt32}(UInt32.(witness["linear_columns"])),UInt32(witness["constant"]))
                bgp_verify_graph_map(F,G,A) || error("seven-bit checkpoint graph certificate failed")
            end
        end
        push!(rows,row)
        for (degree,count) in row["degrees"]
            counts[degree] = get(counts,degree,0)+count
        end
        println(io,"seven-bit root $(index)/488 $(input.label): $(row["spaces"]) spaces, $(row["classes"]) classes, complete=$(row["complete"]), $(round(row["elapsed_seconds"];digits=3)) s")
        flush(io)
        # Continue after a root-specific limit; partial totals remain explicit.
        remaining() <= 0 && break
    end
    complete = length(rows)==488 && all(r->r["complete"],rows)
    expected = Dict("2"=>488,"3"=>60302,"4"=>21619)
    totals_match = complete && counts==expected
    complete && !totals_match && error("seven-bit degree totals differ from the paper")
    summary = merge(bgp_metadata("section32_sevenbit",seed,(;limit,timeout_seconds,
        per_root_timeout_seconds,max_nodes,max_subspaces,max_memory_bytes,resume,
        group_algorithm=string(group_algorithm))),
        Dict("closures_complete"=>complete,"roots_distinctness"=>"loaded pinned sboxU collection; not independently certified by this run",
            "subspace_algorithm"=>"optimized","algorithm_profile"=>string(group_algorithm),"prefer_permutations"=>false,
            "roots_processed"=>length(rows),"roots_completed"=>count(r->r["complete"],rows),
            "degree_counts"=>counts,"total_classes"=>sum(values(counts)),
            "paper_totals_match"=>totals_match,"elapsed_seconds"=>(time_ns()-started)*1e-9,
            "rows"=>[Dict(k=>r[k] for k in ("root_index","label","spaces","classes","complete","degrees","elapsed_seconds","stop_reason")) for r in rows]))
    save_results && bgp_seven_checkpoint(joinpath(@__DIR__,"results",result_name*".toml"),summary)
    return (;complete,rows,counts,summary)
end
