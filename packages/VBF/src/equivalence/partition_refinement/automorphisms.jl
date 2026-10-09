"""
    AutomorphismGroupResult

A verified subgroup of ambient CCZ or EA affine automorphisms. `generators`
generate the subgroup; they are not an enumeration of its elements. `complete`
certifies that it is the entire automorphism group. `stop_reason` is `:none`,
`:time`, `:nodes` or `:memory`. A stopped search still provides valid generators.

`graph_order` is the order of the induced graph action, `kernel_order` that of
the pointwise affine kernel, and `order` their product. An order is `nothing`
if its construction was interrupted. Orders are exact `BigInt` values.
"""
struct AutomorphismGroupResult{D}
    relation::Symbol
    generators::Vector{F2AffineMap{D,UInt32}}
    complete::Bool
    stop_reason::Symbol
    order::Union{Nothing,BigInt}
    graph_order::Union{Nothing,BigInt}
    kernel_order::Union{Nothing,BigInt}
    nodes_visited::Int
    elapsed_seconds::Float64
end

nodes_visited(H::AutomorphismGroupResult) = H.nodes_visited
elapsed_seconds(H::AutomorphismGroupResult) = H.elapsed_seconds

mutable struct _PRDiscovery{D}
    group::_PRPermutationGroup
    generators::Vector{F2AffineMap{D,UInt32}}
    epoch::Int
end

"""Algorithm 4: discover new graph actions and refresh ancestor stabilizers."""
function _pr_auto_dfs!(F::SBox{N}, points, planes, pl, pr, hl, hr, a, work,
                      floor, ea, budget, state, fixed, H, epoch) where {N}
    _pr_check!(budget) || return
    if budget.nodes >= budget.max_nodes
        budget.stopped = :nodes
        return
    end
    budget.nodes += 1
    _pr_refine!(pl, pr, hl, hr, points, points, planes, planes,
                work, floor, budget) || return
    oldfixed = length(fixed)
    choice = _pr_prepare_node!(pl, pr, points, points, a, work, N, ea, fixed)
    choice === nothing && return
    H = _pr_group_fix(H, view(fixed, (oldfixed+1):length(fixed)), budget)
    H === nothing && return
    cell, xindex = choice
    if cell == 0
        A = _pr_certificate(a, F, F, ea)
        A === nothing && return
        p = _pr_graph_permutation(F, A; ea)
        if _pr_group_add!(state.group, p, budget)
            push!(state.generators, A)
            state.epoch += 1
        end
        return
    end
    lo, hi = pr.starts[cell], pr.starts[cell+1] - 1
    touched = falses(length(points))
    labels = _pr_group_orbits(H, budget)
    labels === nothing && return
    while _pr_check!(budget)
        if epoch != state.epoch
            # New automorphisms may merge formerly distinct branch orbits.
            H = _pr_group_fix(state.group, fixed, budget)
            H === nothing && return
            labels = _pr_group_orbits(H, budget)
            labels === nothing && return
            epoch = state.epoch
        end
        covered = falses(length(points))
        for i in eachindex(touched)
            touched[i] && (covered[labels[i]] = true)
        end
        j = findfirst(k -> !covered[labels[pr.order[k]]], lo:hi)
        j === nothing && return
        yindex = pr.order[lo+j-1]
        touched[yindex] = true
        b = copy(a)
        _pr_insert!(b, points[xindex], points[yindex], N, ea) || continue
        child_group = _pr_group_stabilizer(H, yindex, budget)
        child_group === nothing && return
        ql, qr = copy(pl), copy(pr)
        _pr_individualize!(ql, cell, xindex)
        _pr_individualize!(qr, cell, yindex)
        child_fixed = copy(fixed); push!(child_fixed, yindex)
        _pr_auto_dfs!(F, points, planes, ql, qr, copy(hl), copy(hr), b,
            work, floor, ea, budget, state, child_fixed, child_group, epoch)
    end
    return
end

"""Conservative live stabilizer-chain allocation estimate, including DFS depth."""
_pr_group_memory(n::Int) = Int128(16) * (Int128(1) << (2n)) * (2n + 2)^2

"""
    partition_refinement_automorphisms(F; relation=:ccz, max_nodes=10^6,
        timeout_seconds=60.0, min_active_hyperplanes=0,
        max_memory_bytes=512*1024^2, threaded=false) -> AutomorphismGroupResult

Discover a generating set for the full ambient CCZ or EA automorphism group
using Kaleyski–Sunde Algorithms 4–5 (ePrint 2026/940). Dynamic stabilizer orbits
prune the search. Quadratic translations seed the graph action. Lemma 13's
pointwise kernel supplies the affine lift, including rank-deficient graphs.

`complete=true` is a completeness certificate. A node/time/memory interruption
returns a verified subgroup with `complete=false`; it is still safe to supply
as `automorphisms` to [`partition_refinement_equivalence`](@ref). Memory bounds
include live stabilizer chains and use the same estimated-allocation convention
as the equivalence search. Schreier–Sims stores permutations of 2^n graph
points, never 2^(2n) ambient points.
`threaded=true` parallelizes only sufficiently large refinement kernels; group
updates and DFS are serial. Threads do not alter completeness or node budgets.
"""
function partition_refinement_automorphisms(F::SBox{N}; relation::Symbol = :ccz,
    max_nodes::Int = 10^6, timeout_seconds::Real = 60.0,
    min_active_hyperplanes::Int = 0, max_memory_bytes::Int = 512 * 1024^2,
    threaded::Bool = false,
) where {N}
    relation in (:ccz, :ea) || throw(ArgumentError("relation must be :ccz or :ea"))
    max_nodes >= 0 || throw(ArgumentError("max_nodes must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    min_active_hyperplanes >= 0 || throw(ArgumentError("min_active_hyperplanes must be nonnegative"))
    max_memory_bytes >= 0 || throw(ArgumentError("max_memory_bytes must be nonnegative"))
    start = time_ns()
    budget = _PRBudget(start, Float64(timeout_seconds), max_nodes, 0, :none)
    state = _PRDiscovery(_PRPermutationGroup(length(F)), F2AffineMap{2N,UInt32}[], 0)
    kernel_order = nothing
    finish = function ()
        graph_order = _pr_group_order(state.group)
        order = graph_order === nothing || kernel_order === nothing ? nothing : graph_order * kernel_order
        return AutomorphismGroupResult{2N}(relation, state.generators,
            budget.stopped === :none, budget.stopped, order, graph_order, kernel_order,
            budget.nodes, (time_ns() - start) * 1e-9)
    end
    _pr_check!(budget) || return finish()
    if max_nodes == 0
        budget.stopped = :nodes
        return finish()
    end
    if (Int128(16) << (2N)) + _pr_group_memory(N) > max_memory_bytes
        budget.stopped = :memory
        return finish()
    end
    points = FunctionGraph(F).packed
    kernel, kernel_order = _pr_affine_kernel(F, points, relation === :ea, budget)
    append!(state.generators, kernel)
    _pr_check!(budget) || return finish()
    if algebraic_degree(F) <= 2
        for A in _pr_quadratic_translations(F)
            _pr_check!(budget) || return finish()
            p = _pr_graph_permutation(F, A; ea = relation === :ea)
            if _pr_group_add!(state.group, p, budget)
                push!(state.generators, A); state.epoch += 1
            end
        end
    end
    spectrum = _pr_graph_walsh(points, 2N; threaded)
    _pr_check!(budget) || return finish()
    histogram = _pr_intersection_histogram(spectrum, length(points))
    floor = min_active_hyperplanes == 0 ? (N <= 7 ? 16 : 2) * length(points) : min_active_hyperplanes
    classes, nplanes = _pr_select_classes(histogram, floor)
    estimate = (Int128(16) << (2N)) + _pr_group_memory(N) +
        Int128(nplanes + length(points)) * (64 + 32 * (2N + 2))
    if estimate > max_memory_bytes
        budget.stopped = :memory
        return finish()
    end
    planes, hl = _pr_build_planes(spectrum, length(points), classes, histogram)
    pl, pr = _PRPartition(length(points)), _PRPartition(length(points))
    a, fixed = _PRAffineMap(N), Int[]
    if algebraic_degree(F) <= 2
        _pr_insert!(a, first(points), first(points), N, relation === :ea)
        push!(fixed, 1)
        _pr_individualize!(pl, 1, 1); _pr_individualize!(pr, 1, 1)
    end
    H = _pr_group_fix(state.group, fixed, budget)
    H === nothing && return finish()
    _pr_auto_dfs!(F, points, planes, pl, pr, hl, copy(hl), a,
        _PRWorkspace(2N, length(points), nplanes; threaded), floor, relation === :ea,
        budget, state, fixed, H, state.epoch)
    return finish()
end

"""Validate all ambient generators before trusting any graph-action pruning."""
function _pr_checked_automorphisms(G, automorphisms, ea, budget)
    H = _PRPermutationGroup(length(G))
    generators = automorphisms isa AutomorphismGroupResult ? automorphisms.generators : automorphisms
    for A in generators
        _pr_check!(budget) || return nothing
        A isa F2AffineMap || throw(ArgumentError("automorphisms must contain affine maps"))
        _pr_group_add!(H, _pr_graph_permutation(G, A; ea), budget)
        budget.stopped === :none || return nothing
    end
    return H
end
