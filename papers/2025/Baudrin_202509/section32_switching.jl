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
isdefined(@__MODULE__, :bgp_audit_switching_parent) ||
    include(joinpath(@__DIR__, "section32_switching_audit.jl"))

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

# No saved row escapes until every binding, coverage and certificate check
# finishes. Deadline interruption leaves its on-disk checkpoint unchanged.
function _bgp_read_switching_checkpoint(path,parent,census,identity;
    parent_index,check_deadline=nothing)
    _bgp_switch_audit_check(check_deadline)
    saved = TOML.parsefile(path)
    _bgp_switch_audit_check(check_deadline)
    bgp_audit_switching_parent(saved,parent,census;parent_index,
        identity,check_deadline)
    return saved
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

# Each invocation owns its candidate records, constraints and equivalence RNG.
# Target groups are immutable inputs: the equivalence API rebuilds and validates
# its own permutation group from their generators before every query.
function _bgp_switching_parent(index,parent,census,identity,remaining,get_group,
    spectra,quadratic,mugshots;max_evaluations,max_nodes,max_memory_bytes,seed)
    F = parent.function_value
    row_started = time_ns()
    rng = Xoshiro(UInt64(seed) ⊻ UInt64(index))
    records = Dict{String,Any}[]
    directions = Dict{String,Any}[]
    kernels = Dict{Int,Dict{String,Any}}()
    comparisons = Ref(0)
    nodes = Ref(0)
    membership_seconds = Ref(0.0)
    function classify(event,G)
        event === :apn || return
        started = time_ns()
        try
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
                group = get_group(i)
                decision = partition_refinement_equivalence(G,census.roots[i];
                    max_nodes,timeout_seconds=remaining(),max_memory_bytes,
                    automorphisms=group,rng)
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
            push!(records,record)
        finally
            membership_seconds[] += (time_ns()-started)*1e-9
        end
    end
    function diagnostics(event,payload)
        if event === :kernel
            kernels[payload.direction] = Dict(string(k)=>v for (k,v) in pairs(payload))
        elseif event === :direction_complete
            push!(directions,merge(kernels[payload.direction],
                Dict(string(k)=>v for (k,v) in pairs(payload))))
        end
    end
    constructor_started = time_ns()
    outcome = switching_neighbors_bounded(F;max_evaluations,
        timeout_seconds=remaining(),observer=classify,diagnostics)
    constructor_seconds = (time_ns()-constructor_started)*1e-9-membership_seconds[]
    complete = outcome isa Exhausted && all(r->r["status"]=="matched",records)
    return merge(copy(identity),Dict{String,Any}("parent_index"=>index,
        "parent_lut"=>Int.(F.lut),"source_root_index"=>parent.root_index,
        "complete"=>complete,"constructor_complete"=>outcome isa Exhausted,
        "stop_reason"=>outcome isa BudgetHit ? string(outcome.where_it_stopped.reason) : "none",
        "evaluations"=>nodes_visited(outcome),"neighbors"=>length(search_solutions(outcome)),
        "comparisons"=>comparisons[],"nodes"=>nodes[],"records"=>records,
        "directions"=>directions,"elapsed_seconds"=>(time_ns()-row_started)*1e-9,
        "constructor_seconds"=>max(0.0,constructor_seconds),
        "membership_including_group_wait_seconds"=>membership_seconds[]))
end

"""
Exhaust switching over a certified 716-class census, resuming checked parents.

Completion proves closure of this finite known set under one-coordinate
switching. It does not prove Conjecture 1 (all six-bit APNs are known).
`workers=1` is sequential; `workers>1` schedules independent parents on Julia
threads (start Julia with at least that many threads). Each parent has its own
constraints, records and deterministic parent-index RNG. A locked cache discovers
one target group per root; searches create their own mutable pruning groups.
Positive certificates may differ from older sequential runs, while candidate
LUTs, coverage and membership remain unchanged. Scheduling is an experiment
optimization, separate from the mathematical construction and paper algorithms.

The global timeout is cooperative. Completed later checkpoints may survive an
earlier incomplete parent; summaries include only the ordered prefix through
that first incomplete parent. Resume validates source/parent binding, independent
flat dimensions, quotient coverage and graph certificates before accepting rows.
Timing fields separate the constructor from membership callbacks; parent stage
seconds are sums, not parallel wall time. Membership includes target-group wait.
Input-census validation precedes the search timeout and is timed separately.
Checkpoint audits share that timeout; a stopped audit contributes no saved row.
"""
function section32_switching(; census_path=joinpath(@__DIR__,"results","section32.toml"),
    limit=1, timeout_seconds=60.0, max_evaluations=10^6, max_nodes=10^6,
    max_memory_bytes=512*1024^2, save_results=false, resume=true,
    result_name="section32_switching", seed=940, workers::Int=1, io::IO=stdout)
    all(x->x>=0,(limit,timeout_seconds,max_evaluations,max_nodes,max_memory_bytes,seed)) ||
        throw(ArgumentError("limits and seed must be nonnegative"))
    isnan(timeout_seconds) && throw(ArgumentError("timeout must not be NaN"))
    1 <= workers <= Threads.nthreads() ||
        throw(ArgumentError("workers must be between 1 and Threads.nthreads(); start Julia with --threads"))
    occursin(r"^[A-Za-z0-9_-]+$",result_name) || throw(ArgumentError("invalid result name"))
    validation_started = time_ns()
    census = bgp_saved_census(census_path)
    census_seconds = (time_ns()-validation_started)*1e-9
    started = time_ns()
    remaining() = max(0.0,timeout_seconds-(time_ns()-started)*1e-9)
    directory = joinpath(@__DIR__,"results",result_name)
    identity = Dict("census_sha256"=>census.sha256,"schema"=>"vbf-switching-closure-v1",
        "source_hashes"=>BGP_SOURCE_CAPTURE.hashes,"seed"=>seed)
    nparents = min(limit,length(census.parents))
    computed = Union{Nothing,Dict{String,Any}}[nothing for _ in 1:nparents]
    # Ordinary Bool slots: packed BitVector writes to distinct bits can race.
    reused = fill(false,nparents)
    checkpoint_write_seconds = zeros(Float64,nparents)
    checkpoint_validation_seconds = zeros(Float64,nparents)
    group_lock = ReentrantLock()
    io_lock = ReentrantLock()
    groups = Dict{Int,Any}()
    group_seconds = Ref(0.0)
    prep_started = time_ns()
    spectra = Any[nothing for _ in census.roots]
    quadratic = fill(false,length(census.roots))
    mugshots = Dict{Int,Any}()
    for i in eachindex(census.roots)
        remaining() <= 0 && break
        spectra[i] = absolute_walsh_spectrum(census.roots[i])
        remaining() <= 0 && break
        quadratic[i] = is_quadratic_apn(census.roots[i])
        remaining() <= 0 && break
        quadratic[i] && (mugshots[i] = apn_ea_mugshot(census.roots[i]))
    end
    preparation_seconds = (time_ns()-prep_started)*1e-9
    function get_group(i)
        lock(group_lock) do
            get!(groups,i) do
                t0 = time_ns()
                group = partition_refinement_automorphisms(census.roots[i];
                    max_nodes,timeout_seconds=remaining(),max_memory_bytes,
                    rng=Xoshiro(UInt64(seed) ⊻ (UInt64(i) << 32)))
                group_seconds[] += (time_ns()-t0)*1e-9
                return group
            end
        end
    end
    function process(index)
        remaining() <= 0 && return
        parent = census.parents[index]
        path = joinpath(directory,"parent_$(lpad(index,3,'0')).toml")
        saved = nothing
        if resume && save_results && isfile(path)
            t0 = time_ns()
            try
                saved = _bgp_read_switching_checkpoint(path,parent,census,identity;
                    parent_index=index,check_deadline=()->remaining()>0)
            catch err
                err isa BGPSwitchingAuditDeadline && return
                rethrow()
            finally
                checkpoint_validation_seconds[index] = (time_ns()-t0)*1e-9
            end
        end
        if saved !== nothing && saved["complete"]
            row = saved
            reused[index] = true
        else
            remaining() <= 0 && return
            row = _bgp_switching_parent(index,parent,census,identity,remaining,get_group,
                spectra,quadratic,mugshots;max_evaluations,max_nodes,max_memory_bytes,seed)
            if save_results
                t0 = time_ns()
                bgp_atomic_toml(path,row)
                checkpoint_write_seconds[index] = (time_ns()-t0)*1e-9
            end
        end
        computed[index] = row
        lock(io_lock) do
            println(io,"switching parent $(index)/716: $(row["neighbors"]) neighbors, complete=$(row["complete"]), $(round(row["elapsed_seconds"];digits=3)) s")
            flush(io)
        end
    end
    if workers == 1
        for index in 1:nparents
            process(index)
            row = computed[index]
            (row === nothing || !row["complete"]) && break
        end
    else
        jobs = Channel{Int}(nparents)
        for index in 1:nparents
            put!(jobs,index)
        end
        close(jobs)
        @sync for _ in 1:workers
            Threads.@spawn for index in jobs
                process(index)
            end
        end
    end
    rows = Dict{String,Any}[]
    for row in computed
        row === nothing && break
        push!(rows,row)
        row["complete"] || break
    end
    edges = falses(length(census.roots),length(census.roots))
    cache = Set{Tuple}()
    for row in rows, record in row["records"]
        record["status"] == "matched" || continue
        edges[row["source_root_index"],record["root_index"]] = true
        push!(cache,Tuple(record["candidate_lut"]))
    end
    complete = length(rows)==length(census.parents) && all(row->row["complete"],rows)
    components = bgp_connection_components(length(census.roots),edges)
    summary = merge(bgp_metadata("section32_switching",seed,(;limit,timeout_seconds,
        max_evaluations,max_nodes,max_memory_bytes,resume,workers)),Dict("census_sha256"=>census.sha256,
        "complete"=>complete,"conjecture_proved"=>false,"parents_completed"=>count(r->r["complete"],rows),
        "parents_processed"=>length(rows),"evaluations"=>sum(r->r["evaluations"],rows;init=0),
        "comparisons"=>sum(r->r["comparisons"],rows;init=0),"nodes"=>sum(r->r["nodes"],rows;init=0),
        "unique_matched_luts"=>length(cache),"components"=>components,
        "edges"=>[[i,j] for i in axes(edges,1) for j in axes(edges,2) if edges[i,j]],
        "elapsed_seconds"=>(time_ns()-started)*1e-9,
        "reused_elapsed_seconds"=>sum(i->reused[i] ? rows[i]["elapsed_seconds"] : 0.0,eachindex(rows);init=0.0),
        "stage_seconds"=>Dict("census_validation"=>census_seconds,
            "invariant_preparation"=>preparation_seconds,"target_group_discovery"=>group_seconds[],
            "constructor_excluding_membership_sum"=>sum(r->get(r,"constructor_seconds",0.0),rows;init=0.0),
            "membership_including_group_wait_sum"=>sum(r->get(r,"membership_including_group_wait_seconds",0.0),rows;init=0.0),
            "checkpoint_writes_sum"=>sum(checkpoint_write_seconds),
            "checkpoint_validation_sum"=>sum(checkpoint_validation_seconds)),
        "checkpoint_directory"=>result_name))
    save_results && bgp_atomic_toml(joinpath(@__DIR__,"results",result_name*".toml"),summary)
    return (;complete,rows,summary,components)
end
