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
struct _PRWorkspace{T<:Signed}
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
end

"""Allocate safe-width scratch space and choose the direct-summation crossover."""
function _PRWorkspace(d::Int, npoints::Int, nplanes::Int; threaded::Bool = false)
    T = Int128(max(npoints, nplanes)) * 8191 <= typemax(Int32) ? Int32 : Int64
    return _PRWorkspace(
        zeros(T, 1 << d), zeros(Int, npoints), zeros(Int, npoints),
        zeros(Int, nplanes), zeros(Int, nplanes), zeros(UInt32, nplanes),
        zeros(Int, nplanes), zeros(Int, npoints), zeros(Int, npoints),
        threaded, (d * (1 << d)) ÷ npoints,
    )
end

"""Compute the graph indicator's Walsh transform using VBF's native FWHT."""
function _pr_graph_walsh(points::Vector{UInt32}, d::Int; threaded::Bool = false)
    v = zeros(Int32, 1 << d)
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
"""
function _pr_select_classes(histogram::Vector{Int}, floor::Int)
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
    sort!(classes)
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
    return _PRPlanes(normals, signs), _PRPartition(collect(1:nplanes), starts)
end

"""Compute point signatures from signed hyperplane-cell weights (Algorithm 1)."""
function _pr_point_scores!(scores, points, planes::_PRPlanes, hp::_PRPartition,
                           work::_PRWorkspace)
    k = 0
    @inbounds for c = 1:(length(hp.starts)-1)
        weight = _pr_cell_weight(c, length(hp.starts)-1)
        for j = hp.starts[c]:(hp.starts[c+1]-1)
            i = hp.order[j]
            k += 1
            work.normals[k] = planes.normals[i]
            work.weights[k] = weight * planes.signs[i]
        end
    end
    if k <= work.direct_threshold
        if _pr_parallel_direct(work, length(points), k)
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
                           hp::_PRPartition, work::_PRWorkspace)
    @inbounds for c = 1:(length(pp.starts)-1)
        weight = _pr_cell_weight(c, length(pp.starts)-1)
        for j = pp.starts[c]:(pp.starts[c+1]-1)
            work.point_weights[pp.order[j]] = weight
        end
    end
    if length(hp.order) <= work.direct_threshold
        if _pr_parallel_direct(work, length(points), length(hp.order))
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
