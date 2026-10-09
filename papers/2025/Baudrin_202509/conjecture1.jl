# Implements bounded evidence for Conjecture 1 through switching exploration.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.2 — Conjecture 1 and preceding switching exploration
#
# Pseudocode:
#   1. Start from cube and Kim classes; expand selected EA representatives.
#   2. Enumerate bounded switching candidates and compare against known CCZ seeds.
#   3. Save verified mappings; retain budget-hit comparisons as undecided.
#   4. Report finite frontier exhaustion separately from global APN classification.
# VBF API used: switching_neighbors, partition_refinement_equivalence, ccz_equivalent_function
isdefined(@__MODULE__, :bgp_verify_graph_map) || include(joinpath(@__DIR__, "helpers.jl"))
isdefined(@__MODULE__, :section32_inputs) || include(joinpath(@__DIR__, "catalog_validation.jl"))

"""Compare a switching candidate with reference seeds, retaining all budget outcomes."""
function bgp_match(G, references, relation, state; groups=nothing)
    stopped = false
    checks = Dict{String,Any}[]
    for (i,F) in enumerate(references)
        if state.comparisons[] >= state.max_comparisons || state.remaining_time() <= 0
            return (; status=:undecided, index=0, certificate=nothing, checks,
                reason=state.remaining_time() <= 0 ? :time : :comparisons)
        end
        result = partition_refinement_equivalence(G, F; relation,
            max_nodes=state.remaining_nodes[], timeout_seconds=state.remaining_time(),
            max_memory_bytes=state.max_memory_bytes, rng=state.rng,
            automorphisms=groups === nothing ? nothing : groups[i])
        state.comparisons[] += 1
        state.remaining_nodes[] -= min(state.remaining_nodes[], nodes_visited(result))
        reason = result isa BudgetHit ? result.where_it_stopped.reason : :none
        push!(checks, Dict("reference_index"=>i, "relation"=>string(relation),
            "outcome"=>string(outcome_tag(result)), "nodes"=>nodes_visited(result),
            "stop_reason"=>string(reason)))
        if result isa Found
            A = only(search_solutions(result))
            bgp_verify_graph_map(G, F, A; relation) || error("equivalence witness failed graph validation")
            return (; status=:matched, index=i, certificate=A, checks, reason=:none)
        elseif result isa BudgetHit
            stopped = true
        elseif !proves_emptiness(result)
            error("negative equivalence outcome lacks exhaustion")
        end
    end
    return (; status=stopped ? :undecided : :inequivalent, index=0,
        certificate=nothing, checks, reason=stopped ? :search_budget : :none)
end

"""Explore switching evidence for Baudrin–Galissant–Perrin (2025), Conjecture 1."""
function conjecture1(; dimension=4, roots=nothing, known_roots=nothing,
    limit=1, max_evaluations=1 << 16, sample_size=1, max_nodes=10^6,
    timeout_seconds=30.0, max_subspaces=4096, max_memory_bytes=512 * 1024^2,
    max_comparisons=1000, max_frontier=4096, max_neighbors=4096,
    save_results=false, seed=940, full_search=false)
    bgp_validate_limits(; limit, max_evaluations, sample_size, max_nodes,
        timeout_seconds, max_subspaces, max_memory_bytes)
    all(x -> x >= 0, (max_comparisons,max_frontier,max_neighbors)) ||
        throw(ArgumentError("switching limits must be nonnegative"))
    dimension in (4,6,7) || throw(ArgumentError("dimension must be 4, 6 or 7"))
    started = time_ns()
    remaining_time() = max(0.0, timeout_seconds - (time_ns()-started)*1e-9)
    initial = roots === nothing ? (dimension == 6 ? [gold_apn(6),kim_apn()] : [gold_apn(dimension)]) : collect(roots)
    all(F -> inputbits(F) == dimension, initial) || throw(ArgumentError("root dimension differs"))
    references = known_roots === nothing ?
        (dimension == 6 && roots === nothing ? [r.function_value for r in section32_inputs()] : copy(initial)) : collect(known_roots)
    all(F -> inputbits(F) == dimension, references) || throw(ArgumentError("reference dimension differs"))
    cache = [Dict{Symbol,Any}(:seed=>F, :closure=>nothing, :expanded=>false,
        :label=>"reference $(i)") for (i,F) in enumerate(references)]
    rng = Xoshiro(seed)
    state = (; comparisons=Ref(0), max_comparisons, remaining_time,
        remaining_nodes=Ref(max_nodes), max_memory_bytes, rng)
    queue = NamedTuple[]
    scheduled = Set{Tuple}()
    witnesses = Dict{String,Any}[]
    records = Dict{String,Any}[]
    inconclusive = Dict{String,Any}[]
    expanded = 0
    evaluations = 0
    novel_ccz = 0
    stop_reason = :none
    constructors_complete = true
    closures_complete = true
    processed = 0
    roots_processed = 0

    function schedule(F, class_index, parent_index)
        key = Tuple(F.lut)
        key in scheduled && return true
        if length(queue) >= max_frontier
            stop_reason = :frontier
            return false
        end
        push!(scheduled,key)
        push!(queue,(; function_value=F, class_index, parent_index))
        return true
    end

    function expand_class(index, parent_index)
        entry = cache[index]
        entry[:expanded] && return
        entry[:expanded] = true
        F = entry[:seed]
        closure = ea_class_representatives(F; backend=:partition_refinement,
            max_nodes=state.remaining_nodes[], timeout_seconds=remaining_time(),
            max_subspaces, max_memory_bytes, rng)
        state.remaining_nodes[] -= min(state.remaining_nodes[], closure.orbit_result.nodes_visited)
        entry[:closure] = closure
        closures_complete &= closure.complete
        for (i,(G,A)) in enumerate(zip(closure.representatives,closure.mappings))
            push!(witnesses,bgp_witness(F,G,A; kind="orbit_representative",
                parent=parent_index, target=i, source_label=entry[:label],
                target_label="class $(index), EA orbit $(closure.orbit_indices[i])"))
            schedule(G,index,parent_index) || break
        end
        if !closure.complete && stop_reason === :none
            stop_reason = closure.stop_reason
            stop_reason === :none && (stop_reason = :time)
        end
    end

    for (i,F) in enumerate(initial[1:min(length(initial),sample_size)])
        limit == 0 && break
        remaining_time() <= 0 && (stop_reason=:time; break)
        existing = findfirst(entry -> entry[:seed].lut == F.lut,cache)
        if existing === nothing
            push!(cache,Dict{Symbol,Any}(:seed=>F,:closure=>nothing,
                :expanded=>false,:label=>"initial root $(i)"))
            existing = length(cache)
        end
        expand_class(existing,0)
        roots_processed += 1
    end

    while processed < length(queue) && expanded < limit && remaining_time() > 0
        evaluations >= max_evaluations && (stop_reason=:evaluations; break)
        state.comparisons[] >= max_comparisons && (stop_reason=:comparisons; break)
        processed += 1
        entry = queue[processed]
        F = entry.function_value
        result = switching_neighbors_bounded(F;
            max_evaluations=max_evaluations-evaluations,
            timeout_seconds=remaining_time(), max_neighbors)
        expanded += 1
        evaluations += nodes_visited(result)
        constructors_complete &= result isa Exhausted
        if result isa BudgetHit
            stop_reason = result.where_it_stopped.reason
        end
        neighbours = search_solutions(result)
        for (candidate_index,G) in enumerate(neighbours)
            differential_uniformity(G) == 2 || error("switching neighbour failed APN check")
            difference = F.lut .⊻ G.lut
            directions = unique(filter(!iszero,difference))
            length(directions) == 1 || error("candidate does not differ in a single switching direction")
            record = Dict{String,Any}("parent_index"=>processed,
                "candidate_index"=>candidate_index,"dimension"=>dimension,
                "parent_lut"=>Int.(F.lut),"candidate_lut"=>Int.(G.lut),
                "switching_direction"=>Int(only(directions)),
                "switching_support"=>findall(!iszero,difference) .- 1,
                "apn_verified"=>true)
            groups = [entry[:closure] === nothing ? nothing :
                entry[:closure].orbit_result.automorphisms for entry in cache]
            match = bgp_match(G,[entry[:seed] for entry in cache],:ccz,state;groups)
            record["ccz_checks"] = match.checks
            record["ccz_status"] = string(match.status)
            if match.status === :undecided
                record["status"] = "undecided_ccz"
                record["stop_reason"] = string(match.reason)
                push!(inconclusive,record)
                stop_reason = match.reason
            elseif match.status === :inequivalent
                novel_ccz += 1
                record["status"] = "inequivalent_to_current_reference_seeds"
                push!(cache,Dict{Symbol,Any}(:seed=>G,:closure=>nothing,
                    :expanded=>false,:label=>"relative new CCZ seed $(novel_ccz)"))
                record["class_index"] = length(cache)
                expand_class(length(cache),processed)
            else
                index = match.index
                record["class_index"] = index
                push!(witnesses,bgp_witness(G,cache[index][:seed],match.certificate;
                    kind="ccz_match",parent=processed,target=index,
                    target_label=cache[index][:label]))
                expand_class(index,processed)
                closure = cache[index][:closure]
                ea = bgp_match(G,closure.representatives,:ea,state)
                record["ea_checks"] = ea.checks
                record["ea_status"] = string(ea.status)
                if ea.status === :matched
                    record["status"] = "matched_ea"
                    record["ea_index"] = ea.index
                    push!(witnesses,bgp_witness(G,closure.representatives[ea.index],
                        ea.certificate;relation=:ea,kind="ea_match",parent=processed,
                        target=ea.index,target_label="class $(index), EA representative $(ea.index)"))
                elseif ea.status === :inequivalent
                    closure.complete && error("complete orbit census omitted a witnessed CCZ member")
                    record["status"] = "inequivalent_to_partial_ea_reference_list"
                    schedule(G,index,processed)
                else
                    record["status"] = "undecided_ea"
                    record["stop_reason"] = string(ea.reason)
                    push!(inconclusive,record)
                    stop_reason = ea.reason
                end
            end
            push!(records,record)
            if remaining_time() <= 0 || state.comparisons[] >= max_comparisons
                stop_reason = remaining_time() <= 0 ? :time : :comparisons
                if candidate_index < length(neighbours)
                    push!(inconclusive,Dict("parent_index"=>processed,
                        "status"=>"unprocessed_neighbours",
                        "count"=>length(neighbours)-candidate_index,
                        "stop_reason"=>string(stop_reason)))
                end
                break
            end
        end
    end
    frontier_exhausted = processed == length(queue)
    if remaining_time() <= 0
        stop_reason = :time
    elseif !frontier_exhausted && expanded >= limit && stop_reason === :none
        stop_reason = :parents
    elseif roots_processed < length(initial) && stop_reason === :none
        stop_reason = :roots
    end
    finite_region_complete = frontier_exhausted && constructors_complete &&
        closures_complete && isempty(inconclusive) && stop_reason === :none &&
        roots_processed == length(initial)
    data = bgp_metadata("conjecture1",seed,(; dimension,limit,max_evaluations,
        sample_size,max_nodes,timeout_seconds,max_subspaces,max_memory_bytes,
        max_comparisons,max_frontier,max_neighbors,full_search))
    merge!(data,Dict("initial_roots"=>[Int.(F.lut) for F in initial],
        "elapsed_seconds"=>(time_ns()-started)*1e-9,
        "constructors_complete"=>constructors_complete,
        "closures_complete"=>closures_complete,
        "cached_closures"=>[Dict("index"=>i,"label"=>entry[:label],
            "seed_lut"=>Int.(entry[:seed].lut),"expanded"=>entry[:expanded],
            "closure_available"=>entry[:closure] !== nothing,
            "complete"=>entry[:closure] === nothing ? false : entry[:closure].complete,
            "stop_reason"=>entry[:closure] === nothing ? "not_expanded" : string(entry[:closure].stop_reason),
            "automorphisms_complete"=>entry[:closure] === nothing ? false : entry[:closure].orbit_result.automorphisms_complete,
            "subspaces_complete"=>entry[:closure] === nothing ? false : entry[:closure].orbit_result.subspaces_complete,
            "actions_complete"=>entry[:closure] === nothing ? false : entry[:closure].orbit_result.actions_complete,
            "ea_representatives"=>entry[:closure] === nothing ? 0 : length(entry[:closure].representatives),
            "group_order"=>entry[:closure] === nothing ? "unavailable" : string(entry[:closure].orbit_result.group_order))
            for (i,entry) in enumerate(cache)],
        "reference_seeds"=>[Int.(entry[:seed].lut) for entry in cache],
        "parent_expansions"=>expanded,"candidate_evaluations"=>evaluations,
        "comparisons"=>state.comparisons[],"nodes_remaining"=>state.remaining_nodes[],
        "frontier_exhausted"=>frontier_exhausted,
        "finite_region_complete"=>finite_region_complete,
        "stop_reason"=>string(stop_reason),"relative_new_ccz_seeds"=>novel_ccz,
        "records"=>records,"inconclusive"=>inconclusive,"witnesses"=>witnesses,
        "frontier"=>[Dict("index"=>i,"class_index"=>entry.class_index,
            "parent_index"=>entry.parent_index,"lut"=>Int.(entry.function_value.lut),
            "processed"=>i<=processed) for (i,entry) in enumerate(queue)]))
    path = bgp_save("conjecture1",data;save_results)
    return (; status=finite_region_complete ? :finite_frontier_exhausted : :bounded,
        exhaustive=finite_region_complete, conjecture_proved=false, seed,
        dimension,expanded,evaluations,comparisons=state.comparisons[],
        frontier_exhausted,constructors_complete,closures_complete,stop_reason,
        relative_new_ccz_seeds=novel_ccz,records,inconclusive,witnesses,
        frontier=queue,processed,saved_path=path,
        elapsed_seconds=(time_ns()-started)*1e-9)
end

"""Report bounded switching evidence for Baudrin–Galissant–Perrin (2025), Conjecture 1."""
function conjecture1_report(io::IO=stdout; kwargs...)
    r = conjecture1(; kwargs...)
    print_section(io, "Conjecture 1 — Bounded switching evidence")
    print_kv(io, "status", r.status)
    print_kv(io, "dimension / seed", (r.dimension,r.seed))
    print_kv(io, "parent expansions / candidate evaluations / comparisons",
        (r.expanded,r.evaluations,r.comparisons))
    print_kv(io, "frontier exhausted", r.frontier_exhausted)
    print_kv(io, "relative new CCZ seeds", r.relative_new_ccz_seeds)
    print_kv(io, "undecided records", length(r.inconclusive))
    print_kv(io, "verified witnesses", length(r.witnesses))
    print_kv(io, "stop reason", r.stop_reason)
    print_kv(io, "conjecture proved", r.conjecture_proved)
    return r
end
