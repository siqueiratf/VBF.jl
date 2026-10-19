"""Bounded prototype for certified reuse of complete codimension-two completions.

For U ≤ Alt(n) of dimension n−2, the set C(U) = {S ≥ U : dim S = n,
S⊥ contains no decomposable bivector} depends only on U, not on the V5
hyperplane used to reach U. An invertible input pullback sends C(U) bijectively
to C(A*U). This is the component-space extension criterion of Beierle et al.,
arXiv:2508.04644, Section 3.2. This offline prototype uses the existing VBF
Fourier extension implementation; it does not change campaign coverage.
"""
module V6CompletionReuse

using VBF, SHA
const Q = VBF.QuadraticExtensions

"""Complete exact-U cache entry; affine polynomial terms are excluded."""
struct CompletionEntry
    n::Int
    forms::Vector{UInt32}
    max_kernel::Int
    max_T::Int
    du_filter::Bool
    completions::Vector{Vector{UInt32}}
end

"""Bounded, single-owner cache of independently exhausted completion sets."""
mutable struct CompletionCache
    max_entries::Int
    entries::Vector{CompletionEntry}
end

"""Construct a process-local cache without persistent coverage semantics."""
function CompletionCache(; max_entries::Int=128)
    max_entries > 0 || throw(ArgumentError("max_entries must be positive"))
    CompletionCache(max_entries, CompletionEntry[])
end

"""Canonical exact-U identity, independent of its chosen V5 hyperplane."""
function state_key(G, U)
    R = VBF._quadratic_space_basis(G, U)
    length(R) == G.n-2 || throw(ArgumentError("U must have dimension n-2"))
    (G.n, Tuple(R))
end

"""Compute C(U) with the existing Fourier routine and retain explicit caps.

This direct backend needs one transform per U. It is a proof oracle rather
than a replacement for VBF's faster shared-V5 transform on cache misses.
"""
function complete_state(G, U; max_kernel::Int=23, max_T::Int=1_000_000,
        du_filter::Bool=true)
    max_kernel >= 0 && max_T >= 0 || throw(ArgumentError("negative completion cap"))
    _, key = state_key(G, U)
    R = collect(key)
    started = time_ns()
    result = Q.extensions(G, R, Q.ExtWork(G.N-length(R), G.n);
        max_kernel, max_T, du_filter)
    outputs = Set{Vector{UInt32}}()
    for (u,v) in result.Ts
        S = first(Q.rref(vcat(result.R, Q.lift(u,result.Qmask), Q.lift(v,result.Qmask))))
        length(S) == G.n || error("completion has incorrect dimension")
        push!(outputs, S)
    end
    # Degenerate states need the separate n−1 APN case; never certify them here.
    complete = !result.capped && !result.degenerate
    (; Ss=outputs, complete, work=result,
        elapsed_seconds=(time_ns()-started)*1e-9)
end

"""Cache a complete state or replay an explicitly supplied input transporter.

No invariant match or timed-out comparison establishes coverage. Reused
arrays are detached, and a supplied map is verified against the exact U.
Incomplete results, including solution or kernel caps, are never cached.
"""
function cached_state!(cache::CompletionCache, G, U;
        max_kernel::Int=23, max_T::Int=1_000_000, du_filter::Bool=true,
        source_index::Union{Nothing,Int}=nothing,
        input_columns::Union{Nothing,AbstractVector}=nothing)
    _, key = state_key(G, U)
    R = collect(key)
    identity_columns = UInt16[1 << i for i in 0:G.n-1]
    found = nothing
    columns = identity_columns
    if source_index !== nothing
        1 <= source_index <= length(cache.entries) || throw(ArgumentError("invalid source index"))
        input_columns === nothing && throw(ArgumentError("source index requires an input map"))
        entry = cache.entries[source_index]
        entry.n == G.n && entry.max_kernel == max_kernel && entry.max_T == max_T && entry.du_filter == du_filter ||
            throw(ArgumentError("source completion parameters differ"))
        verify_quadratic_space_transporter(G,entry.forms,R,input_columns) ||
            throw(ArgumentError("U transporter did not replay"))
        found = source_index
        columns = UInt16.(input_columns)
    else
        input_columns === nothing || throw(ArgumentError("input map requires a source index"))
        found = findfirst(e->e.n==G.n && e.forms==R && e.max_kernel==max_kernel && e.max_T==max_T &&
            e.du_filter==du_filter, cache.entries)
    end
    if found !== nothing
        entry = cache.entries[found]
        Ss = Set(transform_quadratic_space(G,S,columns) for S in entry.completions)
        return (; Ss, complete=true, reused=true, source_index=found,
            input_columns=copy(columns), work=nothing)
    end
    result = complete_state(G,R;max_kernel,max_T,du_filter)
    if result.complete
        push!(cache.entries,CompletionEntry(G.n,copy(R),max_kernel,max_T,du_filter,
            deepcopy(sort!(collect(result.Ss);by=Tuple))))
        length(cache.entries)>cache.max_entries && popfirst!(cache.entries)
    end
    merge(result,(;reused=false,source_index=nothing,input_columns=nothing))
end

end
