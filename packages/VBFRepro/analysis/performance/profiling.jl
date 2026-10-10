# performance/profiling.jl — an estimated core/paper/other runtime
# attribution, derived from a FlameGraphs.jl call tree (not a per-frame scan).
#
# This is a STATISTICAL ESTIMATE from a sampling profiler, not an exact
# measurement:
#   * it needs enough samples to be reliable — a call shorter than one
#     sampling interval yields zero samples, hence NaN fractions;
#   * a sample is one instant of execution, not a guaranteed even share of
#     wall time;
#   * Julia's inliner can merge a fast call into its caller's frame, moving
#     an owner boundary earlier or later than the source would suggest.
# `samples_total` travels with every fraction so a reader can see how much
# evidence backs the estimate.
module ProfileAttribution

using FlameGraphs, AbstractTrees

export attribute_flamegraph, profile_components

const CORE_MARKERS = ("packages/VBF/src", "packages/VBFCatalog/src")
const PAPER_MARKER = "papers/"

# `:core`/`:paper` when `file` sits under a marker directory, `:other`
# otherwise — including this project's perf/ orchestration, deliberately:
# perf/ measures the work, it is not the work.
function _owner(file::AbstractString)
    for m in CORE_MARKERS
        occursin(m, file) && return :core
    end
    occursin(PAPER_MARKER, file) && return :paper
    return :other
end

# A FlameGraphs node's `span` is inclusive of every descendant; the node's
# own (exclusive) sample count is what is left after subtracting them.
_exclusive_samples(node) =
    length(node.data.span) -
    sum((length(child.data.span) for child in AbstractTrees.children(node)); init = 0)

# Top-down: a node's *own* file overrides whatever owner its ancestors carry,
# because the node sits strictly nearer to its own descendants' leaves than
# any ancestor does. This is what makes `paper -> VBF -> BLAS` attribute the
# BLAS leaf's exclusive samples to `:core` — BLAS itself has no owner, so it
# inherits VBF's, the nearest one above it, not paper's (farther above VBF).
# Symmetrically, `paper -> (no VBF frame) -> external package` attributes to
# `:paper`, since nothing nearer overrides it.
function _accumulate!(counts, node, inherited::Symbol)
    own = _owner(String(node.data.sf.file))
    effective = own === :other ? inherited : own
    counts[effective] += _exclusive_samples(node)
    for child in AbstractTrees.children(node)
        _accumulate!(counts, child, effective)
    end
    counts
end

"""
    attribute_flamegraph(g) -> NamedTuple

Attribute every sample in flame graph `g` (from `FlameGraphs.flamegraph`) to
`:core`, `:paper`, or `:other`, using each sample's FULL call stack rather
than only its leaf frame — see the module docstring for the ownership rule.
Returns sample counts and fractions for all three; a fraction is `NaN` when
`g` holds zero samples.
"""
function attribute_flamegraph(g)
    counts = Dict(:core => 0, :paper => 0, :other => 0)
    g === nothing || _accumulate!(counts, g, :other)
    total = sum(values(counts))
    frac(k) = total == 0 ? NaN : counts[k] / total
    (; samples_total = total,
       core_samples = counts[:core], paper_samples = counts[:paper], other_samples = counts[:other],
       core_fraction = frac(:core), paper_fraction = frac(:paper), other_fraction = frac(:other))
end

"""Exclusive sample rows, classified by nearest project owner and operation.

FlameGraphs constructs the tree; only the VBF ownership semantics live here.
External callees inherit their nearest project caller. `other` therefore means
unattributed runtime, not all time spent inside Julia or external libraries.
"""
function profile_components(g)
    rows = NamedTuple{(:owner, :subsystem, :operation, :samples),Tuple{String,String,String,Int}}[]
    function visit(node, inherited, subsystem, operation)
        file = replace(String(node.data.sf.file), '\\' => '/')
        own = _owner(file)
        effective = own === :other ? inherited : own
        if own !== :other
            subsystem = if occursin("packages/VBF/src/", file)
                first(split(split(file, "packages/VBF/src/"; limit=2)[2], '/'))
            elseif occursin("packages/VBFCatalog/src/", file)
                "catalog"
            else
                "paper"
            end
            operation = string(node.data.sf.func)
        end
        count = _exclusive_samples(node)
        count > 0 && push!(rows, (string(effective), subsystem, operation, count))
        for child in AbstractTrees.children(node)
            visit(child, effective, subsystem, operation)
        end
    end
    g === nothing || visit(g, :other, "runtime/unattributed", "runtime/unattributed")
    rows
end

end # module
