"""
Compact ordered partitions for Kaleyski–Sunde refinement (ePrint 2026/940,
Sections 3–4). Cell order is part of the invariant, unlike `EAPartition`'s
multiplicity buckets. Elements are storage indices, not packed graph points.
"""

"""An ordered partition stored in one contiguous element array."""
mutable struct _PRPartition
    order::Vector{Int}
    starts::Vector{Int}
end

"""Construct a single-cell partition of `1:n`."""
_PRPartition(n::Int) = _PRPartition(collect(1:n), [1, n + 1])
Base.copy(p::_PRPartition) = _PRPartition(copy(p.order), copy(p.starts))

"""Split paired cells by signed signatures and reject unequal histograms."""
function _pr_split_pair!(a::_PRPartition, b::_PRPartition, sa, sb)
    a.starts == b.starts || return false
    starts = nothing
    @inbounds for c = 1:(length(a.starts)-1)
        lo, hi = a.starts[c], a.starts[c+1] - 1
        score = sa[a.order[lo]]
        if all(j -> sa[a.order[j]] == score, lo:hi)
            # Uniform cells (including singletons) need neither sorting nor
            # replacement boundaries. This also rejects a nonuniform mate.
            all(j -> sb[b.order[j]] == score, lo:hi) || return false
            starts === nothing || push!(starts, hi + 1)
            continue
        end
        if starts === nothing
            starts = a.starts[1:c]
        end
        sort!(view(a.order, lo:hi); by = i -> sa[i])
        sort!(view(b.order, lo:hi); by = i -> sb[i])
        for j = lo:hi
            sa[a.order[j]] == sb[b.order[j]] || return false
            if j > lo && sa[a.order[j]] != sa[a.order[j-1]]
                push!(starts, j)
            end
        end
        push!(starts, hi + 1)
    end
    if starts !== nothing
        a.starts = starts
        b.starts = copy(starts)
    end
    return true
end

"""Individualize an element in a known cell, preserving the other cell order."""
function _pr_individualize!(p::_PRPartition, c::Int, element::Int)
    lo, hi = p.starts[c], p.starts[c+1] - 1
    @inbounds for j = lo:hi
        if p.order[j] == element
            p.order[lo], p.order[j] = p.order[j], p.order[lo]
            hi > lo && insert!(p.starts, c + 1, lo + 1)
            return p
        end
    end
    error("element does not belong to the selected partition cell")
end

"""Retain corresponding smallest whole hyperplane cells, up to a floor."""
function _pr_trim_pair!(a::_PRPartition, b::_PRPartition, floor::Int; preserve_order::Bool = true)
    preserve_order && length(a.order) <= floor && return
    cells = collect(1:(length(a.starts)-1))
    sort!(cells; by = c -> (a.starts[c+1] - a.starts[c], c))
    total, nkeep = 0, 0
    for c in cells
        total += a.starts[c+1] - a.starts[c]
        nkeep += 1
        total >= floor && break
    end
    resize!(cells, nkeep)
    preserve_order && sort!(cells)
    oa, ob, starts = Int[], Int[], Int[1]
    sizehint!(oa, total)
    sizehint!(ob, total)
    for c in cells
        append!(oa, view(a.order, a.starts[c]:(a.starts[c+1]-1)))
        append!(ob, view(b.order, b.starts[c]:(b.starts[c+1]-1)))
        push!(starts, length(oa) + 1)
    end
    a.order, a.starts = oa, starts
    b.order, b.starts = ob, copy(starts)
    return nothing
end

"""
Deterministic bounded cell weights, shared by both sides. Collisions only weaken
refinement: witnesses are verified and negative answers exhaust the affine search.
"""
@inline function _pr_cell_weight(c::Int, ncells::Int)
    x = UInt32(c) ⊻ (UInt32(ncells) * UInt32(0x85ebca6b))
    x ⊻= x >> 16
    x *= UInt32(0x7feb352d)
    x ⊻= x >> 15
    x *= UInt32(0x846ca68b)
    x ⊻= x >> 16
    return Int(x % UInt32(8191)) + 1
end
