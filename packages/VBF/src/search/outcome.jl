"""
Three-case result type for bounded searches.

A search over a region can stop for three reasons, and conflating two of them
is how a timeout becomes a theorem:

  * [`Found`](@ref) — stopped early on a solution cap. Says nothing about the
    rest of the region.
  * [`Exhausted`](@ref) — the whole region was walked. Its solution list is
    **complete** for that region, so an `Exhausted` holding no solutions *is* a
    proof that the region is empty.
  * [`BudgetHit`](@ref) — a budget (wall clock, node count, memory) stopped the
    walk. Its solution list is partial and it proves nothing about coverage.

Returning a bare `Vector` cannot express this: an empty vector reads identically
whether the tree was exhausted or the deadline expired. That collapse is not
hypothetical — see the note on `search_qam`/`search_qam_full` below, and
`papers/2021/Beierle_202107/algorithm1.jl`, whose `APNSearch` used to compute a
`timed_out` flag and then drop it on return, so a class that ran out of its
300 s budget was indistinguishable from one proved to contain no APN
permutation.

# Why misuse is a `MethodError` and not a review comment

[`certified_region`](@ref) and [`certified_empty_region`](@ref) are defined
**only** on `Exhausted`. There is deliberately no `::SearchOutcome` fallback, so

    certified_empty_region(result)

on a `BudgetHit` raises `MethodError` from Julia's own dispatch. Do not add a
fallback method — the absence is the check, and
`packages/VBF/test/unit/search_outcome_test.jl` fails if one appears.
[`assert_exhausted`](@ref) gives the same guarantee at runtime, with a message
naming where the walk stopped.

Everything safe to read from any outcome ([`search_solutions`](@ref),
[`search_region`](@ref)) is defined on the abstract type; everything that
asserts coverage is not.

# Example

```jldoctest
julia> using VBF

julia> reg = SearchRegion(:subspace, "V_A/class22"; size = 1024);

julia> e = Exhausted(reg, Int[]);   # walked it all, found nothing

julia> proves_emptiness(e)
true

julia> b = BudgetHit(StopPoint(:time, "300 s"), reg, Int[]);  # ran out of time

julia> proves_emptiness(b)          # same empty list, not a proof
false
```
"""

# ── Region and stop-point descriptors ───────────────────────────────────────

"""
    SearchRegion(kind, id; size = nothing, params = Dict{String,Any}())

What a search covered, or failed to cover. `size` is the region's cardinality
when it is known exactly and `nothing` otherwise — a `nothing` size is itself
information, because no honest coverage fraction can be derived without it.
"""
struct SearchRegion
    kind::Symbol
    id::String
    size::Union{Nothing,BigInt}
    params::Dict{String,Any}
end

SearchRegion(
    kind::Symbol,
    id::AbstractString;
    size::Union{Nothing,Integer} = nothing,
    params::Dict{String,Any} = Dict{String,Any}(),
) = SearchRegion(kind, String(id), size === nothing ? nothing : BigInt(size), params)

Base.show(io::IO, r::SearchRegion) = print(
    io,
    "SearchRegion(",
    r.kind,
    ", \"",
    r.id,
    "\", size=",
    r.size === nothing ? "unknown" : string(r.size),
    ")",
)

"""
    StopPoint(reason, detail = ""; resume_key = Dict{String,Any}())

Where a budget stopped a walk. `reason` is one of `:time`, `:nodes`,
`:solutions`, `:memory`, `:external`. `resume_key` carries whatever the searcher
needs to resume rather than restart, so a `BudgetHit` names a frontier instead
of just a failure.
"""
struct StopPoint
    reason::Symbol
    detail::String
    resume_key::Dict{String,Any}
end

StopPoint(
    reason::Symbol,
    detail::AbstractString = "";
    resume_key::Dict{String,Any} = Dict{String,Any}(),
) = StopPoint(reason, String(detail), resume_key)

Base.show(io::IO, s::StopPoint) =
    print(io, "StopPoint(", s.reason, ", \"", s.detail, "\")")

# ── The three cases ─────────────────────────────────────────────────────────

"""
    SearchOutcome{T}

Abstract supertype of [`Found`](@ref), [`Exhausted`](@ref) and
[`BudgetHit`](@ref). See the file docstring for why the distinction is a type
and not a flag.
"""
abstract type SearchOutcome{T} end

"""
    Found(functions, region; nodes_visited = -1, elapsed_seconds = NaN)

The search stopped early because it produced what it was asked for (a solution
cap). The region was **not** fully walked, so this is not a completeness
statement.
"""
struct Found{T} <: SearchOutcome{T}
    functions::Vector{T}
    region::SearchRegion
    nodes_visited::Int
    elapsed_seconds::Float64
end

Found(
    functions::Vector{T},
    region::SearchRegion;
    nodes_visited::Integer = -1,
    elapsed_seconds::Real = NaN,
) where {T} = Found{T}(functions, region, Int(nodes_visited), Float64(elapsed_seconds))

"""
    Exhausted(region, functions = Any[]; nodes_visited = -1, elapsed_seconds = NaN)

The whole region was walked, so `functions` is the **complete** list of
solutions it contains. An `Exhausted` with no solutions is the only value in
this package that means "this region is empty".
"""
struct Exhausted{T} <: SearchOutcome{T}
    region::SearchRegion
    functions::Vector{T}
    nodes_visited::Int
    elapsed_seconds::Float64
end

Exhausted(
    region::SearchRegion,
    functions::Vector{T} = Any[];
    nodes_visited::Integer = -1,
    elapsed_seconds::Real = NaN,
) where {T} = Exhausted{T}(region, functions, Int(nodes_visited), Float64(elapsed_seconds))

"""
    BudgetHit(where_it_stopped, region, functions = Any[];
              nodes_visited = -1, elapsed_seconds = NaN)

A budget stopped the walk. `functions` is whatever had been found by then — a
partial list. This value proves nothing about the unexamined part of the region,
and the accessors that assert coverage are not defined for it.
"""
struct BudgetHit{T} <: SearchOutcome{T}
    where_it_stopped::StopPoint
    region::SearchRegion
    functions::Vector{T}
    nodes_visited::Int
    elapsed_seconds::Float64
end

BudgetHit(
    where_it_stopped::StopPoint,
    region::SearchRegion,
    functions::Vector{T} = Any[];
    nodes_visited::Integer = -1,
    elapsed_seconds::Real = NaN,
) where {T} = BudgetHit{T}(
    where_it_stopped,
    region,
    functions,
    Int(nodes_visited),
    Float64(elapsed_seconds),
)

# ── Accessors safe on ANY outcome ───────────────────────────────────────────
# Every element of `search_solutions(o)` is a genuine solution however the walk
# ended, so reading them is always sound. Inferring coverage is what is not.

"""
    search_solutions(o::SearchOutcome) -> Vector

The solutions the search produced. Complete only when `o` is [`Exhausted`](@ref).
"""
search_solutions(o::SearchOutcome) = o.functions

"""
    search_region(o::SearchOutcome) -> SearchRegion

The region the search was aimed at — **not** a claim that it was covered.
"""
search_region(o::SearchOutcome) = o.region

nodes_visited(o::SearchOutcome) = o.nodes_visited
elapsed_seconds(o::SearchOutcome) = o.elapsed_seconds

outcome_tag(::Found) = :found
outcome_tag(::Exhausted) = :exhausted
outcome_tag(::BudgetHit) = :budget_hit

is_exhausted(o::SearchOutcome) = o isa Exhausted
is_budget_hit(o::SearchOutcome) = o isa BudgetHit

"""
    proves_emptiness(o::SearchOutcome) -> Bool

`true` only for an [`Exhausted`](@ref) outcome holding no solutions. `false` for
a [`BudgetHit`](@ref) however empty its partial list is, and `false` for
[`Found`](@ref).
"""
proves_emptiness(::SearchOutcome) = false
proves_emptiness(o::Exhausted) = isempty(o.functions)

# ── Accessors defined ONLY on Exhausted ─────────────────────────────────────
# No `::SearchOutcome` fallback exists for these two, on purpose.

"""
    certified_region(o::Exhausted) -> SearchRegion

The region this outcome certifies as completely walked. Defined only for
[`Exhausted`](@ref); calling it on a [`BudgetHit`](@ref) or [`Found`](@ref) is a
`MethodError`.
"""
certified_region(o::Exhausted) = o.region

"""
    certified_empty_region(o::Exhausted) -> SearchRegion

The region this outcome certifies as containing **no** solutions. Defined only
for [`Exhausted`](@ref), and throws if the exhausted region turned out to hold
solutions.
"""
function certified_empty_region(o::Exhausted)
    isempty(o.functions) || throw(
        ArgumentError(
            "certified_empty_region: region $(o.region.id) was exhausted but holds " *
            "$(length(o.functions)) solution(s) — it is not empty",
        ),
    )
    return o.region
end

"""
    assert_exhausted(o::SearchOutcome; context = "") -> Exhausted

Runtime funnel for code that must have a proof of coverage. Returns `o`
unchanged when it is [`Exhausted`](@ref); throws otherwise, naming the stop
point.
"""
assert_exhausted(o::Exhausted; context::AbstractString = "") = o

assert_exhausted(o::BudgetHit; context::AbstractString = "") = error(
    "assert_exhausted$(isempty(context) ? "" : " [$context]"): region " *
    "$(o.region.id) was NOT exhausted — the walk stopped at " *
    "$(o.where_it_stopped.reason) ($(o.where_it_stopped.detail)) after " *
    "$(o.nodes_visited) nodes / $(o.elapsed_seconds) s. This outcome is not a " *
    "proof of emptiness and must not be reported as one.",
)

assert_exhausted(o::Found; context::AbstractString = "") = error(
    "assert_exhausted$(isempty(context) ? "" : " [$context]"): region " *
    "$(o.region.id) stopped early at a solution cap with $(length(o.functions)) " *
    "solution(s); the region was not fully walked.",
)

# ── Reporting ───────────────────────────────────────────────────────────────

"""
    coverage_note(o::SearchOutcome) -> String

One line stating exactly what the outcome licenses. Reports print this so a
`BudgetHit` region can never acquire the wording of an `Exhausted` one.
"""
coverage_note(o::Exhausted) =
    isempty(o.functions) ?
    "EXHAUSTED: region $(o.region.id) fully walked, contains no solutions (proof of emptiness)" :
    "EXHAUSTED: region $(o.region.id) fully walked, contains exactly $(length(o.functions)) solution(s)"

coverage_note(o::BudgetHit) =
    "BUDGET HIT: region $(o.region.id) NOT fully walked — stopped at " *
    "$(o.where_it_stopped.reason) ($(o.where_it_stopped.detail)); " *
    "$(length(o.functions)) solution(s) found so far; coverage of this region is UNKNOWN"

coverage_note(o::Found) =
    "FOUND: region $(o.region.id) stopped early at a solution cap with " *
    "$(length(o.functions)) solution(s); remainder of the region NOT walked"

Base.show(io::IO, o::SearchOutcome) = print(io, coverage_note(o))

# `isempty(result)` is the idiom that hid the old collapse: it reads the same on
# a proof of emptiness and on a timeout. Refuse it, and say what to call instead.
Base.isempty(o::SearchOutcome) = error(
    "isempty is deliberately not supported on a SearchOutcome ($(outcome_tag(o))). " *
    "It is the idiom that collapsed \"proved empty\" into \"ran out of budget\". " *
    "Use `proves_emptiness(o)` for a proof of emptiness, or " *
    "`isempty(search_solutions(o))` if you really only mean \"found nothing so far\".",
)
