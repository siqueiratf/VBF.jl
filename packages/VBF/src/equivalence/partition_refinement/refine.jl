"""
Weighted point/hyperplane refinement, Kaleyski–Sunde Algorithms 1–3 and 7.

For `H(a,c) = {p : dot(a,p) = c}`, graph intersection counts are
`(length(graph) + (-1)^c Walsh(graph_indicator)[a+1])/2`. Signed weighted
Walsh scores differ from incidence counts by a common offset and positive
scale, so they induce exactly the same ordered refinement (Lemmas 6 and 9).
No incidence graph is materialized. https://eprint.iacr.org/2026/940.
"""

"""Affine hyperplanes represented by a nonzero normal and a sign `(-1)^c`."""
struct _PRPlanes
    normals::Vector{UInt32}
    signs::Vector{Int8}
end

"""Reusable transform and signature buffers; owned by one search."""
struct _PRWorkspace{T<:Signed,R<:AbstractRNG}
    scratch::Vector{T}
    point_left::Vector{Int}
    point_right::Vector{Int}
    plane_left::Vector{Int}
    plane_right::Vector{Int}
    normals::Vector{UInt32}
    weights::Vector{Int}
    point_weights::Vector{Int}
    point_cells::Vector{Int}
    threaded::Bool
    direct_threshold::Int
    algorithm::Symbol
    rng::R
    trace::Any
    sort_order::Vector{Int}
    sort_counts::Vector{Int}
    native_direct::Bool
end

"""Retain private constructors and their full-width direct arithmetic."""
_PRWorkspace{T,R}(args::Vararg{Any,16}) where {T<:Signed,R<:AbstractRNG}=
    _PRWorkspace{T,R}(args...,false)

_PRWorkspace(s,a,b,c,d,e,f,g,h,t,k,algorithm,rng,trace,sort_order,sort_counts)=
    _PRWorkspace(s,a,b,c,d,e,f,g,h,t,k,algorithm,rng,trace,sort_order,sort_counts,false)

_PRWorkspace(s,a,b,c,d,e,f,g,h,t,k,algorithm,rng,trace)=
    _PRWorkspace(s,a,b,c,d,e,f,g,h,t,k,algorithm,rng,trace,Int[],Int[],false)

# Existing private kernel tests construct workspaces directly.
_PRWorkspace(s,a,b,c,d,e,f,g,h,t,k) = _PRWorkspace(s,a,b,c,d,e,f,g,h,t,k,:optimized,Xoshiro(940),nothing)

"""Allocate safe-width scratch space and choose the direct-summation crossover."""
function _PRWorkspace(d::Int, npoints::Int, nplanes::Int; threaded::Bool = false,
                      algorithm::Symbol = :optimized, rng::AbstractRNG = Xoshiro(940), trace=nothing,
                      native_direct::Bool = false)
    T = Int128(max(npoints, nplanes)) * 8191 <= typemax(Int32) ? Int32 : Int64
    return _PRWorkspace(
        zeros(T, 1 << d), zeros(Int, npoints), zeros(Int, npoints),
        zeros(Int, nplanes), zeros(Int, nplanes), zeros(UInt32, nplanes),
        zeros(Int, nplanes), zeros(Int, npoints), zeros(Int, npoints),
        threaded, (d * (1 << d)) ÷ npoints, algorithm, rng, trace,Int[],Int[],native_direct,
    )
end

"""Compute the graph indicator's Walsh transform using VBF's native FWHT."""
function _pr_graph_walsh(points::Vector{UInt32}, d::Int; threaded::Bool = false)
    T = length(points) <= typemax(Int32) ? Int32 : Int64
    v = zeros(T, 1 << d)
    @inbounds for p in points
        v[Int(p)+1] = 1
    end
    return walsh_hadamard!(v; threaded)
end

"""Exact signed incidence sum, shared by serial and threaded direct kernels."""
@inline function _pr_signed_sum(p, normals, weights, k)
    score = 0
    @inbounds @simd for j = 1:k
        w = weights[j]
        score += ifelse(isodd(count_ones(p & normals[j])), -w, w)
    end
    return score
end

"""Native bounded signatures with narrow SIMD lanes and the historical Int result.

Call only after `_pr_direct_weights!` establishes the weight and sum bounds.
"""
@inline function _pr_signed_sum32(p,normals,weights,k)
    score=Int32(0)
    @inbounds @simd for j in 1:k
        w=weights[j]
        score+=ifelse(isodd(count_ones(p & normals[j])),-w,w)
    end
    Int(score)
end

"""Sum checked Int32 weights once for a batch of signed incidence signatures."""
@inline function _pr_direct_weight_total32(weights,k)
    total=Int32(0)
    @inbounds @simd for j in 1:k
        total+=weights[j]
    end
    Int(total)
end

"""Reuse weights across two signatures and accumulate only odd incidences.

The checked native bound covers each subset sum. Convert before doubling so
the adjustment can exceed Int32 even when both final signatures fit Int32.
"""
@inline function _pr_signed_sum32_pair(p,q,normals,weights,k,total)
    a=Int32(0);b=Int32(0)
    @inbounds @simd for j in 1:k
        n=normals[j];w=weights[j]
        a+=ifelse(isodd(count_ones(p & n)),w,Int32(0))
        b+=ifelse(isodd(count_ones(q & n)),w,Int32(0))
    end
    (total-2Int(a),total-2Int(b))
end

"""Write one pair of point signatures, retaining the scalar kernel for a tail."""
@inline function _pr_point_score_pair32!(scores,points,normals,weights,k,total,pair)
    i=2pair-1
    @inbounds if i<length(points)
        a,b=_pr_signed_sum32_pair(points[i],points[i+1],normals,weights,k,total)
        scores[i]=a;scores[i+1]=b
    else
        scores[i]=_pr_signed_sum32(points[i],normals,weights,k)
    end
    nothing
end

"""Write one active hyperplane pair in its original order, including its signs."""
@inline function _pr_plane_score_pair32!(scores,points,planes,active,weights,total,pair)
    j=2pair-1
    @inbounds if j<length(active)
        i=active[j];l=active[j+1]
        a,b=_pr_signed_sum32_pair(planes.normals[i],planes.normals[l],points,weights,length(points),total)
        scores[i]=a*planes.signs[i];scores[l]=b*planes.signs[l]
    else
        i=active[j]
        scores[i]=_pr_signed_sum32(planes.normals[i],points,weights,length(points))*planes.signs[i]
    end
    nothing
end

"""Compute checked direct point signatures in adjacent output pairs."""
function _pr_direct_point_scores32!(scores,points,normals,weights,k)
    total=_pr_direct_weight_total32(weights,k)
    for pair in 1:cld(length(points),2)
        _pr_point_score_pair32!(scores,points,normals,weights,k,total,pair)
    end
    scores
end

"""Compute checked direct hyperplane signatures in adjacent active pairs."""
function _pr_direct_plane_scores32!(scores,points,planes,active,weights)
    total=_pr_direct_weight_total32(weights,length(points))
    for pair in 1:cld(length(active),2)
        _pr_plane_score_pair32!(scores,points,planes,active,weights,total,pair)
    end
    scores
end


"""Reuse transform scratch only for independently bounded native direct sums.

Private/custom-key workspaces retain full-width arithmetic by default. All
weights must satisfy the native bound, and the worst possible absolute sum
must fit Int32. Unsupported scratch widths, sizes and traced work fall back.
"""
_pr_direct_weights!(work,weights,k)=nothing
function _pr_direct_weights!(work::_PRWorkspace{Int32},weights,k)
    work.native_direct && work.trace===nothing || return nothing
    0<=k<=length(work.scratch) && k<=length(weights) && k<=fld(typemax(Int32),8191) || return nothing
    @inbounds for j in 1:k
        -8191<=weights[j]<=8191 || return nothing
    end
    @inbounds for j in 1:k
        work.scratch[j]=weights[j] % Int32
    end
    work.scratch
end

_pr_parallel_direct(work, points, planes) = work.threaded && Threads.nthreads() > 1 &&
    points * planes >= (1 << 19)

"""Isolate task captures from the caller's mutable signature-building counters."""
function _pr_parallel_point_scores!(scores, points, normals, weights, k)
    Threads.@threads :dynamic for i in eachindex(points)
        @inbounds scores[i] = _pr_signed_sum(points[i], normals, weights, k)
    end
    return scores
end

function _pr_parallel_plane_scores!(scores, points, planes, active, weights)
    Threads.@threads :dynamic for j in eachindex(active)
        @inbounds begin
            i = active[j]
            scores[i] = _pr_signed_sum(planes.normals[i], points,
                weights, length(points)) * planes.signs[i]
        end
    end
    return scores
end

function _pr_parallel_point_scores32!(scores,points,normals,weights,k)
    total=_pr_direct_weight_total32(weights,k)
    Threads.@threads :dynamic for pair in 1:cld(length(points),2)
        _pr_point_score_pair32!(scores,points,normals,weights,k,total,pair)
    end
    scores
end

function _pr_parallel_plane_scores32!(scores,points,planes,active,weights)
    total=_pr_direct_weight_total32(weights,length(points))
    Threads.@threads :dynamic for pair in 1:cld(length(active),2)
        _pr_plane_score_pair32!(scores,points,planes,active,weights,total,pair)
    end
    scores
end

"""Count all nonconstant affine hyperplanes by graph intersection size."""
function _pr_intersection_histogram(walsh, npoints::Int)
    counts = zeros(Int, npoints + 1)
    @inbounds for j = 2:length(walsh)
        counts[(npoints+Int(walsh[j]))÷2+1] += 1
        counts[(npoints-Int(walsh[j]))÷2+1] += 1
    end
    return counts
end

"""
Choose whole intersection classes in Algorithm 7's order (large absolute Walsh
values first, then small classes). Class ties use the intersection size.
`preserve_order=false` retains that priority order for the paper profile;
the private default preserves the earlier canonical intersection-size order.
"""
function _pr_select_classes(histogram::Vector{Int}, floor::Int; preserve_order::Bool = true)
    npoints = length(histogram) - 1
    classes = findall(!iszero, histogram)
    sort!(classes; by = j -> (-abs(2(j-1)-npoints), histogram[j], j))
    total, last = 0, 0
    for j in classes
        total += histogram[j]
        last += 1
        total >= floor && break
    end
    resize!(classes, last)
    preserve_order && sort!(classes)
    return classes, total
end

"""Build selected affine hyperplanes and their initial ordered partition."""
function _pr_build_planes(walsh, npoints::Int, classes::Vector{Int}, histogram)
    ncells = length(classes)
    starts = ones(Int, ncells + 1)
    class_index = zeros(Int, npoints + 1)
    for (c, j) in pairs(classes)
        starts[c+1] = starts[c] + histogram[j]
        class_index[j] = c
    end
    nplanes = starts[end] - 1
    normals, signs = zeros(UInt32, nplanes), zeros(Int8, nplanes)
    positions = copy(starts)
    @inbounds for j = 2:length(walsh)
        for sign in (Int8(1), Int8(-1))
            count_index = (npoints + sign * Int(walsh[j])) ÷ 2 + 1
            c = class_index[count_index]
            c == 0 && continue
            k = positions[c]
            normals[k], signs[k] = UInt32(j - 1), sign
            positions[c] += 1
        end
    end
    return _PRPlanes(normals, signs), _pr_native_partition(nplanes, starts)
end

"""Compute point signatures from signed hyperplane-cell weights (Algorithm 1)."""
function _pr_point_scores!(scores, points, planes::_PRPlanes, hp::_PRPartition,
                           work::_PRWorkspace; keys=nothing)
    k = 0
    @inbounds for c = 1:(length(hp.starts)-1)
        weight = keys === nothing ? _pr_cell_weight(c, length(hp.starts)-1) : keys[c]
        for j = hp.starts[c]:(hp.starts[c+1]-1)
            i = hp.order[j]
            k += 1
            work.normals[k] = planes.normals[i]
            work.weights[k] = weight * planes.signs[i]
        end
    end
    if k <= work.direct_threshold
        packed=_pr_direct_weights!(work,work.weights,k)
        if packed!==nothing
            if _pr_parallel_direct(work,length(points),k)
                _pr_parallel_point_scores32!(scores,points,work.normals,packed,k)
            else
                _pr_direct_point_scores32!(scores,points,work.normals,packed,k)
            end
        elseif _pr_parallel_direct(work, length(points), k)
            _pr_parallel_point_scores!(scores, points, work.normals, work.weights, k)
        else
            @inbounds for i in eachindex(points)
                scores[i] = _pr_signed_sum(points[i], work.normals, work.weights, k)
            end
        end
    else
        fill!(work.scratch, 0)
        @inbounds for j = 1:k
            work.scratch[Int(work.normals[j])+1] += work.weights[j]
        end
        walsh_hadamard!(work.scratch; threaded = work.threaded)
        @inbounds for i in eachindex(points)
            scores[i] = work.scratch[Int(points[i])+1]
        end
    end
    return scores
end

"""Compute hyperplane signatures from point-cell weights (Algorithm 2)."""
function _pr_plane_scores!(scores, points, pp::_PRPartition, planes::_PRPlanes,
                           hp::_PRPartition, work::_PRWorkspace; keys=nothing)
    @inbounds for c = 1:(length(pp.starts)-1)
        weight = keys === nothing ? _pr_cell_weight(c, length(pp.starts)-1) : keys[c]
        for j = pp.starts[c]:(pp.starts[c+1]-1)
            work.point_weights[pp.order[j]] = weight
        end
    end
    if length(hp.order) <= work.direct_threshold
        packed=_pr_direct_weights!(work,work.point_weights,length(points))
        if packed!==nothing
            if _pr_parallel_direct(work,length(points),length(hp.order))
                _pr_parallel_plane_scores32!(scores,points,planes,hp.order,packed)
            else
                _pr_direct_plane_scores32!(scores,points,planes,hp.order,packed)
            end
        elseif _pr_parallel_direct(work, length(points), length(hp.order))
            _pr_parallel_plane_scores!(scores, points, planes, hp.order, work.point_weights)
        else
            @inbounds for i in hp.order
                scores[i] = _pr_signed_sum(planes.normals[i], points,
                    work.point_weights, length(points)) * planes.signs[i]
            end
        end
    else
        fill!(work.scratch, 0)
        @inbounds for j in eachindex(points)
            work.scratch[Int(points[j])+1] = work.point_weights[j]
        end
        walsh_hadamard!(work.scratch; threaded = work.threaded)
        @inbounds for i in hp.order
            scores[i] = Int(work.scratch[Int(planes.normals[i])+1]) * planes.signs[i]
        end
    end
    return scores
end
