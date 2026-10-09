"""
EA classes inside a CCZ class as orbits of Walsh-zero subspaces.

Baudrin, Galissant and Perrin, *Exploring the Set of APN Functions*, BFA 2025,
Proposition 2 and Section 3.1, https://hal.science/hal-05376704v2.
Native automorphisms come from Kaleyski–Sunde, ePrint 2026/940. Using group
generators in place of all elements gives the same orbits. The Walsh action
here is L⁻ᵀ; the paper writes Lᵀ, which has identical group orbits.
"""

function _ea_class_visit!(budget)
    _pr_check!(budget) || return false
    if budget.nodes >= budget.max_nodes
        budget.stopped = :nodes
        return false
    end
    budget.nodes += 1
    return true
end

function _ea_class_partition(parent)
    groups = Dict{Int,Vector{Int}}()
    for i in eachindex(parent)
        root = i
        while parent[root] != root
            root = parent[root]
        end
        push!(get!(groups, root, Int[]), i)
    end
    return sort!(collect(values(groups)); by = first)
end

function _ea_class_result(bases, parent, nauts, group_order, group_complete,
                          spaces_complete, actions_complete, reason, budget;
                          automorphisms = nothing)
    return (; bases, nspaces = length(bases), nauts,
        orbits = _ea_class_partition(parent), group_order,
        complete = group_complete && spaces_complete && actions_complete,
        automorphisms_complete = group_complete, subspaces_complete = spaces_complete,
        actions_complete, automorphisms, stop_reason = reason, nodes_visited = budget.nodes,
        elapsed_seconds = (time_ns() - budget.start) * 1e-9)
end

"""
    ea_class_orbits(F::SBox; backend=:ortho_derivative, automorphisms=nothing,
        max_nodes=typemax(Int), max_subspaces=typemax(Int), timeout_seconds=Inf,
        max_memory_bytes=512*1024^2, algorithm=:paper, rng=Xoshiro(940))

Partition the n-dimensional Walsh-zero subspaces into EA-class orbits under
the linear parts of graph automorphisms (Baudrin–Galissant–Perrin 2025,
Proposition 2 / Section 3.1). The native backend accepts arbitrary SBoxes.
Supply an [`AutomorphismGroupResult`](@ref) to reuse a discovered CCZ group.
Full-group certification requires its recorded graph to match `F`; unbound
or other-source results supply only a verified subgroup, even if marked complete.
`backend=:ortho_derivative` preserves the existing quadratic-APN default.
Use `backend=:partition_refinement` and explicit limits for bounded native
computations. The representative API selects the native backend by default.
The legacy route certifies the full CCZ group only for `n ≥ 4`, the hypothesis
of the paper's Proposition 3; smaller dimensions retain subgroup bounds.

Returns `(; bases, nspaces, nauts, orbits, group_order, complete,
automorphisms_complete, subspaces_complete, actions_complete, stop_reason,
nodes_visited, elapsed_seconds, automorphisms)`. `automorphisms` retains the
native group result for reuse in later equivalence queries (`nothing` for the
legacy backend). `nauts` counts acting maps, so it counts
generators in the native backend, rather than the order of their group.
`group_order` is the full ambient order reported by native discovery.

`complete` certifies an exact EA-class partition only when the subspace list,
automorphism group and orbit actions all completed. With all subspaces and a
partial group, the number of orbits is an upper bound. A partial subspace list
does not bound the total class count. The legacy automorphism enumeration is
not interruptible; its elapsed time is charged to this call before proceeding.
All later stages share the time/node budget; node counts include discovery,
bounded subspace candidates and orbit actions. Memory checks are allocation
estimates: an output cap is applied before subspace enumeration. Time checks
are cooperative; individual Walsh transforms and graph validations may finish
before a timeout is reported. The unbounded compatibility path (all limits,
including memory, disabled) does not count subspace candidates.
"""
function ea_class_orbits(F::SBox{N,T}; backend::Symbol = :ortho_derivative,
    automorphisms = nothing, max_nodes::Int = typemax(Int),
    max_subspaces::Int = typemax(Int), timeout_seconds::Real = Inf,
    max_memory_bytes::Int = 512 * 1024^2,
    algorithm::Symbol = :paper, rng::AbstractRNG = Xoshiro(940),
) where {N,T}
    backend in (:partition_refinement, :ortho_derivative) ||
        throw(ArgumentError("unknown EA-class orbit backend: $backend"))
    max_nodes >= 0 || throw(ArgumentError("max_nodes must be nonnegative"))
    max_subspaces >= 0 || throw(ArgumentError("max_subspaces must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    max_memory_bytes >= 0 || throw(ArgumentError("max_memory_bytes must be nonnegative"))
    algorithm in (:paper, :optimized) || throw(ArgumentError("unknown algorithm: $algorithm"))
    2N <= 32 || throw(ArgumentError("graph must fit UInt32"))
    backend === :ortho_derivative && automorphisms !== nothing &&
        throw(ArgumentError("supply automorphisms only to the native backend"))
    budget = _PRBudget(time_ns(), Float64(timeout_seconds), max_nodes, 0, :none)
    bases, parent = Vector{Vector{UInt32}}(), Int[]
    empty_result(reason) = _ea_class_result(bases, parent, 0, nothing,
        false, false, false, reason, budget)
    _pr_check!(budget) || return empty_result(:time)
    max_nodes == 0 && return empty_result(:nodes)
    max_subspaces == 0 && return empty_result(:solutions)
    base_memory = Int128(16) << (2N)
    # Allow for a basis, its full span, dictionary/union-find storage and one
    # temporary image. Deriving the cap before extraction bounds output growth.
    per_space_memory = (Int128(16) << N) + Int128(4)*N + 256
    base_memory <= max_memory_bytes || return empty_result(:memory)
    memory_cap = Int(min(Int128(typemax(Int)),
        (Int128(max_memory_bytes) - base_memory) ÷ per_space_memory))
    memory_cap > 0 || return empty_result(:memory)
    extraction_cap = min(max_subspaces, memory_cap)
    H = nothing
    if backend === :ortho_derivative
        is_quadratic_apn(F) || throw(ArgumentError("ortho-derivative backend requires quadratic APN"))
        maps = automorphisms_from_ortho_derivative(F)
        group_complete, group_order = N >= 4, nothing
        group_reason = group_complete ? :none : :subgroup
    else
        H = automorphisms === nothing ? partition_refinement_automorphisms(F;
            relation = :ccz, max_nodes, timeout_seconds = Float64(timeout_seconds),
            max_memory_bytes, algorithm, rng) : automorphisms
        H isa AutomorphismGroupResult{2N} || throw(ArgumentError("automorphisms must match the graph dimension"))
        automorphisms === nothing && (budget.nodes += H.nodes_visited)
        for A in H.generators
            _pr_graph_permutation(F, A)
        end
        maps = [A.linear for A in H.generators]
        bound_to_graph = H.graph_points !== nothing && H.graph_points == FunctionGraph(F).packed
        group_complete = H.complete && H.relation === :ccz && bound_to_graph
        group_order = H.order
        group_reason = H.complete && !group_complete ? :subgroup : H.stop_reason
    end
    _pr_check!(budget) || return _ea_class_result(bases, parent, length(maps),
        group_order, group_complete, false, false, :time, budget; automorphisms = H)
    zeroes = walsh_zeroes(F)
    remaining = max(0.0, budget.timeout - (time_ns() - budget.start) * 1e-9)
    subspaces = if timeout_seconds == Inf && max_nodes == typemax(Int) &&
                   max_subspaces == typemax(Int) && max_memory_bytes == typemax(Int)
        Exhausted(SearchRegion(:linear_subspaces, "dimension-$N"),
            extract_linear_subspaces(zeroes, N; max_bits = 2N); nodes_visited = 0)
    else
        extract_linear_subspaces_bounded(zeroes, N;
            max_bits = 2N, max_nodes = max(0, max_nodes - budget.nodes),
            max_subspaces = extraction_cap, timeout_seconds = remaining)
    end
    bases = search_solutions(subspaces)
    budget.nodes += nodes_visited(subspaces)
    spaces_complete = subspaces isa Exhausted
    parent = collect(eachindex(bases))
    spaces_reason = spaces_complete ? :none : subspaces.where_it_stopped.reason
    if spaces_reason === :solutions && memory_cap < max_subspaces
        spaces_reason = :memory
    end
    # Full spans retain the existing representation and avoid basis-convention
    # assumptions when identifying images of subspaces.
    estimate = base_memory + Int128(length(bases)) * per_space_memory
    if estimate > max_memory_bytes
        return _ea_class_result(bases, parent, length(maps), group_order,
            group_complete, spaces_complete, false, :memory, budget; automorphisms = H)
    end
    spans = Vector{Vector{UInt32}}()
    for b in bases
        _ea_class_visit!(budget) || return _ea_class_result(bases, parent,
            length(maps), group_order, group_complete, spaces_complete,
            false, budget.stopped, budget; automorphisms = H)
        push!(spans, sort!(span_from_basis(b)))
    end
    key = Dict{Vector{UInt32},Int}(s => i for (i,s) in pairs(spans))
    actions_complete = true
    for L in maps
        dual = transpose(inv(L))
        for (i,s) in pairs(spans)
            if !_ea_class_visit!(budget)
                actions_complete = false
                break
            end
            image = sort!(UInt32[dual(p) for p in s])
            j = get(key, image, 0)
            if j == 0
                spaces_complete && error("automorphism does not preserve the Walsh-zero subspaces")
                continue
            end
            ri, rj = i, j
            while parent[ri] != ri
                ri = parent[ri]
            end
            while parent[rj] != rj
                rj = parent[rj]
            end
            parent[ri] = rj
        end
        actions_complete || break
    end
    reason = !spaces_complete ? spaces_reason : !actions_complete ? budget.stopped :
        !group_complete ? group_reason : :none
    return _ea_class_result(bases, parent, length(maps), group_order,
        group_complete, spaces_complete, actions_complete, reason, budget; automorphisms = H)
end

"""
    ea_class_representatives(F::SBox; prefer_permutations=true, kwargs...)

One function and verified CCZ graph map per orbit from [`ea_class_orbits`](@ref),
including nonquadratic EA classes (Baudrin–Galissant–Perrin Section 3.1).
Returns `(; representatives, mappings, orbit_indices, orbit_result, complete,
stop_reason, elapsed_seconds)`.
Exact coverage requires `complete=true`. Construction shares the orbit call's
time limit; an interruption preserves the verified representatives already built.

The selected Walsh subspace supplies the high input coordinate rows of each
map. A complementary Walsh-zero subspace is preferred when available, yielding
a permutation representative; otherwise an arbitrary complement is admissible.
Constants are zero, since the admissibility criterion concerns the linear part.
"""
function ea_class_representatives(F::SBox{N,T}; prefer_permutations::Bool = true,
    backend::Symbol = :partition_refinement, timeout_seconds::Real = 60, kwargs...
) where {N,T}
    started = time_ns()
    result = ea_class_orbits(F; backend, timeout_seconds, kwargs...)
    representatives, mappings, orbit_indices = SBox{N,T}[], F2AffineMap{2N,UInt32}[], Int[]
    finished = true
    for (i,orbit) in pairs(result.orbits)
        if (time_ns() - started) * 1e-9 >= timeout_seconds
            finished = false
            break
        end
        basis = result.bases[first(orbit)]
        complement = complete_basis(basis, 2N)[(N+1):end]
        if prefer_permutations
            for other in result.bases
                if (time_ns() - started) * 1e-9 >= timeout_seconds
                    finished = false
                    break
                end
                if rank_f2(UInt32[basis;other]; nbits = 2N) == 2N
                    complement = other
                    break
                end
            end
        end
        finished || break
        L = transpose(F2LinearMap{2N,UInt32}(UInt32[complement;basis]))
        A = F2AffineMap(L, UInt32(0))
        G = ccz_equivalent_function(F, A)
        G === nothing && error("Walsh-zero subspace failed the admissibility criterion")
        push!(representatives, G)
        push!(mappings, A)
        push!(orbit_indices, i)
    end
    return (; representatives, mappings, orbit_indices, orbit_result = result,
        complete = result.complete && finished,
        stop_reason = finished ? result.stop_reason : :time,
        elapsed_seconds = (time_ns() - started) * 1e-9)
end
