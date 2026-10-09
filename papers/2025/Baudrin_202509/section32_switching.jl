# Implements Section 3.2's switching closure of the known six-bit EA classes.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.2 — Implementation and Results; Gillot–Langevin (2026), Section 6, Fact 3
#
# Pseudocode:
#   1. Validate a saved complete census and its graph certificates.
#   2. Exhaust all nontrivial switching extensions in all 63 output directions.
#   3. Verify membership certificates against the fourteen known CCZ roots.
#   4. Checkpoint completed parents; compute the CCZ connection graph.
# VBF API used: switching_neighbors_bounded, partition_refinement_equivalence
isdefined(@__MODULE__, :bgp_verify_graph_map) || include(joinpath(@__DIR__, "helpers.jl"))

"""Load and independently validate graph certificates from a saved six-bit census."""
function bgp_saved_census(path)
    data = TOML.parsefile(path)
    get(data,"census_complete",false) && get(data,"roots_distinct",false) ||
        throw(ArgumentError("requires a complete census with distinct CCZ roots"))
    roots = [SBox{6,UInt8}(UInt8.(row["lut"])) for row in data["dataset"]]
    length(roots) == 14 || throw(ArgumentError("requires fourteen six-bit roots"))
    labels = [row["label"] for row in data["dataset"]]
    parents = NamedTuple[]
    for witness in data["witnesses"]
        get(witness,"kind","") == "orbit_representative" || continue
        source = findfirst(==(witness["source_label"]),labels)
        source === nothing && throw(ArgumentError("unknown census source label"))
        F = roots[source]
        G = SBox{6,UInt8}(UInt8.(witness["target_lut"]))
        Int.(F.lut) == witness["source_lut"] || throw(ArgumentError("census source LUT differs"))
        A = F2AffineMap(F2LinearMap{12,UInt32}(UInt32.(witness["linear_columns"])),UInt32(witness["constant"]))
        bgp_verify_graph_map(F,G,A) || throw(ArgumentError("invalid census graph certificate"))
        differential_uniformity(G) == 2 || throw(ArgumentError("census representative is not APN"))
        push!(parents,(;function_value=G,root_index=source,label=witness["target_label"]))
    end
    length(parents) == 716 || throw(ArgumentError("requires 716 certified EA representatives"))
    length(unique(Tuple(p.function_value.lut) for p in parents)) == 716 ||
        throw(ArgumentError("duplicate census representative LUT"))
    return (;roots,labels,parents,sha256=bytes2hex(sha256(read(path))))
end

# Use a temporary sibling so an interrupted write cannot destroy a checkpoint.
function bgp_atomic_toml(path,data)
    mkpath(dirname(path))
    temporary = path * ".tmp"
    open(temporary,"w") do io
        TOML.print(io,data;sorted=true)
    end
    mv(temporary,path;force=true)
    return path
end

function bgp_connection_components(n,edges)
    remaining = Set(1:n)
    components = Vector{Int}[]
    while !isempty(remaining)
        queue = [minimum(remaining)]
        delete!(remaining,first(queue))
        for i in queue, j in collect(remaining)
            if edges[i,j] || edges[j,i]
                delete!(remaining,j)
                push!(queue,j)
            end
        end
        push!(components,sort!(queue))
    end
    return components
end

"""
Exhaust switching over a certified 716-class census, resuming completed parents.

Completion proves closure of this finite known set under one-coordinate
switching. It does not prove Conjecture 1 (all six-bit APNs are known).
Each incomplete parent is recomputed on resume; complete parent files retain
all positive graph certificates and exact per-direction kernel diagnostics.
"""
function section32_switching(; census_path=joinpath(@__DIR__,"results","section32.toml"),
    limit=1, timeout_seconds=60.0, max_evaluations=10^6, max_nodes=10^6,
    max_memory_bytes=512*1024^2, save_results=false, resume=true,
    result_name="section32_switching", seed=940, io::IO=stdout)
    all(x->x>=0,(limit,timeout_seconds,max_evaluations,max_nodes,max_memory_bytes)) ||
        throw(ArgumentError("limits must be nonnegative"))
    isnan(timeout_seconds) && throw(ArgumentError("timeout must not be NaN"))
    occursin(r"^[A-Za-z0-9_-]+$",result_name) || throw(ArgumentError("invalid result name"))
    census = bgp_saved_census(census_path)
    started = time_ns()
    remaining() = max(0.0,timeout_seconds-(time_ns()-started)*1e-9)
    directory = joinpath(@__DIR__,"results",result_name)
    identity = Dict("census_sha256"=>census.sha256,"schema"=>"vbf-switching-closure-v1",
        "source_hashes"=>BGP_SOURCE_CAPTURE.hashes,"seed"=>seed)
    rows = Dict{String,Any}[]
    cache = Dict{Tuple,Dict{String,Any}}()
    edges = falses(length(census.roots),length(census.roots))
    groups = Dict{Int,Any}()
    spectra = absolute_walsh_spectrum.(census.roots)
    quadratic = is_quadratic_apn.(census.roots)
    mugshots = Dict(i=>apn_ea_mugshot(census.roots[i]) for i in eachindex(quadratic) if quadratic[i])
    rng = Xoshiro(seed)
    total_evaluations = 0
    total_comparisons = 0
    total_nodes = 0
    elapsed_previous = 0.0
    for (index,parent) in enumerate(census.parents)
        index > limit && break
        path = joinpath(directory,"parent_$(lpad(index,3,'0')).toml")
        saved = resume && save_results && isfile(path) ? TOML.parsefile(path) : nothing
        if saved !== nothing
            all(get(saved,k,nothing)==v for (k,v) in identity) ||
                throw(ArgumentError("checkpoint provenance differs: $(path); use a new result_name"))
        end
        if saved !== nothing && saved["complete"]
            row = saved
            elapsed_previous += row["elapsed_seconds"]
        else
            remaining() <= 0 && break
            F = parent.function_value
            row_started = time_ns()
            records = Dict{String,Any}[]
            directions = Dict{String,Any}[]
            kernels = Dict{Int,Dict{String,Any}}()
            comparisons = Ref(0)
            nodes = Ref(0)
            function classify(event,G)
                event === :apn || return
                key = Tuple(G.lut)
                if haskey(cache,key)
                    push!(records,copy(cache[key]))
                    return
                end
                spectrum = absolute_walsh_spectrum(G)
                isquadratic = is_quadratic_apn(G)
                mugshot = isquadratic ? apn_ea_mugshot(G) : nothing
                candidates = [i for i in eachindex(census.roots) if spectra[i]==spectrum &&
                    !(isquadratic && quadratic[i] && mugshots[i]!=mugshot)]
                sort!(candidates;by=i->i==parent.root_index ? 0 : 1)
                record = Dict{String,Any}("candidate_lut"=>Int.(G.lut),
                    "candidate_sha256"=>bytes2hex(sha256(UInt8.(G.lut))),"status"=>"outside_known_roots")
                checks = Dict{String,Any}[]
                uncertain = false
                for i in candidates
                    if remaining() <= 0
                        uncertain = true
                        break
                    end
                    if !haskey(groups,i)
                        groups[i] = partition_refinement_automorphisms(census.roots[i];
                            max_nodes,timeout_seconds=remaining(),max_memory_bytes,rng)
                    end
                    decision = partition_refinement_equivalence(G,census.roots[i];
                        max_nodes,timeout_seconds=remaining(),max_memory_bytes,
                        automorphisms=groups[i],rng)
                    comparisons[] += 1
                    nodes[] += nodes_visited(decision)
                    push!(checks,Dict("root_index"=>i,"outcome"=>string(outcome_tag(decision)),
                        "nodes"=>nodes_visited(decision)))
                    if decision isa Found
                        A = only(search_solutions(decision))
                        record["witness"] = bgp_witness(G,census.roots[i],A;kind="switching_ccz_match",target=i)
                        record["root_index"] = i
                        record["status"] = "matched"
                        break
                    elseif decision isa BudgetHit
                        uncertain = true
                    elseif !proves_emptiness(decision)
                        error("negative CCZ decision lacks exhaustion")
                    end
                end
                if record["status"] != "matched" && uncertain
                    record["status"] = "undecided"
                end
                record["checks"] = checks
                record["status"] == "matched" && (cache[key]=record)
                push!(records,record)
            end
            function diagnostics(event,payload)
                if event === :kernel
                    kernels[payload.direction] = Dict(string(k)=>v for (k,v) in pairs(payload))
                    return
                end
                event === :direction_complete || return
                push!(directions,merge(kernels[payload.direction],
                    Dict(string(k)=>v for (k,v) in pairs(payload))))
            end
            outcome = switching_neighbors_bounded(F;max_evaluations,
                timeout_seconds=remaining(),observer=classify,diagnostics)
            complete = outcome isa Exhausted && all(r->r["status"]=="matched",records)
            row = merge(copy(identity),Dict{String,Any}("parent_index"=>index,
                "parent_lut"=>Int.(F.lut),"source_root_index"=>parent.root_index,
                "complete"=>complete,"constructor_complete"=>outcome isa Exhausted,
                "stop_reason"=>outcome isa BudgetHit ? string(outcome.where_it_stopped.reason) : "none",
                "evaluations"=>nodes_visited(outcome),"neighbors"=>length(search_solutions(outcome)),
                "comparisons"=>comparisons[],"nodes"=>nodes[],"records"=>records,
                "directions"=>directions,"elapsed_seconds"=>(time_ns()-row_started)*1e-9))
            save_results && bgp_atomic_toml(path,row)
        end
        for record in row["records"]
            record["status"] == "matched" || continue
            witness = record["witness"]
            G = SBox{6,UInt8}(UInt8.(record["candidate_lut"]))
            i = record["root_index"]
            A = F2AffineMap(F2LinearMap{12,UInt32}(UInt32.(witness["linear_columns"])),UInt32(witness["constant"]))
            bgp_verify_graph_map(G,census.roots[i],A) || error("checkpoint certificate failed validation")
            edges[parent.root_index,i] = true
            cache[Tuple(G.lut)] = record
        end
        push!(rows,row)
        total_evaluations += row["evaluations"]
        total_comparisons += row["comparisons"]
        total_nodes += row["nodes"]
        println(io,"switching parent $(index)/716: $(row["neighbors"]) neighbors, complete=$(row["complete"]), $(round(row["elapsed_seconds"];digits=3)) s")
        flush(io)
        row["complete"] || break
    end
    complete = length(rows)==716 && all(row->row["complete"],rows)
    components = bgp_connection_components(length(census.roots),edges)
    summary = merge(bgp_metadata("section32_switching",seed,(;limit,timeout_seconds,
        max_evaluations,max_nodes,max_memory_bytes,resume)),Dict("census_sha256"=>census.sha256,
        "complete"=>complete,"conjecture_proved"=>false,"parents_completed"=>count(r->r["complete"],rows),
        "parents_processed"=>length(rows),"evaluations"=>total_evaluations,
        "comparisons"=>total_comparisons,"nodes"=>total_nodes,
        "unique_matched_luts"=>length(cache),"components"=>components,
        "edges"=>[[i,j] for i in axes(edges,1) for j in axes(edges,2) if edges[i,j]],
        "elapsed_seconds"=>(time_ns()-started)*1e-9,"reused_elapsed_seconds"=>elapsed_previous,
        "checkpoint_directory"=>result_name))
    save_results && bgp_atomic_toml(joinpath(@__DIR__,"results",result_name*".toml"),summary)
    return (;complete,rows,summary,components)
end
