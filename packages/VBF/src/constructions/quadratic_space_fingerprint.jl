"""Split one ordered partition canonically and append its exact score histogram."""
function _quadratic_space_fingerprint_split!(partition::_PRPartition, scores, io::IO)
    starts = Int[1]
    for c in 1:length(partition.starts)-1
        lo, hi = partition.starts[c], partition.starts[c+1]-1
        first_score = scores[partition.order[lo]]
        if !all(j -> scores[partition.order[j]] == first_score, lo:hi)
            sort!(view(partition.order, lo:hi); by=i->scores[i])
        end
        run_start = lo
        while run_start <= hi
            score = scores[partition.order[run_start]]
            run_end = run_start
            while run_end < hi && scores[partition.order[run_end+1]] == score
                run_end += 1
            end
            write(io, htol(Int64(score)), htol(Int64(run_end-run_start+1)))
            push!(starts, run_end+1)
            run_start = run_end+1
        end
    end
    # Include parent-cell boundaries as well as score runs. Equal size/score
    # pairs in adjacent old cells remain distinct canonical color classes.
    write(io, htol(Int64(length(partition.starts))))
    for x in partition.starts
        write(io, htol(Int64(x)))
    end
    partition.starts = starts
    write(io, htol(Int64(length(starts))))
    return nothing
end

"""
    quadratic_space_fingerprint(G, V; max_rounds=4,
        min_active_hyperplanes=0) -> String

Necessary invariant for invertible-input equivalence of square-free quadratic
component spaces modulo affine terms. Different fingerprints computed with
the **same options and implementation** rigorously separate spaces; equal
fingerprints are candidate buckets only and never authorize search reuse.
Every proposed merge still requires `quadratic_space_transporter` and exact
certificate replay. SHA collisions can only enlarge candidate buckets.

This reuses the native Kaleyski--Sunde graph/hyperplane incidence kernels in
one direction, with deterministic ordered refinement. A `d`-dimensional space
is represented by an `n`-input, `d`-output pure quadratic table. Its graph point
zero is individualized, then the exact ordered score histograms of at most
`max_rounds` point/hyperplane refinement rounds are hashed. A space transporter
induces a **linear** EA graph transporter fixing zero: the input translation
and output affine drift can be removed modulo affine terms. It consequently
preserves the initial hyperplane classes, all incidence scores and every
recorded histogram by induction. Changes of the component basis also induce
such a graph transporter.

The graph Walsh arrays have `2^(n+d)` entries: 8192 for V5 in eight variables,
not the 2^23-entry quotient arrays of the APN extension search. Space dimension
is limited to `d <= n <= 8`; refinement is deterministic and single threaded.
`min_active_hyperplanes=0` selects the native solver's default class floor.
`max_rounds` is a fixed invariant-strength option, never an equivalence-search
budget. No canonical representative or full stabilizer is computed.
"""
function quadratic_space_fingerprint(G::QuadraticExtensions.Geometry,
        V::AbstractVector{<:Integer}; max_rounds::Int=4,
        min_active_hyperplanes::Int=0)
    0 <= max_rounds <= 32 || throw(ArgumentError("max_rounds must be in 0:32"))
    min_active_hyperplanes >= 0 ||
        throw(ArgumentError("min_active_hyperplanes must be nonnegative"))
    R = _quadratic_space_basis(G, V)
    d = length(R)
    d <= G.n || throw(ArgumentError("component-space dimension must be at most $(G.n)"))
    io = IOBuffer()
    write(io, "vbf-quadratic-space-anchored-refinement-v1\0")
    for x in (G.n, d, max_rounds, min_active_hyperplanes)
        write(io, htol(Int64(x)))
    end
    d == 0 && return bytes2hex(SHA.sha256(take!(io)))
    F = VBFTable{G.n,d}(QuadraticExtensions.lut_from_coeffs(G,
        QuadraticExtensions.forms_to_coeffs(R, G.N)))
    points = FunctionGraph(F).packed
    walsh = _pr_graph_walsh(points, G.n+d)
    histogram = _pr_intersection_histogram(walsh, length(points))
    for x in histogram
        write(io, htol(Int64(x)))
    end
    floor = min_active_hyperplanes == 0 ? (G.n <= 7 ? 16 : 2)*length(points) :
        min_active_hyperplanes
    classes, nplanes = _pr_select_classes(histogram, floor; preserve_order=true)
    planes, hp = _pr_build_planes(walsh, length(points), classes, histogram)
    pp = _PRPartition(length(points))
    _pr_individualize!(pp, 1, 1) # Pure quadratic tables satisfy F(0)=0.
    work = _PRWorkspace(G.n+d, length(points), nplanes; algorithm=:optimized)
    for round in 1:max_rounds
        before = length(pp.starts)+length(hp.starts)
        write(io, htol(Int64(round)))
        _pr_point_scores!(work.point_left, points, planes, hp, work)
        _quadratic_space_fingerprint_split!(pp, work.point_left, io)
        _pr_plane_scores!(work.plane_left, points, pp, planes, hp, work)
        _quadratic_space_fingerprint_split!(hp, work.plane_left, io)
        before == length(pp.starts)+length(hp.starts) && break
    end
    return bytes2hex(SHA.sha256(take!(io)))
end
