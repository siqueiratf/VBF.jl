"""
Switching-neighbour APN construction ([Edel and Pott, 2009](@cite Edel_200900)).

For an APN function `F : F₂ⁿ → F₂ⁿ` and a nonzero field element `u`, a
**`u`-switching neighbour** is an APN function of the form
`G(x) = F(x) ⊕ u·s(x)` for a Boolean function `s`, excluding the trivial
choices (`s` constant, linear, or one of `F`'s own `u`-coordinates).
[`switching_neighbors`](@ref) returns, for every nonzero `u`, the APN
functions in the `u`-switching space of `F`.

Switching-neighbour construction (Edel–Pott). The classical formulation
*samples* the constraint equations at random and retries when a kernel
element turns out non-APN; this implementation instead assembles the
**complete** system of necessary linear constraints (so the result is
deterministic and reproducible) and then filters the candidate neighbours by an
explicit APN check. Each affine two-flat contributes one equation, rather than
the 24 repeated equations from its ordered direction and point pairs. The
complete enumeration is still `O(2^{3n})`.

The constraint for a fixed `u` lives over the `2ⁿ` unknowns `s(0..2ⁿ-1)`.
For each direction `a ≠ 0` and pair `x₁ ≠ x₂` (with `x₁ ≠ x₂ ⊕ a`) such
that `D_aF(x₁) ⊕ D_aF(x₂) = u`, the quadruple `{x₁⊕a, x₁, x₂⊕a, x₂}` of
`s`-values must sum to zero. The trivial neighbours (constant / linear /
the `n-1` non-`u` coordinates of `F`) are removed from the solution space.
"""

# Small homogeneous F₂ system: incremental insertion and kernel extraction.
mutable struct _SNSystem
    nvars::Int
    pivot_rows::Vector{BitVector}
    pivot_cols::Vector{Int}
    removed::Vector{BitVector}
    equation_row::BitVector
end

_sn_system(nvars::Int) = _SNSystem(nvars, BitVector[], Int[], BitVector[], falses(nvars))

# 0-based variable positions to a BitVector row, XOR-toggling so repeats cancel.
function _sn_rowof(nvars::Int, positions)
    row = falses(nvars)
    @inbounds for p in positions
        row[p+1] = !row[p+1]
    end
    row
end

function _sn_add_equation!(S::_SNSystem, positions)
    # Dependent equations dominate the complete flat enumeration. Reuse one
    # private row per system and retain an independent copy only for a pivot.
    row = S.equation_row
    fill!(row, false)
    @inbounds for p in positions
        row[p+1] = !row[p+1]
    end
    @inbounds for t in eachindex(S.pivot_rows)
        row[S.pivot_cols[t]] && (row .⊻= S.pivot_rows[t])
    end
    lead = findfirst(row)
    if lead !== nothing
        push!(S.pivot_rows, copy(row))
        push!(S.pivot_cols, lead)
    end
    return nothing
end

_sn_remove_solution!(S::_SNSystem, positions) =
    push!(S.removed, _sn_rowof(S.nvars, positions))

# RREF a set of BitVector rows in place; return parallel pivot columns.
# Explicit callback type parameters prevent Julia's Function-forwarding widening,
# which can cause boxing of callback/position values in the per-flat constraint loop.
_sn_check(::Nothing, stage, direction, position) = nothing
@inline _sn_check(check::C, stage, direction, position::P) where {C,P} = check(stage, direction, position)
_sn_diagnostic(::Nothing, event, value) = nothing
_sn_diagnostic(diagnostics, event, value) = diagnostics(event, value)

function _sn_rref!(rows::Vector{BitVector}, check::C = nothing, direction = 0) where {C}
    cols = Int[]
    keep = BitVector[]
    for (position, r) in enumerate(rows)
        _sn_check(check, :kernel, direction, position)
        row = copy(r)
        for t in eachindex(keep)
            _sn_check(check, :kernel, direction, position)
            row[cols[t]] && (row .⊻= keep[t])
        end
        lead = findfirst(row)
        if lead !== nothing
            push!(keep, row)
            push!(cols, lead)
        end
    end
    # back-reduce
    for i in eachindex(keep)
        pc = cols[i]
        for j in eachindex(keep)
            _sn_check(check, :kernel, direction, i)
            i == j && continue
            keep[j][pc] && (keep[j] .⊻= keep[i])
        end
    end
    return keep, cols
end

# Kernel basis of the system, with the removed solutions quotiented out.
function _sn_kernel(S::_SNSystem, check::C = nothing, direction = 0) where {C}
    _sn_check(check, :kernel, direction, 0)
    prows, pcols = _sn_rref!(S.pivot_rows, check, direction)
    pivot_set = Set(pcols)
    kernel = BitVector[]
    @inbounds for f = 1:S.nvars
        _sn_check(check, :kernel, direction, f)
        f in pivot_set && continue
        v = falses(S.nvars)
        v[f] = true
        for i in eachindex(prows)
            _sn_check(check, :kernel, direction, f)
            prows[i][f] && (v[pcols[i]] = true)
        end
        push!(kernel, v)
    end
    isempty(S.removed) && return kernel

    krows, kcols = _sn_rref!(copy(kernel), check, direction)
    in_kernel = BitVector[]
    for (position, r) in enumerate(S.removed)
        _sn_check(check, :kernel, direction, position)
        row = copy(r)
        for t in eachindex(krows)
            _sn_check(check, :kernel, direction, position)
            row[kcols[t]] && (row .⊻= krows[t])
        end
        findfirst(row) === nothing && push!(in_kernel, r)   # r ∈ span(kernel)
    end
    isempty(in_kernel) && return kernel

    qrows = BitVector[]
    qcols = Int[]
    for (position, r) in enumerate(in_kernel)
        _sn_check(check, :kernel, direction, position)
        row = copy(r)
        for t in eachindex(qrows)
            _sn_check(check, :kernel, direction, position)
            row[qcols[t]] && (row .⊻= qrows[t])
        end
        lead = findfirst(row)
        lead !== nothing && (push!(qrows, row); push!(qcols, lead))
    end
    out = BitVector[]
    for (position, k) in enumerate(kernel)
        _sn_check(check, :kernel, direction, position)
        row = copy(k)
        for t in eachindex(qrows)
            _sn_check(check, :kernel, direction, position)
            row[qcols[t]] && (row .⊻= qrows[t])
        end
        lead = findfirst(row)
        if lead !== nothing
            push!(qrows, row)
            push!(qcols, lead)
            push!(out, k)
        end
    end
    return out
end

# Keep the machine-integer path for small kernels, without wrapping a large
# candidate count into a negative/empty range and falsely reporting exhaustion.
_sn_combinations(nb::Int) = nb < 8*sizeof(Int) - 1 ?
    (1:((1 << nb) - 1)) : (big(1):((big(1) << nb) - 1))

# All neighbours F ⊕ u·s for s in span(basis) \ {0}, keeping the APN ones.
function _sn_apn_coset(
    F::SBox{N,T},
    uu::T,
    basis::Vector{BitVector},
    observer::O = nothing,
    check::C = nothing,
    verified::V = nothing,
    diagnostics::D = nothing,
    start_combination::Integer = 1,
    checkpoint::P = nothing,
) where {N,T,O,C,V,D,P}
    n_size = 1 << N
    result = SBox{N,T}[]
    seen = Set{Vector{T}}()
    nb = length(basis)
    evaluations = 0
    if nb == 0
        start_combination == 1 || throw(ArgumentError("combination cursor exceeds empty switching space"))
        checkpoint === nothing || checkpoint(:direction_complete,
            (; direction=Int(uu), next_direction=Int(uu)+1, next_combination=big(1), evaluations=0))
        _sn_diagnostic(diagnostics, :direction_complete,
            (; direction=Int(uu), evaluations, neighbors=0))
        return result
    end
    combinations = _sn_combinations(nb)
    start_combination <= last(combinations)+1 || throw(ArgumentError("combination cursor exceeds switching space"))
    @inbounds for combo in start_combination:last(combinations)
        _sn_check(check, :candidate, Int(uu), combo)
        evaluations += 1
        observer === nothing || observer(:candidate, nothing)
        lut = copy(F.lut)
        for j = 0:(nb-1)
            ((combo >> j) & 1) == 1 || continue
            bj = basis[j+1]
            for x = 0:(n_size-1)
                bj[x+1] && (lut[x+1] ⊻= uu)
            end
        end
        lut in seen && continue
        push!(seen, lut)
        G = SBox{N,T}(lut)
        observer === nothing || observer(:final_test, nothing)
        apn = differential_uniformity(G) ≤ 2
        if apn
            push!(result, G)
            observer === nothing || observer(:apn, G)
            verified === nothing || verified(G)
        end
        checkpoint === nothing || checkpoint(:candidate_complete,
            (; direction=Int(uu), combination=combo, next_direction=Int(uu),
               next_combination=combo+1, candidate=G, apn))
        _sn_check(check, :candidate_done, Int(uu), combo)
    end
    checkpoint === nothing || checkpoint(:direction_complete,
        (; direction=Int(uu), next_direction=Int(uu)+1, next_combination=big(1), evaluations))
    _sn_diagnostic(diagnostics, :direction_complete,
        (; direction=Int(uu), evaluations, neighbors=length(result)))
    return result
end

"""
    switching_neighbors(F::SBox{N,T}; quadratic_certificate=false)
        -> Vector{Vector{SBox{N,T}}}

For an APN function `F`, the switching neighbours grouped by field
element: entry `u` (for `u = 1 … 2ⁿ-1`) is the vector of APN functions
`G = F ⊕ u·s` with `s` a non-trivial Boolean function in `F`'s
`u`-switching space. The returned vector has length `2ⁿ-1`.

Throws `ArgumentError` if `F` is not APN. See the module docstring for the
deterministic-vs-sampled difference.
Optional `observer(event, value)` reports `:candidate`, `:final_test`, and
`:apn`; only `:apn` carries the verified SBox, which must not be mutated.
With `quadratic_certificate=true`, an exact certificate may establish that
all Boolean switching spaces contain only trivial solutions. It then returns
the same empty groups without constructing the full Boolean systems.
Inconclusive certificates retain the ordinary algorithm.
"""
function switching_neighbors(F::SBox{N,T}; observer = nothing,
    quadratic_certificate::Bool = false) where {N,T}
    _sn_neighbors(F, observer, nothing, nothing, nothing, 1, 1, nothing,
        quadratic_certificate)
end

function _sn_neighbors(
    F::SBox{N,T}, observer::O = nothing, check::C = nothing, verified::V = nothing,
    diagnostics::D = nothing,
    start_direction::Int = 1, start_combination::Integer = 1, checkpoint::P = nothing,
    quadratic_certificate::Bool = false,
) where {N,T,O,C,V,D,P}
    _sn_check(check, :validation, 0, 0)
    differential_uniformity(F) ≤ 2 ||
        throw(ArgumentError("switching_neighbors: F must be APN"))
    _sn_check(check, :constraints, 0, 0)
    n_size = 1 << N
    flut = F.lut

    if quadratic_certificate && _sn_quadratic_empty_certificate(F, check)
        result = [SBox{N,T}[] for _ in 1:(n_size-1)]
        for uu in start_direction:(n_size-1)
            # There are no candidate or elimination steps to trigger the usual
            # throttled polls. Poll each certified direction before its events.
            _sn_check(check, :validation, uu, :quadratic_certificate)
            basis = BitVector[]
            _sn_diagnostic(diagnostics, :kernel,
                (; direction=uu, raw_dimension=2N, quotient_dimension=0,
                    trivial_dimension=2N))
            checkpoint === nothing || checkpoint(:kernel,
                (; direction=uu, raw_dimension=2N, quotient_dimension=0, basis))
            result[uu] = _sn_apn_coset(F, T(uu), basis, observer, check, verified,
                diagnostics, uu == start_direction ? start_combination : 1, checkpoint)
        end
        return result
    end

    # One constraint system per nonzero field element u (1-based: systems[u]).
    systems = [_sn_system(n_size) for _ = 1:(n_size-1)]

    # Exclude trivial neighbours: constant, linear, and F's own coordinates.
    all_positions = collect(0:(n_size-1))
    linear_positions =
        [Int[x for x = 0:(n_size-1) if (x >> i) & 1 == 1] for i = 0:(N-1)]
    for uu = 1:(n_size-1)
        _sn_check(check, :removed_solutions, uu, 0)
        S = systems[uu]
        _sn_remove_solution!(S, all_positions)            # constant function
        for (i, lp) in enumerate(linear_positions)         # linear coordinates
            _sn_check(check, :removed_solutions, uu, i)
            _sn_remove_solution!(S, lp)
        end
        Minv = inv(F2LinearMap{N,T}(complete_basis(T[T(uu)], N)))
        temp_s = compose(Minv, F)                          # M⁻¹ ∘ F
        for i = 1:(N-1)  # F's non-u coordinates
            _sn_check(check, :removed_solutions, uu, N + i)
            pos = Int[x for x = 0:(n_size-1) if (temp_s.lut[x+1] >> i) & 1 == 1]
            _sn_remove_solution!(S, pos)
        end
    end

    _sn_constraints!(systems, flut, check)

    result = [SBox{N,T}[] for _ in 1:(n_size-1)]
    for uu = start_direction:(n_size-1)
        basis = _sn_kernel(systems[uu], check, uu)
        raw_dimension = n_size - length(systems[uu].pivot_rows)
        _sn_diagnostic(diagnostics, :kernel,
            (; direction=uu, raw_dimension, quotient_dimension=length(basis),
               trivial_dimension=raw_dimension-length(basis)))
        checkpoint === nothing || checkpoint(:kernel,
            (; direction=uu, raw_dimension, quotient_dimension=length(basis), basis))
        result[uu] = _sn_apn_coset(F, T(uu), basis, observer, check, verified, diagnostics,
            uu == start_direction ? start_combination : 1, checkpoint)
    end
    return result
end

# A flat is {x, x+a, x+b, x+a+b}. Select its smallest direction a,
# second-smallest direction b, and smallest point x. These are precisely the
# first occurrences in the former (a,x1,x2) loop, so pivot insertion order and
# the resulting kernel/quotient representatives remain unchanged.
function _sn_constraints!(systems, flut, check::C = nothing) where {C}
    n_size = length(flut)
    @inbounds for a in 1:(n_size-1)
        _sn_check(check, :constraints, a, 0)
        for x in 0:(n_size-1)
            xa = x ⊻ a
            x < xa || continue
            # Iterate the opposite point in the original order, rather than
            # b: XOR translation does not preserve integer ordering.
            for xb in (x+1):(n_size-1)
                b = x ⊻ xb
                a < b && b < (a ⊻ b) || continue
                xab = xb ⊻ a
                x < xab || continue
                _sn_check(check, :constraints, a, (x, xb))
                target = flut[x+1] ⊻ flut[xa+1] ⊻ flut[xb+1] ⊻ flut[xab+1]
                iszero(target) && continue
                _sn_add_equation!(systems[Int(target)], (xa, x, xab, xb))
            end
        end
    end
    return nothing
end

# Budget state belongs to one invocation; observer calls may start other searches.
struct _SNStopped <: Exception
    point::StopPoint
end

"""
    switching_neighbors_bounded(F::SBox; max_evaluations=10^4,
        timeout_seconds=60, max_neighbors=typemax(Int), observer=nothing,
        diagnostics=nothing, quadratic_certificate=false)
        -> Exhausted | BudgetHit

Enumerate the same complete-system switching neighbours as
[`switching_neighbors`](@ref), flattened in increasing switching direction and
its existing candidate order. Every returned function has passed an explicit
APN test. `Exhausted` certifies completion; `BudgetHit` retains verified partial
results and does not establish coverage. Neighbour caps conservatively return
`BudgetHit`, even when the final candidate might meet the cap.

`nodes_visited` counts candidate evaluations, including rejected candidates;
constraint construction and kernel elimination do not consume that counter.
The wall-clock budget covers input validation, constraint construction, kernel
extraction and candidate enumeration. Checks occur between individual
constraints and kernel operations; one APN test or linear-algebra primitive
cannot be interrupted. Zero budgets return before validating the input.
The time and `stop_requested` checks run at every validation and candidate
step, but only once in 1024 constraint and kernel steps; neighbour and
evaluation budgets are checked at every step.
`StopPoint.resume_key` identifies the stopped stage, direction and position;
it is a diagnostic frontier, not a serialized resumable linear system.
The observer has the same events and contract as `switching_neighbors`.
`start_direction` and `start_combination` select a suffix of the deterministic
enumeration. A checkpoint callback receives `:kernel` (including the quotient
basis), `:candidate_complete` (including the tested candidate and the next
cursor), and `:direction_complete`. It must persist a candidate and its next
cursor together before returning, and must not mutate supplied values. Resuming
reconstructs the constraint systems for the interrupted parent, then skips
completed directions and combinations. `Exhausted` covers only the selected
suffix; a caller must audit the earlier prefix before claiming full coverage.
Optional `stop_requested()` returns true to stop cooperatively with reason
`:external`, preserving completed candidates and their checkpoint cursors.
Optional `diagnostics(event, value)` reports `:kernel` with the switching
direction, full constraint-kernel dimension, quotient dimension and removed
trivial dimension; `:direction_complete` with per-direction candidate and APN
counts; and `:stop` with the budget frontier and total counts. Diagnostics do
not alter the observer's event sequence and must not mutate returned values.
With `quadratic_certificate=true`, a sufficient quadratic certificate may prove
that every full Boolean switching kernel contains only trivial solutions. The
ordinary empty-kernel and direction-complete events, dimensions and cursors
are preserved. The certificate checks the same time and stop budgets; an
inconclusive certificate falls back to the complete Boolean algorithm.
"""
function switching_neighbors_bounded(
    F::SBox{N,T};
    max_evaluations::Integer = 10^4,
    timeout_seconds::Real = 60,
    max_neighbors::Integer = typemax(Int),
    observer = nothing,
    diagnostics = nothing,
    start_direction::Integer = 1,
    start_combination::Integer = 1,
    checkpoint = nothing,
    stop_requested = nothing,
    quadratic_certificate::Bool = false,
) where {N,T}
    max_evaluations >= 0 || throw(ArgumentError("max_evaluations must be nonnegative"))
    max_neighbors >= 0 || throw(ArgumentError("max_neighbors must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    isfinite(timeout_seconds) || timeout_seconds == Inf ||
        throw(ArgumentError("timeout_seconds must be finite or Inf"))
    1 <= start_direction <= (1<<N) || throw(ArgumentError("invalid switching direction cursor"))
    start_combination >= 1 || throw(ArgumentError("invalid switching combination cursor"))
    start_direction == (1<<N) && start_combination != 1 && throw(ArgumentError("invalid exhausted cursor"))
    started = time_ns()
    elapsed() = Float64(time_ns() - started) / 1e9
    evaluations = Ref(0)
    found = SBox{N,T}[]
    region = SearchRegion(
        :switching_neighbors, "complete switching systems on $(N) bits";
        params = Dict{String,Any}(
            "max_evaluations" => max_evaluations,
            "timeout_seconds" => timeout_seconds,
            "max_neighbors" => max_neighbors,
            "start_direction" => start_direction,
            "start_combination" => string(start_combination),
        ),
    )
    inner_steps = Ref(0)
    function check(stage, direction, position)
        # A complete search makes millions of constraint and kernel steps. Poll
        # the clock and the external stop request only once in 1024 of them.
        poll = stage === :validation || stage === :candidate || stage === :candidate_done ||
            (inner_steps[] += 1) & 1023 == 0
        reason = if poll && stop_requested !== nothing && stop_requested()
            :external
        elseif length(found) >= max_neighbors
            :solutions
        elseif poll && elapsed() >= timeout_seconds
            :time
        elseif (stage === :validation || stage === :candidate) &&
               evaluations[] >= max_evaluations
            :nodes
        else
            nothing
        end
        if reason !== nothing
            frontier = Dict{String,Any}(
                "stage" => stage, "direction" => direction, "position" => position,
                "evaluations" => evaluations[],
            )
            throw(_SNStopped(StopPoint(
                reason, "switching stage $(stage), direction $(direction), position $(position)";
                resume_key = frontier,
            )))
        end
        stage === :candidate && (evaluations[] += 1)
        return nothing
    end
    try
        _sn_neighbors(F, observer, check, G -> push!(found, G), diagnostics,
            Int(start_direction), start_combination, checkpoint,
            quadratic_certificate)
    catch err
        err isa _SNStopped || rethrow()
        _sn_diagnostic(diagnostics, :stop,
            (; point=err.point, evaluations=evaluations[], neighbors=length(found)))
        return BudgetHit(
            err.point, region, found;
            nodes_visited = evaluations[], elapsed_seconds = elapsed(),
        )
    end
    return Exhausted(
        region, found; nodes_visited = evaluations[], elapsed_seconds = elapsed(),
    )
end
