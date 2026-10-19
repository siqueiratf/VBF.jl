"""
    QuadraticExtensionOrbitPlan

Verified subgroup orbits of eligible cosets in `Alt(n)/V`. `cosets` retain the
original search order; each `representative_of[i]` is an original coset index.
The rooted forest (`tree_parent`, `tree_generator`) records a transporter to
every coset. A subgroup suffices: no assertion that the full stabilizer was
found is necessary for this reduction.

Construct plans with [`quadratic_extension_orbits`](@ref). A plan certifies
orbit coverage of its supplied domain, not completeness of an APN search.
"""
struct QuadraticExtensionOrbitPlan
    n::Int
    basis::Vector{UInt32}
    quotient_mask::UInt32
    cosets::Vector{UInt32}
    generators::Vector{Vector{UInt16}}
    representatives::Vector{Int}
    representative_of::Vector{Int}
    tree_parent::Vector{Int}
    tree_generator::Vector{Int}
end

"""
    quadratic_space_stabilizers(G, V; max_nodes=10_000,
        timeout_seconds=1.0, max_memory_bytes=512*1024^2,
        algorithm=:optimized)

Discover a verified subgroup of input changes stabilizing the square-free
quadratic space `V` modulo affine functions. Uses the native bounded EA
automorphism solver on its rectangular component table and replays every
projected input generator on `V`. Identity input actions, including the
universal quadratic translations, are discarded.

Returns `(; generators, complete, stop_reason, nodes_visited,
elapsed_seconds, discarded_identity_actions)`. A stopped solver still
provides safe generators, but `complete=false`. Generator discovery can cost
more than it saves for a space with trivial input stabilizer. It is never
enabled implicitly by `v5_extensions`.
"""
function quadratic_space_stabilizers(G::QuadraticExtensions.Geometry,
        V::AbstractVector{<:Integer}; max_nodes::Int=10_000,
        timeout_seconds::Real=1.0, max_memory_bytes::Int=512*1024^2,
        algorithm::Symbol=:optimized)
    max_nodes >= 0 || throw(ArgumentError("max_nodes must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    max_memory_bytes >= 0 || throw(ArgumentError("max_memory_bytes must be nonnegative"))
    algorithm in (:paper, :optimized) || throw(ArgumentError("unknown automorphism algorithm"))
    start = time_ns()
    R = _quadratic_space_basis(G, V)
    d = length(R)
    1 <= d <= G.n || throw(ArgumentError("component-space dimension must be in 1:$(G.n)"))
    F = VBFTable{G.n,d}(QuadraticExtensions.lut_from_coeffs(G,
        QuadraticExtensions.forms_to_coeffs(R, G.N)))
    remaining = max(0.0, Float64(timeout_seconds) - (time_ns()-start)*1e-9)
    group = partition_refinement_automorphisms(F; relation=:ea, max_nodes,
        timeout_seconds=remaining, max_memory_bytes, algorithm)
    identity = identity_linear_map(G.n, UInt16).cols
    generators = Vector{UInt16}[]
    discarded_identity_actions = 0
    for ambient in group.generators
        columns = UInt16[ambient.linear.cols[d+i] >> d for i in 1:G.n]
        verify_quadratic_space_transporter(G, R, R, columns) ||
            error("native EA automorphism failed quadratic-space stabilizer replay")
        if columns == identity
            discarded_identity_actions += 1
        elseif !(columns in generators)
            push!(generators, columns)
        end
    end
    return (; generators, complete=group.complete, stop_reason=group.stop_reason,
        nodes_visited=group.nodes_visited, elapsed_seconds=(time_ns()-start)*1e-9,
        discarded_identity_actions)
end

@inline function _quadratic_coset_remainder(q::UInt32, R, pivots)
    for (r, p) in zip(R, pivots)
        isodd(q >> p) && (q ⊻= r)
    end
    return q
end

@inline function _quadratic_coset_action(t::UInt32, columns::Vector{UInt32})
    result = UInt32(0)
    while !iszero(t)
        i = trailing_zeros(t)
        result ⊻= columns[i+1]
        t &= t-UInt32(1)
    end
    return result
end

"""
    quadratic_extension_orbits(G, V, eligible_cosets, generators)

Compute deterministic subgroup orbits in `Alt(n)/V`. Cosets are the nonzero
`UInt32` quotient coordinates used by `QuadraticExtensions.lift`, with the
canonical RREF of `V`. The supplied domain must be distinct and closed under
all supplied generators; malformed maps, maps not stabilizing `V`, and
nonclosed domains are rejected. Representatives are the first original
indices in their orbits. Every generator is checked by exact pullback.

For a verified stabilizer `A`, pullback bijects completions of `V+<x>` with
completions of `V+<A^*x>`, preserving polar rank, bentness, dimension and the APN
condition. Thus only representative cosets require enumeration. Transporting
their outputs is essential: discarding the other outputs would lose original
coset provenance and, in general, distinct coefficient-space outputs.
"""
function quadratic_extension_orbits(G::QuadraticExtensions.Geometry,
        V::AbstractVector{<:Integer}, eligible_cosets::AbstractVector{<:Integer},
        generators::AbstractVector)
    R = _quadratic_space_basis(G, V)
    _, pivots = QuadraticExtensions.rref(R)
    _, mask = QuadraticExtensions.pivots_masks(R, pivots, G.N)
    D = G.N-length(R)
    all(x -> 0 < x < (UInt64(1) << D), eligible_cosets) ||
        throw(ArgumentError("eligible cosets must be nonzero D-bit quotient coordinates"))
    X = UInt32.(eligible_cosets)
    length(unique(X)) == length(X) || throw(ArgumentError("eligible cosets must be distinct"))
    checked_generators = Vector{UInt16}[]
    quotient_generators = Vector{UInt32}[]
    for columns in generators
        columns isa AbstractVector{<:Integer} ||
            throw(ArgumentError("generators must be vectors of input-map columns"))
        verify_quadratic_space_transporter(G, R, R, columns) ||
            throw(ArgumentError("input generator does not stabilize the quadratic space"))
        columns in checked_generators && continue
        A = _quadratic_space_columns(G, columns)
        wedges = _quadratic_space_pullback_columns(G, A)
        qcolumns = UInt32[]
        for i in 0:D-1
            q = QuadraticExtensions.lift(UInt32(1)<<i, mask)
            image = _quadratic_space_pullback(q, wedges)
            image = _quadratic_coset_remainder(image, R, pivots)
            push!(qcolumns, QuadraticExtensions.pext(image, mask))
        end
        push!(checked_generators, copy(A.cols))
        push!(quotient_generators, qcolumns)
    end
    index = Dict(x=>i for (i,x) in enumerate(X))
    # Check closure even for an empty generator subgroup. A finite closed
    # domain is permuted by each invertible action, so forward BFS gives the
    # full subgroup orbit, including inverse-generator images.
    for qcolumns in quotient_generators, x in X
        haskey(index, _quadratic_coset_action(x, qcolumns)) ||
            throw(ArgumentError("eligible domain is not closed under a supplied stabilizer"))
    end
    representatives = Int[]
    representative_of = zeros(Int, length(X))
    tree_parent = zeros(Int, length(X))
    tree_generator = zeros(Int, length(X))
    queue = Int[]
    for root in eachindex(X)
        iszero(representative_of[root]) || continue
        push!(representatives, root)
        representative_of[root] = root
        empty!(queue); push!(queue, root)
        cursor = 1
        while cursor <= length(queue)
            current = queue[cursor]; cursor += 1
            for (g, qcolumns) in enumerate(quotient_generators)
                child = index[_quadratic_coset_action(X[current], qcolumns)]
                iszero(representative_of[child]) || continue
                representative_of[child] = root
                tree_parent[child] = current
                tree_generator[child] = g
                push!(queue, child)
            end
        end
    end
    return QuadraticExtensionOrbitPlan(G.n, R, mask, X, checked_generators,
        representatives, representative_of, tree_parent, tree_generator)
end

"""
    quadratic_extension_orbit_witness(plan, index) -> Vector{UInt16}

Input-map columns taking the representative coset of `index` to that original
coset modulo `V`. Composes the verified BFS-tree generators in pullback order;
the result can be replayed independently on both the base and output spaces.
"""
function quadratic_extension_orbit_witness(plan::QuadraticExtensionOrbitPlan, index::Int)
    checkbounds(plan.cosets, index)
    path = Int[]
    i = index
    while !iszero(plan.tree_parent[i])
        push!(path, plan.tree_generator[i])
        i = plan.tree_parent[i]
    end
    columns = identity_linear_map(plan.n, UInt16).cols
    for g in reverse(path)
        previous = F2LinearMap{plan.n,UInt16}(columns)
        columns = UInt16[previous(c) for c in plan.generators[g]]
    end
    return columns
end

"""
    transport_quadratic_extension_orbit(G, plan, representative_index, Ss;
        capped=false)

Replay a representative coset's completion spaces into every original coset
of its orbit. Returns events containing `index`, `source_index`, `representative`,
`input_columns`, transported `Ss` and the unchanged `capped` flag. Every input
space must have dimension `n` and contain the base plus representative coset.
The returned events alone assert no enumeration completeness: a capped or
otherwise partial source enumeration remains partial under transport.
"""
function transport_quadratic_extension_orbit(G::QuadraticExtensions.Geometry,
        plan::QuadraticExtensionOrbitPlan, representative_index::Int, Ss;
        capped::Bool=false)
    G.n == plan.n || throw(ArgumentError("orbit-plan input dimension mismatch"))
    representative_index in plan.representatives ||
        throw(ArgumentError("source must be an orbit representative index"))
    R = plan.basis
    x = QuadraticExtensions.lift(plan.cosets[representative_index], plan.quotient_mask)
    U = first(QuadraticExtensions.rref(vcat(R, x)))
    sources = Vector{UInt32}[]
    for S in Ss
        basis = _quadratic_space_basis(G, S)
        length(basis) == G.n || throw(ArgumentError("completion space must have dimension n"))
        first(QuadraticExtensions.rref(vcat(basis, U))) == basis ||
            throw(ArgumentError("completion space does not contain its source coset"))
        push!(sources, basis)
    end
    events = NamedTuple[]
    for index in eachindex(plan.cosets)
        plan.representative_of[index] == representative_index || continue
        columns = quadratic_extension_orbit_witness(plan, index)
        verify_quadratic_space_transporter(G, R, R, columns) ||
            error("orbit witness failed base-space replay")
        target = QuadraticExtensions.lift(plan.cosets[index], plan.quotient_mask)
        verify_quadratic_space_transporter(G, U,
            first(QuadraticExtensions.rref(vcat(R, target))), columns) ||
            error("orbit witness failed source-to-target coset replay")
        transported = Set{Vector{UInt32}}(
            transform_quadratic_space(G, S, columns) for S in sources)
        push!(events, (; index, source_index=representative_index,
            representative=target, input_columns=columns, Ss=transported, capped))
    end
    return events
end

"""
    v5_extensions_by_symmetry(G, V5, need, work; beta, generators,
        du_filter=true, max_kernel=12, should_stop=()->false,
        coset_observer=nothing)

Opt-in V5 enumeration using certified input-stabilizer orbits of eligible
six-space cosets. Executes the original search only for orbit representatives
and reconstructs *all* original coefficient-space outputs and per-coset events
with explicit input-map witnesses. The default `v5_extensions` path is unchanged.

For a nonempty generator list, an extra bent-count transform builds the orbit
plan; an empty list uses the original engine once. Generator discovery is
separate and never implicit. `nX_searched`, `ncand`, `nT`, and `du_reject` count
actual representative work, while `nX_covered` counts original cosets with
uncapped transported enumeration. Only `complete=true` certifies all eligible
cosets covered. A stopped or kernel-capped source cannot certify its orbit.

Observers receive original logical `index`, lifted `representative`, `Ss`,
`capped`, `source_index`, `input_columns`, and `replayed`. Replayed events have
zero `ncand`/`nT` since no search was executed there. Events are emitted in
original index order after replay; this wrapper has no resumable cursor API.
"""
function v5_extensions_by_symmetry(G::QuadraticExtensions.Geometry,
        V5::AbstractVector{UInt32}, need::Int, work::QuadraticExtensions.V5Work;
        beta::Vector{Int}, generators::AbstractVector, du_filter::Bool=true,
        max_kernel::Int=12, should_stop::Function=()->false, coset_observer=nothing)
    R = _quadratic_space_basis(G, V5)
    length(R) == G.n-3 || throw(ArgumentError("V5 must have dimension n-3"))
    should_stop() && return (; Ss=Set{Vector{UInt32}}(), nX=nothing,
        nX_searched=0, nX_covered=0, n_orbits=nothing, complete=false,
        capped=false, du_reject=0, ncand=0, nT=0, key=nothing, plan=nothing)
    if isempty(generators)
        # The common trivial-stabilizer case requires neither a second FWHT
        # nor replay of thousands of identity transports. No work is skipped.
        nX_covered = 0
        events = NamedTuple[]
        identity = identity_linear_map(G.n, UInt16).cols
        observer = function (event)
            !event.capped && (nX_covered += 1)
            coset_observer === nothing && return
            push!(events, merge(event, (; source_index=event.index,
                input_columns=copy(identity), replayed=false,
                coverage_complete=!event.capped, next_x=nothing)))
        end
        result = QuadraticExtensions.v5_extensions(G, R, need, work;
            beta, du_filter, max_kernel, should_stop, coset_observer=observer)
        scale = (1 << (G.N-length(R))) ÷ gcd(beta)
        X = UInt32[i-1 for i in 2:length(work.cnt) if work.cnt[i] == need*scale]
        plan = quadratic_extension_orbits(G, R, X, generators)
        coset_observer === nothing || foreach(coset_observer, events)
        return (; Ss=result.Ss, nX=result.nX, nX_searched=result.nX_used,
            nX_covered, n_orbits=result.nX, complete=nX_covered==result.nX,
            capped=result.capped, du_reject=result.du_reject, ncand=result.ncand,
            nT=result.nT, key=result.key, plan)
    end
    counts = QuadraticExtensions.coset_bent_counts!(work.cnt, G, R, beta)
    X = UInt32[i-1 for i in 2:length(work.cnt) if work.cnt[i] == need*counts.scale]
    plan = quadratic_extension_orbits(G, R, X, generators)
    source_events = Dict{Int,Any}()
    result = QuadraticExtensions.v5_extensions(G, R, need, work; beta, du_filter,
        max_kernel, should_stop, selected_coset_indices=plan.representatives,
        coset_observer=event->(source_events[event.index]=event))
    events = NamedTuple[]
    Ss = Set{Vector{UInt32}}()
    covered = falses(length(X))
    for source_index in plan.representatives
        haskey(source_events, source_index) || continue
        source = source_events[source_index]
        for event in transport_quadratic_extension_orbit(G, plan, source_index, source.Ss;
                capped=source.capped)
            replayed = event.index != source_index
            union!(Ss, event.Ss)
            covered[event.index] = !event.capped
            push!(events, merge(event, (; replayed, coverage_complete=!event.capped,
                total_x=length(X), du_reject=source.du_reject,
                ncand=replayed ? 0 : source.ncand, nT=replayed ? 0 : source.nT)))
        end
    end
    sort!(events; by=event->event.index)
    if coset_observer !== nothing
        foreach(coset_observer, events)
    end
    nX_covered = count(covered)
    return (; Ss, nX=length(X), nX_searched=result.nX_used, nX_covered,
        n_orbits=length(plan.representatives), complete=all(covered),
        capped=result.capped, du_reject=result.du_reject, ncand=result.ncand,
        nT=result.nT, key=result.key, plan)
end
