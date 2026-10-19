"""Validate a packed square-free quadratic form and its ambient dimension."""
function _quadratic_space_form(G::QuadraticExtensions.Geometry, q::Integer)
    0 <= q < (UInt64(1) << G.N) ||
        throw(ArgumentError("quadratic form exceeds the $(G.N)-bit ambient space"))
    return UInt32(q)
end

"""Canonical basis; linear and constant terms are not part of this representation."""
function _quadratic_space_basis(G::QuadraticExtensions.Geometry, V::AbstractVector{<:Integer})
    return first(QuadraticExtensions.rref([_quadratic_space_form(G, q) for q in V]))
end

"""Validate columns of an invertible input map, with the least significant input bit first."""
function _quadratic_space_columns(G::QuadraticExtensions.Geometry, columns::AbstractVector{<:Integer})
    length(columns) == G.n || throw(ArgumentError("input map must have $(G.n) columns"))
    all(c -> 0 <= c < (1 << G.n), columns) ||
        throw(ArgumentError("input map columns exceed the $(G.n)-bit input space"))
    A = F2LinearMap{G.n,UInt16}(UInt16.(columns))
    is_invertible(A) || throw(ArgumentError("input map must be invertible"))
    return A
end

"""The induced exterior-square columns, computed using VBF's existing wedge coordinates."""
function _quadratic_space_pullback_columns(G::QuadraticExtensions.Geometry, A::F2LinearMap)
    return [QuadraticExtensions.wedge(G.pair, G.n, A.cols[i], A.cols[j])
            for (i, j) in G.pairs]
end

@inline function _quadratic_space_pullback(q::UInt32, wedges::Vector{UInt32})
    result = UInt32(0)
    for (i, w) in enumerate(wedges)
        isodd(count_ones(q & w)) && (result |= UInt32(1) << (i - 1))
    end
    return result
end

"""
    transform_quadratic_form(G, q, input_columns) -> UInt32

Square-free quadratic part of `q(A*x)`, where `input_columns[i] = A(e_i)`.
Coordinates are those of `QuadraticExtensions.Geometry`. Boolean diagonal
terms created by substitution satisfy `x_i^2 = x_i` and are discarded: this
is an action on quadratic forms **modulo affine functions**. An invertible
input map is required. Polarization computes the square-free coefficients
directly without treating the full composed Boolean polynomial as homogeneous.
"""
function transform_quadratic_form(G::QuadraticExtensions.Geometry, q::Integer,
                                  input_columns::AbstractVector{<:Integer})
    form = _quadratic_space_form(G, q)
    A = _quadratic_space_columns(G, input_columns)
    return _quadratic_space_pullback(form, _quadratic_space_pullback_columns(G, A))
end

"""
    transform_quadratic_space(G, V, input_columns) -> Vector{UInt32}

Canonical reduced basis of the pullback `A^*V = {q(A*x) mod affine : q in V}`.
Changing the supplied basis of `V` does not change the result. Input columns
are images of the standard basis vectors; a singular map is rejected.
"""
function transform_quadratic_space(G::QuadraticExtensions.Geometry, V::AbstractVector{<:Integer},
                                   input_columns::AbstractVector{<:Integer})
    R = _quadratic_space_basis(G, V)
    A = _quadratic_space_columns(G, input_columns)
    wedges = _quadratic_space_pullback_columns(G, A)
    return first(QuadraticExtensions.rref([_quadratic_space_pullback(q, wedges) for q in R]))
end

"""
    verify_quadratic_space_transporter(G, V, W, input_columns) -> Bool

Replay an invertible input map and check exact equality `A^*V = W` modulo
affine terms. Malformed, singular, out-of-range, and incorrect certificates
return `false`. No invariant comparison can replace this replay.
"""
function verify_quadratic_space_transporter(G::QuadraticExtensions.Geometry,
        V::AbstractVector{<:Integer}, W::AbstractVector{<:Integer},
        input_columns::AbstractVector{<:Integer})
    try
        return transform_quadratic_space(G, V, input_columns) == _quadratic_space_basis(G, W)
    catch err
        err isa ArgumentError || err isa InexactError || rethrow()
        return false
    end
end

"""
    quadratic_space_rank_signature(G, V) -> Vector{Int}

Histogram of polar ranks among **all** forms in the component space. Entry
`r+1` counts rank `r`. This is invariant under invertible input maps and basis
changes; differing histograms prove inequivalence, but equality is only a
candidate filter. Component-space dimension is restricted to `G.n` to keep
this enumeration bounded by 256 forms.
"""
function quadratic_space_rank_signature(G::QuadraticExtensions.Geometry, V::AbstractVector{<:Integer})
    R = _quadratic_space_basis(G, V)
    length(R) <= G.n || throw(ArgumentError("component-space dimension must be at most $(G.n)"))
    histogram = zeros(Int, G.n + 1)
    for q in QuadraticExtensions.comp_forms(R)
        histogram[QuadraticExtensions.form_rank(G, q) + 1] += 1
    end
    return histogram
end

"""
    quadratic_space_transporter(G, V, W; max_nodes=10_000,
        timeout_seconds=1.0, max_memory_bytes=128*1024^2,
        algorithm=:optimized) -> SearchOutcome{Vector{UInt16}}

Find columns of an invertible input map `A` for which `A^*V = W` modulo
affine terms. `Found` contains one independently replayed column vector;
an empty `Exhausted` proves inequivalence, while `BudgetHit` is inconclusive.
Both spaces must have dimension at most `G.n` (and `2 <= G.n <= 8`).

The solver reuses VBF's bounded native EA partition refinement on rectangular
`n`-input, `d`-output truth tables of independent coordinate forms, rather than
enumerating `GL(n,2)`. Their ambient graph dimension is `n+d` (13 for V5 in
eight variables). An EA graph witness induces an invertible input map, and
its inverse is replayed on the original coefficient spaces. Translation of
quadratic inputs changes only affine terms, so no affine input translation
is required in the returned certificate. Conversely, a space transporter
induces an invertible output-basis change and hence an EA graph witness.

This is a pairwise certified decision procedure, **not** a canonical-labeling
algorithm or a proof that a matching rank signature permits search reuse.
Timeout covers local preprocessing and the native search. The memory option
is the backend's conservative allocation estimate, not an operating-system
RSS cap. Identity transport is handled without a graph search.
"""
function quadratic_space_transporter(G::QuadraticExtensions.Geometry,
        V::AbstractVector{<:Integer}, W::AbstractVector{<:Integer};
        max_nodes::Int=10_000, timeout_seconds::Real=1.0,
        max_memory_bytes::Int=128*1024^2, algorithm::Symbol=:optimized)
    max_nodes >= 0 || throw(ArgumentError("max_nodes must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    max_memory_bytes >= 0 || throw(ArgumentError("max_memory_bytes must be nonnegative"))
    algorithm in (:paper, :optimized) || throw(ArgumentError("unknown partition refinement algorithm"))
    start = time_ns()
    region = SearchRegion(:equivalence, "GL($(G.n),2) quadratic component spaces modulo affine";
        params=Dict{String,Any}("action"=>"pullback", "algorithm"=>algorithm))
    elapsed() = (time_ns() - start) * 1e-9
    empty_witnesses = Vector{UInt16}[]
    exhausted(reason) = begin
        region.params["decision_reason"] = reason
        Exhausted(region, empty_witnesses; nodes_visited=0, elapsed_seconds=elapsed())
    end
    budget(reason) = BudgetHit(StopPoint(reason), region, empty_witnesses;
        nodes_visited=0, elapsed_seconds=elapsed())
    timeout_seconds == 0 && return budget(:time)
    max_nodes == 0 && return budget(:nodes)
    R, S = _quadratic_space_basis(G, V), _quadratic_space_basis(G, W)
    d = length(R)
    max(d, length(S)) <= G.n ||
        throw(ArgumentError("component-space dimension must be at most $(G.n)"))
    region.params["dimension_source"] = d
    region.params["dimension_target"] = length(S)
    length(S) == d || return exhausted("different dimensions")
    elapsed() >= timeout_seconds && return budget(:time)
    if R == S
        columns = [UInt16(1) << i for i in 0:G.n-1]
        return Found([columns], region; nodes_visited=0, elapsed_seconds=elapsed())
    end
    quadratic_space_rank_signature(G, R) == quadratic_space_rank_signature(G, S) ||
        return exhausted("different exact polar-rank histograms")
    elapsed() >= timeout_seconds && return budget(:time)
    F = VBFTable{G.n,d}(QuadraticExtensions.lut_from_coeffs(G,
        QuadraticExtensions.forms_to_coeffs(R, G.N)))
    H = VBFTable{G.n,d}(QuadraticExtensions.lut_from_coeffs(G,
        QuadraticExtensions.forms_to_coeffs(S, G.N)))
    remaining = max(0.0, Float64(timeout_seconds) - elapsed())
    outcome = partition_refinement_equivalence(F, H; relation=:ea, max_nodes,
        timeout_seconds=remaining, max_memory_bytes, algorithm)
    region.params["backend_region"] = outcome.region.params
    if outcome isa Found
        ambient = only(search_solutions(outcome))
        forward = F2LinearMap{G.n,UInt16}(
            UInt16[ambient.linear.cols[d+i] >> d for i in 1:G.n])
        columns = inv(forward).cols
        verify_quadratic_space_transporter(G, R, S, columns) ||
            error("native EA witness failed quadratic-space transporter replay")
        return Found([columns], region; nodes_visited=outcome.nodes_visited,
            elapsed_seconds=elapsed())
    elseif outcome isa BudgetHit
        return BudgetHit(outcome.where_it_stopped, region, empty_witnesses;
            nodes_visited=outcome.nodes_visited, elapsed_seconds=elapsed())
    end
    return Exhausted(region, empty_witnesses; nodes_visited=outcome.nodes_visited,
        elapsed_seconds=elapsed())
end
