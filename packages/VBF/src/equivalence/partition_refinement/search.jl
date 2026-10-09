"""
Native Kaleyski–Sunde CCZ/EA recovery by affine partition refinement.

Algorithms 3, 6 and 7 of Nikolay Kaleyski and Joakim Sunde, *Efficiently
deciding and recovering CCZ and EA equivalence for arbitrary vectorial Boolean
functions using the partition refinement framework*, ePrint 2026/940 (2026),
https://eprint.iacr.org/2026/940. Reference implementation:
https://github.com/zskiley/CCZ-EA-equivalence.

This Julia implementation uses VBF's packing `(x << m) | F(x)` throughout.
Consequently the EA output subspace occupies the **low** m bits. Signed
signatures implement the paper's incidence refinement with shared random cell
weights in the default paper profile. Hyperplanes only prune; every witness is
checked against the full graph.
"""

"""Search-local deadline and node count, including preprocessing time."""
mutable struct _PRBudget
    start::UInt64
    timeout::Float64
    max_nodes::Int
    nodes::Int
    stopped::Symbol
end

"""Check a search deadline without conflating interruption with exhaustion."""
function _pr_check!(b::_PRBudget)
    b.stopped === :none || return false
    if (time_ns() - b.start) * 1e-9 >= b.timeout
        b.stopped = :time
        return false
    end
    return true
end

"""An affine anchor and injective partial maps on the ambient space and quotient."""
mutable struct _PRAffineMap
    linear::_PartialF2Isomorphism
    quotient::_PartialF2Isomorphism
    anchored::Bool
    source::UInt32
    target::UInt32
end

"""Construct empty affine constraints in VBF's input-high/output-low convention."""
_PRAffineMap(n::Int, m::Int = n) = _PRAffineMap(
    _PartialF2Isomorphism(n+m), _PartialF2Isomorphism(n), false, UInt32(0), UInt32(0),
)
Base.copy(a::_PRAffineMap) = _PRAffineMap(
    copy(a.linear), copy(a.quotient), a.anchored, a.source, a.target,
)

"""Evaluate the determined portion of an affine map."""
@inline function _pr_image(a::_PRAffineMap, x::UInt32)
    a.anchored || return nothing
    y = _partial_image(a.linear, x ⊻ a.source)
    return y === nothing ? nothing : y ⊻ a.target
end

"""
Propagate a point correspondence. EA mode also propagates the input quotient;
this tests every relation in the intersection with the output subspace, including
relations that involve several output basis vectors.
"""
function _pr_insert!(a::_PRAffineMap, x::UInt32, y::UInt32, n::Int, ea::Bool)
    if !a.anchored
        a.anchored, a.source, a.target = true, x, y
        return true
    end
    dx, dy = x ⊻ a.source, y ⊻ a.target
    _partial_insert!(a.linear, dx, dy) || return false
    return !ea || _partial_insert!(a.quotient, dx >> n, dy >> n)
end

"""Run paired point/hyperplane refinement to a fixpoint (Algorithm 3)."""
function _pr_refine!(pl, pr, hl, hr, left, right, planes_left, planes_right,
                     work, floor, budget)
    while _pr_check!(budget)
        before = length(pl.starts) + length(hl.starts)
        keys = work.algorithm === :paper ? rand(work.rng,1:8191,length(hl.starts)-1) : nothing
        _pr_point_scores!(work.point_left, left, planes_left, hl, work;keys)
        _pr_point_scores!(work.point_right, right, planes_right, hr, work;keys)
        _pr_split_pair!(pl, pr, work.point_left, work.point_right) || return false
        work.trace === nothing || work.trace(:points,pl,pr,hl,hr)
        _pr_check!(budget) || return false
        keys = work.algorithm === :paper ? rand(work.rng,1:8191,length(pl.starts)-1) : nothing
        _pr_plane_scores!(work.plane_left, left, pl, planes_left, hl, work;keys)
        _pr_plane_scores!(work.plane_right, right, pr, planes_right, hr, work;keys)
        _pr_split_pair!(hl, hr, work.plane_left, work.plane_right) || return false
        work.trace === nothing || work.trace(:hyperplanes,pl,pr,hl,hr)
        if before == length(pl.starts) + length(hl.starts)
            _pr_trim_pair!(hl, hr, floor;preserve_order=work.algorithm!==:paper)
            work.trace === nothing || work.trace(:trim,pl,pr,hl,hr)
            return true
        end
    end
    return false
end

"""Extend affine constraints and independently verify a full graph certificate."""
function _pr_certificate(a::_PRAffineMap, F::AbstractTruthTable{N,M}, G::AbstractTruthTable, ea::Bool) where {N,M}
    if ea
        # ValidEA must establish a well-defined, injective input quotient before
        # completing the ambient map; the paper performs this check at leaves.
        quotient = _PartialF2Isomorphism(N)
        for p in FunctionGraph(F).packed
            y = _pr_image(a,p)
            y === nothing && return nothing
            _partial_insert!(quotient,(p ⊻ a.source) >> M,(y ⊻ a.target) >> M) || return nothing
        end
    end
    L = _partial_complete(a.linear; output_bits = ea ? M : 0)
    L === nothing && return nothing
    A = F2AffineMap(L, a.target ⊻ L(a.source))
    is_invertible(L) || return nothing
    if ea
        all(v -> v >> M == 0, view(L.cols, 1:M)) || return nothing
    end
    mapped = ccz_equivalent_function(F, A)
    return mapped !== nothing && mapped.lut == G.lut ? A : nothing
end

"""Propagate singleton constraints and choose the next undetermined graph point."""
function _pr_prepare_node!(pl, pr, left, right, a, work, M, ea, fixed)
    @inbounds for c = 1:(length(pl.starts)-1)
        lo = pl.starts[c]
        if pl.starts[c+1] == lo + 1
            x, y = left[pl.order[lo]], right[pr.order[lo]]
            fresh = _pr_image(a, x) === nothing
            _pr_insert!(a, x, y, M, ea && work.algorithm!==:paper) || return nothing
            fresh && push!(fixed, pr.order[lo])
        end
    end
    @inbounds for c = 1:(length(pr.starts)-1)
        for j = pr.starts[c]:(pr.starts[c+1]-1)
            work.point_cells[pr.order[j]] = c
        end
    end
    cell, size, xindex = 0, typemax(Int), 0
    @inbounds for c = 1:(length(pl.starts)-1)
        lo, hi = pl.starts[c], pl.starts[c+1] - 1
        for j = lo:hi
            i = pl.order[j]
            y = _pr_image(a, left[i])
            if y === nothing
                # Algorithms 4/6 print >1 free points. A quadratic anchor is
                # not individualized in Algorithm 5: its cell can have just
                # one free point. Section 3 and Lemma 16 require >0 here.
                if hi - lo + 1 < size
                    cell, size, xindex = c, hi - lo + 1, i
                end
            elseif work.algorithm !== :paper
                # An affine implication must land in the corresponding target cell.
                # Graph points are indexed by input, so membership is O(1).
                target_index = Int(y >> M) + 1
                right[target_index] == y && work.point_cells[target_index] == c ||
                    return nothing
            end
        end
    end
    return cell, xindex
end

"""Depth-first affine recovery with paired partitions (Algorithm 6)."""
function _pr_dfs!(F::AbstractTruthTable{N,M}, G, left, right, planes_left, planes_right, pl, pr,
                  hl, hr, a, work, floor, ea, budget, transitive, H = nothing) where {N,M}
    _pr_check!(budget) || return nothing
    if budget.nodes >= budget.max_nodes
        budget.stopped = :nodes
        return nothing
    end
    budget.nodes += 1
    _pr_refine!(pl, pr, hl, hr, left, right, planes_left, planes_right,
                work, floor, budget) || return nothing
    fixed = Int[]
    choice = _pr_prepare_node!(pl, pr, left, right, a, work, M, ea, fixed)
    choice === nothing && return nothing
    cell, xindex = choice
    cell == 0 && return _pr_certificate(a, F, G, ea)
    if H !== nothing
        H = _pr_group_fix(H, fixed, budget)
        H === nothing && return nothing
    end
    labels = H === nothing || isempty(H.strong) ? nothing : _pr_group_orbits(H, budget)
    budget.stopped === :none || return nothing
    seen = labels === nothing ? nothing : falses(length(right))
    lo, hi = pr.starts[cell], pr.starts[cell+1] - 1
    # Quadratic graphs have known translations acting transitively (paper
    # Section 6.1). At the unanchored root all image choices are equivalent.
    transitive && !a.anchored && (hi = lo)
    for j = lo:hi
        _pr_check!(budget) || return nothing
        yindex = pr.order[j]
        if labels !== nothing
            orbit = labels[yindex]
            seen[orbit] && continue
            seen[orbit] = true
        end
        b = copy(a)
        _pr_insert!(b, left[xindex], right[yindex], M, ea && work.algorithm!==:paper) || continue
        child_group = H === nothing ? nothing : _pr_group_stabilizer(H, yindex, budget)
        H !== nothing && child_group === nothing && return nothing
        ql, qr = copy(pl), copy(pr)
        _pr_individualize!(ql, cell, xindex)
        _pr_individualize!(qr, cell, yindex)
        cert = _pr_dfs!(F, G, left, right, planes_left, planes_right, ql, qr,
                        copy(hl), copy(hr), b, work, floor, ea, budget, transitive, child_group)
        cert === nothing || return cert
        budget.stopped === :none || return nothing
    end
    return nothing
end

"""
    partition_refinement_equivalence(F, G; relation=:ccz, max_nodes=10^6,
        timeout_seconds=60.0, min_active_hyperplanes=0,
        max_memory_bytes=512*1024^2, automorphisms=nothing,
        automorphism_timeout_seconds=0.0, threaded=false,
        algorithm=:paper, rng=Xoshiro(940)) -> SearchOutcome{F2AffineMap}

Kaleyski–Sunde (2026), Algorithms 1–3, 6–7: recover a CCZ or EA affine map
**from F's graph to G's graph** for square SBoxes or rectangular VBFTable objects. `relation` is
`:ccz` or `:ea`. `Found` contains one verified invertible `F2AffineMap`;
`Exhausted` with no witnesses proves inequivalence; `BudgetHit` proves nothing.

The deadline covers preprocessing and DFS. A conservative memory estimate bounds
the transform buffers, hyperplanes and live partition copies before allocating
them; it is not a process RSS limit. `min_active_hyperplanes` is a refinement
floor, not a correctness limit: whole cells are retained and may exceed it.
If fewer hyperplanes are available than requested, all are retained.
Zero selects `16*2^n` for n ≤ 7 and `2*2^n` otherwise. The search is complete
when allowed to exhaust, but its worst-case tree is exponential. Storage is
O(2^(n+m)) for the transform, so larger dimensions may hit the memory budget.

`automorphisms` accepts a verified [`AutomorphismGroupResult`](@ref) or an
iterable of target-graph affine automorphisms. Every map is revalidated; EA
pruning also requires output-subspace preservation. Stabilizers branch on
one target per orbit (Lemma 12). A positive `automorphism_timeout_seconds`
uses bounded discovery on both functions in the paper profile (Section 6.2);
source-group selection reverses the internal search and inverts the witness
back to F → G. Supplied generators retain the target orientation. Discovery
and chain construction share the overall deadline, memory estimate and DFS-node
budget. Discovery is opt-in so easy instances do not pay for a group computation.
`threaded=true` uses independent parallel incidence sums and large Walsh
transforms when Julia has multiple default-pool threads. DFS and group updates
remain serial, and integer signatures, search order and node limits are unchanged.

Credits: Nikolay Kaleyski and Joakim Sunde, ePrint 2026/940,
https://eprint.iacr.org/2026/940. No sboxU, Sage or C++ runtime is required.

`algorithm=:paper` uses fresh shared random keys and the ordered partitions
prescribed in Algorithms 3, 5 and 7. Supply a fresh seeded `rng` to replay a
query. `algorithm=:optimized` preserves the earlier deterministic weights,
canonical cell order and quadratic root symmetry explicitly.
"""
function partition_refinement_equivalence(
    F::AbstractTruthTable{N,M}, G::AbstractTruthTable; relation::Symbol = :ccz, max_nodes::Int = 10^6,
    timeout_seconds::Real = 60.0, min_active_hyperplanes::Int = 0,
    max_memory_bytes::Int = 512 * 1024^2,
    automorphisms = nothing, automorphism_timeout_seconds::Real = 0.0,
    threaded::Bool = false,
    algorithm::Symbol = :paper, rng::AbstractRNG = Xoshiro(940),
) where {N,M}
    N+M <= 32 || throw(ArgumentError("native graph dimension n+m must fit UInt32"))
    algorithm in (:paper,:optimized) || throw(ArgumentError("algorithm must be :paper or :optimized"))
    relation in (:ccz, :ea) || throw(ArgumentError("relation must be :ccz or :ea"))
    max_nodes >= 0 || throw(ArgumentError("max_nodes must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    min_active_hyperplanes >= 0 || throw(ArgumentError("min_active_hyperplanes must be nonnegative"))
    max_memory_bytes >= 0 || throw(ArgumentError("max_memory_bytes must be nonnegative"))
    automorphism_timeout_seconds >= 0 || throw(ArgumentError("automorphism_timeout_seconds must be nonnegative"))
    start = time_ns()
    budget = _PRBudget(start, Float64(timeout_seconds), max_nodes, 0, :none)
    region = SearchRegion(:equivalence, "$(relation):$(N)-input/$(M)-output graphs";
        params=Dict{String,Any}("algorithm"=>algorithm,"orientation"=>:forward,
            "source_discovery_nodes"=>0,"target_discovery_nodes"=>0))
    witnesses = F2AffineMap{(N+M),UInt32}[]
    reversed = false
    finish = function (cert)
        elapsed = (time_ns() - start) * 1e-9
        if cert !== nothing && reversed
            inverse = inv(cert.linear)
            cert = F2AffineMap(inverse,inverse(cert.constant))
        end
        cert === nothing || push!(witnesses, cert)
        if cert !== nothing
            return Found(witnesses, region; nodes_visited = budget.nodes, elapsed_seconds = elapsed)
        elseif budget.stopped !== :none
            return BudgetHit(StopPoint(budget.stopped), region, witnesses;
                             nodes_visited = budget.nodes, elapsed_seconds = elapsed)
        end
        return Exhausted(region, witnesses; nodes_visited = budget.nodes, elapsed_seconds = elapsed)
    end
    inputbits(G) == N && outputbits(G) == M || return finish(nothing)
    _pr_check!(budget) || return finish(nothing)
    if max_nodes == 0
        budget.stopped = :nodes
        return finish(nothing)
    end
    # Check before any ambient-sized allocation, including the indicator FWHT.
    groups = automorphisms !== nothing || automorphism_timeout_seconds > 0
    group_memory = groups ? _pr_group_memory(N,M) : Int128(0)
    if (Int128(16) << ((N+M))) + group_memory > max_memory_bytes
        budget.stopped = :memory
        return finish(nothing)
    end
    left, right = FunctionGraph(F).packed, FunctionGraph(G).packed
    wf = _pr_graph_walsh(left, (N+M); threaded)
    _pr_check!(budget) || return finish(nothing)
    hf = _pr_intersection_histogram(wf, length(left))
    wg = _pr_graph_walsh(right, (N+M); threaded)
    _pr_check!(budget) || return finish(nothing)
    hg = _pr_intersection_histogram(wg, length(right))
    hf == hg || return finish(nothing)
    floor = min_active_hyperplanes == 0 ? (N <= 7 ? 16 : 2) * length(left) : min_active_hyperplanes
    classes, nplanes = _pr_select_classes(hf, floor;preserve_order=algorithm!==:paper)
    estimate = (Int128(16) << ((N+M))) + Int128(nplanes + length(left)) * (64 + 32 * ((N+M) + 2))
    estimate += group_memory
    if estimate > max_memory_bytes
        budget.stopped = :memory
        return finish(nothing)
    end
    if automorphism_timeout_seconds > 0
        remaining = max(0.0, budget.timeout - (time_ns() - start) * 1e-9)
        discovered = partition_refinement_automorphisms(G; relation,
            timeout_seconds = min(Float64(automorphism_timeout_seconds), remaining),
            max_nodes, min_active_hyperplanes, max_memory_bytes, threaded, algorithm, rng)
        budget.nodes += discovered.nodes_visited
        region.params["target_discovery_nodes"] = discovered.nodes_visited
        _pr_check!(budget) || return finish(nothing)
        if algorithm === :paper && automorphisms === nothing
            remaining = max(0.0,budget.timeout-(time_ns()-start)*1e-9)
            source_group = partition_refinement_automorphisms(F;relation,
                timeout_seconds=min(Float64(automorphism_timeout_seconds),remaining),
                max_nodes=max(0,max_nodes-budget.nodes),min_active_hyperplanes,
                max_memory_bytes,threaded,algorithm,rng)
            budget.nodes += source_group.nodes_visited
            region.params["source_discovery_nodes"] = source_group.nodes_visited
            _pr_check!(budget) || return finish(nothing)
            # Section 6.2 compares graph-action groups: the pointwise kernel
            # contributes no pruning. Prefer the source on exact-order ties.
            if source_group.graph_order !== nothing &&
                (discovered.graph_order === nothing || source_group.graph_order >= discovered.graph_order)
                F,G = G,F
                left,right = right,left
                wf,wg = wg,wf
                discovered = source_group
                reversed = true
                region.params["orientation"] = :reverse
            end
        end
        previous = automorphisms isa AutomorphismGroupResult ? automorphisms.generators : automorphisms
        automorphisms = previous === nothing ? discovered : vcat(collect(previous), discovered.generators)
        _pr_check!(budget) || return finish(nothing)
    end
    H = automorphisms === nothing ? nothing :
        _pr_checked_automorphisms(G, automorphisms, relation === :ea, budget)
    _pr_check!(budget) || return finish(nothing)
    planes_left, hl = _pr_build_planes(wf, length(left), classes, hf)
    planes_right, hr = _pr_build_planes(wg, length(right), classes, hg)
    work = _PRWorkspace((N+M), length(left), nplanes; threaded, algorithm, rng)
    pl, pr = _PRPartition(length(left)), _PRPartition(length(right))
    transitive = algorithm === :optimized && algebraic_degree(G) <= 2
    cert = _pr_dfs!(F, G, left, right, planes_left, planes_right, pl, pr, hl, hr,
                    _PRAffineMap(N,M), work, floor, relation === :ea, budget, transitive, H)
    return finish(cert)
end

"""Validate an equivalence API's uncertainty policy, including decided queries."""
function _pr_validate_policy(policy::Symbol)
    policy in (:throw, :missing, :best_effort) ||
        throw(ArgumentError("on_inconclusive must be :throw, :missing or :best_effort"))
    return nothing
end

"""Expose a verified witness while preserving a budget hit as uncertainty."""
function _pr_witness(result::SearchOutcome, policy::Symbol, caller::Symbol)
    _pr_validate_policy(policy)
    result isa Found && return only(search_solutions(result))
    result isa Exhausted && return nothing
    message = "$caller: partition refinement stopped at $(result.where_it_stopped.reason) " *
              "after $(nodes_visited(result)) nodes; equivalence is inconclusive."
    policy === :throw && throw(InconclusiveEquivalence(message))
    policy === :missing && return missing
    @warn message
    return nothing
end

"""Convert a certified search outcome into the existing predicate API."""
function _pr_decision(result::SearchOutcome, policy::Symbol, caller::Symbol)
    witness = _pr_witness(result, policy, caller)
    return ismissing(witness) ? missing : witness !== nothing
end

"""Convert an EA graph map to the existing outer/inner/drift certificate."""
function _pr_ea_triple(A::F2AffineMap{M}, ::Type{T}) where {M,T<:Unsigned}
    n = M ÷ 2
    mask = (UInt32(1) << n) - UInt32(1)
    B = F2LinearMap{n,T}(T[A.linear.cols[i] & mask for i = 1:n])
    L = F2LinearMap{n,T}(T[A.linear.cols[n+i] >> n for i = 1:n])
    C = F2LinearMap{n,T}(T[A.linear.cols[n+i] & mask for i = 1:n])
    inner_linear = inv(L)
    inner = F2AffineMap(inner_linear, inner_linear(A.constant >> n))
    drift = SBox{n,T}(T[C(inner(x)) ⊻ T(A.constant & mask) for x = 0:((1 << n)-1)])
    return (L1 = B, A2 = is_linear(inner) ? inner.linear : inner, A_drift = drift)
end
