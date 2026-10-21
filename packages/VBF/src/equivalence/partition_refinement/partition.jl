"""
Compact ordered partitions for Kaleyski–Sunde refinement (ePrint 2026/940,
Sections 3–4). Cell order is part of the invariant, unlike `EAPartition`'s
multiplicity buckets. Elements are storage indices, not packed graph points.
"""

"""An ordered partition stored in one contiguous element array."""
mutable struct _PRPartition{I<:Signed}
    order::Vector{I}
    starts::Vector{Int}
    function _PRPartition{I}(order,starts) where {I<:Signed}
        new{I}(convert(Vector{I},order),convert(Vector{Int},starts))
    end
end

_PRPartition(order,starts)=_PRPartition{Int}(order,starts)

"""Construct a single-cell partition of `1:n`."""
_PRPartition(n::Int) = _PRPartition(collect(1:n), [1, n + 1])
Base.copy(p::_PRPartition{I}) where {I} = _PRPartition{I}(copy(p.order), copy(p.starts))

"""Choose compact native indices only when the whole positive domain fits."""
_pr_partition_index_type(n::Int)=n<=typemax(Int32) ? Int32 : Int

"""Build a native partition without changing the historical private constructors."""
function _pr_native_partition(n::Int,starts::Vector{Int}=[1,n+1])
    I=_pr_partition_index_type(n)
    _PRPartition{I}(collect(I(1):I(n)),starts)
end

"""Monotone unsigned encoding of an exact signed refinement score."""
@inline _pr_score_key(score::Int)=reinterpret(UInt,score)⊻(one(UInt)<<(8sizeof(Int)-1))

"""Stably sort a large cell using reusable byte histograms and index scratch."""
function _pr_radix_cell!(order,scores,lo,hi,work)
    n=hi-lo+1
    n<=1 && return
    @inbounds low=high=_pr_score_key(scores[order[lo]])
    @inbounds for j in lo+1:hi
        key=_pr_score_key(scores[order[j]])
        low=min(low,key);high=max(high,key)
    end
    span=high-low
    span==0 && return
    length(work.sort_order)>=n || resize!(work.sort_order,n)
    length(work.sort_counts)==256 || resize!(work.sort_counts,256)
    shift=0
    while span!=0
        fill!(work.sort_counts,0)
        @inbounds for j in lo:hi
            key=_pr_score_key(scores[order[j]])-low
            bucket=Int((key>>shift)&0xff)+1
            work.sort_counts[bucket]+=1
        end
        offset=1
        @inbounds for bucket in 1:256
            count=work.sort_counts[bucket]
            work.sort_counts[bucket]=offset
            offset+=count
        end
        @inbounds for j in lo:hi
            index=order[j];key=_pr_score_key(scores[index])-low
            bucket=Int((key>>shift)&0xff)+1
            work.sort_order[work.sort_counts[bucket]]=index
            work.sort_counts[bucket]+=1
        end
        copyto!(order,lo,work.sort_order,1,n)
        span>>=8;shift+=8
    end
    nothing
end

"""Keep the comparison-sort path for small cells or callers without scratch."""
@inline function _pr_sort_cell!(order,scores,lo,hi,work)
    if work!==nothing && scores isa AbstractVector{Int} && hi-lo+1>=256
        _pr_radix_cell!(order,scores,lo,hi,work)
    else
        sort!(view(order,lo:hi);by=i->scores[i])
    end
    nothing
end

"""Split paired cells by signed signatures and reject unequal histograms."""
function _pr_split_pair!(a::_PRPartition, b::_PRPartition, sa, sb,work=nothing)
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
        _pr_sort_cell!(a.order,sa,lo,hi,work)
        _pr_sort_cell!(b.order,sb,lo,hi,work)
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

"""
Retain corresponding smallest whole hyperplane cells, up to a floor.
If fewer hyperplanes are available, retain all cells. Algorithm 3's printed
while-loop omits this boundary; iterating over existing cells supplies it.
"""
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
    oa, ob, starts = empty(a.order), empty(b.order), Int[1]
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
