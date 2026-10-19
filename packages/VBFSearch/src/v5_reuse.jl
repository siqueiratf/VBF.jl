"""
Certified reuse of complete quadratic V5 extension searches.

The component-space formulation of Beierle et al., arXiv:2508.04644,
Section 3.2, is equivariant under invertible input changes modulo affine
terms. A replayed space transporter therefore transports the entire set of
APN completion spaces. These opt-in, in-memory helpers do not alter campaign
controllers, cursors, checkpoints, or construction-path ledgers.
"""

struct _V5CompletionEntry
    n::Int
    need::Int
    max_kernel::Int
    du_filter::Bool
    forms::Vector{UInt32}
    signature::Vector{Int}
    completions::Vector{Vector{UInt32}}
    source_id::String
    source_tag::String
end

"""
    V5CompletionCache(; max_entries=128)

Bounded process-local cache of fully exhausted V5 completion sets. Only a
positive, replayed input-map certificate permits reuse between different
spaces. Invariant matches and inconclusive comparisons never permit reuse.
Returned arrays are detached from the cache. The cache has one owner and is
not thread safe; it is not a durable campaign coverage certificate.
"""
mutable struct V5CompletionCache
    max_entries::Int
    entries::Vector{_V5CompletionEntry}
    betas::Dict{Int,Vector{Int}}
end

function V5CompletionCache(; max_entries::Int=128)
    max_entries > 0 || throw(ArgumentError("max_entries must be positive"))
    V5CompletionCache(max_entries, _V5CompletionEntry[], Dict{Int,Vector{Int}}())
end

"""Content identifier of a canonical space in a specified input dimension."""
function _v5_reuse_space_id(n, forms)
    bytes2hex(SHA.sha256(string(n, ':', join(forms, ','))))
end

"""Bind a completion claim to its exact source and target spaces and map."""
function _v5_reuse_certificate(entry, target, columns)
    Dict{String,Any}(
        "schema"=>"vbfsearch-v5-reuse-v1", "input_dimension"=>entry.n,
        "need"=>entry.need, "max_kernel"=>entry.max_kernel,
        "du_filter"=>entry.du_filter, "source_space_id"=>entry.source_id,
        "target_space_id"=>_v5_reuse_space_id(entry.n, target),
        "source_forms"=>Int.(entry.forms), "target_forms"=>Int.(target),
        "input_columns"=>Int.(columns), "source_tag"=>entry.source_tag,
        "completion_count"=>length(entry.completions),
        "source_complete"=>true, "scope"=>"all completion spaces; no per-coset path claim")
end

"""
    cached_v5_extensions!(cache, G, V, need; max_kernel=23,
        du_filter=true, max_x=typemax(Int), should_stop=()->false,
        equivalence_seconds=0.25, equivalence_nodes=10_000,
        equivalence_memory_bytes=128*1024^2, max_pairs=4, source_tag="")

Return `(; outcome, reused, certificate, comparisons, work)` for the same
completion-space set as `QuadraticExtensions.v5_extensions`. `outcome` is
`Exhausted` only when every completion is covered; an interrupted or capped
enumeration is `BudgetHit` and is never cached. No solution cap is used.

On a hit, `work=nothing`; all cached outputs are transported by an independently
replayed invertible input map. On a miss, `work` is the ordinary Fourier result.
The rank signature only narrows which cached spaces receive bounded pairwise
comparisons. At most `max_pairs` such comparisons are attempted; exact identity
lookups do not consume that budget. A stop request also interrupts the lookup
between comparisons. One native comparison may overrun that request by its
explicit equivalence budget.

Coverage is of completion spaces, not of the original per-parent coset edges.
A campaign integration must attach transported construction witnesses and
retain its own provenance; this helper does not mark any campaign job done.
"""
function cached_v5_extensions!(cache::V5CompletionCache, G::Fourier.Geometry,
        V::AbstractVector{<:Integer}, need::Int; max_kernel::Int=23,
        du_filter::Bool=true, max_x::Int=typemax(Int), should_stop::Function=()->false,
        equivalence_seconds::Real=0.25, equivalence_nodes::Int=10_000,
        equivalence_memory_bytes::Int=128*1024^2, max_pairs::Int=4,
        source_tag::AbstractString="")
    max_pairs >= 0 || throw(ArgumentError("max_pairs must be nonnegative"))
    equivalence_seconds >= 0 || throw(ArgumentError("equivalence_seconds must be nonnegative"))
    equivalence_nodes >= 0 || throw(ArgumentError("equivalence_nodes must be nonnegative"))
    equivalence_memory_bytes >= 0 || throw(ArgumentError("equivalence_memory_bytes must be nonnegative"))
    max_x >= 0 || throw(ArgumentError("max_x must be nonnegative"))
    max_kernel >= 0 || throw(ArgumentError("max_kernel must be nonnegative"))
    R = VBF._quadratic_space_basis(G, V)
    length(R) == G.n-3 || throw(ArgumentError("V must have dimension n-3"))
    0 <= need <= (1 << length(R)) || throw(ArgumentError("invalid bent count in extension coset"))
    signature = quadratic_space_rank_signature(G, R)
    region = SearchRegion(:v5_completion_spaces, _v5_reuse_space_id(G.n, R);
        params=Dict{String,Any}("input_dimension"=>G.n, "need"=>need,
            "max_kernel"=>max_kernel, "du_filter"=>du_filter,
            "deduplication"=>"exact canonical completion spaces"))
    started=time_ns(); seconds()=(time_ns()-started)*1e-9
    comparisons=0
    if should_stop()
        outcome=BudgetHit(StopPoint(:external,"stop requested before lookup"),region,
            Vector{UInt32}[];nodes_visited=0,elapsed_seconds=seconds())
        return (;outcome,reused=false,certificate=nothing,comparisons,work=nothing)
    end
    matches = [e for e in cache.entries if e.n==G.n && e.need==need &&
        e.max_kernel==max_kernel && e.du_filter==du_filter && e.signature==signature]
    sort!(matches; by=e->e.forms==R ? 0 : 1)
    for entry in matches
        should_stop() && break
        columns = if entry.forms == R
            UInt16[1 << i for i in 0:G.n-1]
        else
            comparisons >= max_pairs && break
            comparisons+=1
            result=quadratic_space_transporter(G,entry.forms,R;
                max_nodes=equivalence_nodes, timeout_seconds=equivalence_seconds,
                max_memory_bytes=equivalence_memory_bytes)
            result isa Found || continue
            only(search_solutions(result))
        end
        verify_quadratic_space_transporter(G,entry.forms,R,columns) ||
            error("cached V5 transporter did not replay")
        outputs=[transform_quadratic_space(G,S,columns) for S in entry.completions]
        certificate=_v5_reuse_certificate(entry,R,columns)
        return (;outcome=Exhausted(region,outputs;nodes_visited=0,elapsed_seconds=seconds()),
            reused=true,certificate,comparisons,work=nothing)
    end
    if should_stop()
        outcome=BudgetHit(StopPoint(:external,"stop requested during lookup"),region,
            Vector{UInt32}[];nodes_visited=0,elapsed_seconds=seconds())
        return (;outcome,reused=false,certificate=nothing,comparisons,work=nothing)
    end
    beta=get!(cache.betas,G.n) do
        G.n==8 ? copy(Fourier.BETA8) : Fourier.bent_fourier(G)
    end
    work=Fourier.v5_extensions(G,R,need,Fourier.V5Work(G.N-length(R),G.n);
        beta,max_kernel,du_filter,max_x,should_stop)
    outputs=sort!(collect(work.Ss);by=S->Tuple(S))
    complete = !work.capped && !work.skipped && work.nX_used==work.nX
    if complete
        entry=_V5CompletionEntry(G.n,need,max_kernel,du_filter,copy(R),signature,
            deepcopy(outputs),_v5_reuse_space_id(G.n,R),String(source_tag))
        push!(cache.entries,entry)
        length(cache.entries)>cache.max_entries && popfirst!(cache.entries)
        certificate=_v5_reuse_certificate(entry,R,UInt16[1 << i for i in 0:G.n-1])
        outcome=Exhausted(region,outputs;nodes_visited=work.ncand,elapsed_seconds=seconds())
    else
        reason=should_stop() ? :external : work.capped ? :memory : :nodes
        detail=work.capped ? "completion kernel exceeded max_kernel" : "eligible-coset enumeration interrupted"
        outcome=BudgetHit(StopPoint(reason,detail),region,outputs;
            nodes_visited=work.ncand,elapsed_seconds=seconds())
        certificate=nothing
    end
    (;outcome,reused=false,certificate,comparisons,work)
end
