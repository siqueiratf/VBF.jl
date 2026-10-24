"""Owned read-only preparation for repeated Fourier extensions of one V5 space.

The plan caches only range-independent transforms and constraints. Candidate
thresholds and DU7 domains remain range-specific, preserving the original
enumeration, pruning and evidence counters. Arrays are read-only by ownership:
callers must not mutate plans, their shared geometry or their rank lookup.
"""

"""A prepared canonical V5 domain; construction belongs to `prepare_v5_plan`.

The Walsh array (allocated or explicitly transferred), eligible cosets,
constraints and dense histogram are owned by the plan and never alias the
optional reusable builder's scratch. Geometry and rank lookup are shared
read-only bindings. They must outlive all consumers.
"""
struct V5Plan
    geometry::Geometry
    basis::Vector{UInt32}
    beta::Vector{Int}
    need::Int
    rank_table::Union{Nothing,_PolarRankLookup}
    quotient_mask::UInt32
    quotient_dimension::Int
    eligible_cosets::Vector{UInt32}
    constraints::Vector{UInt32}
    constraint_flat_indices::Vector{Int}
    walsh::Vector{Int16}
    flat_counts::Vector{Int}
    key::Tuple{UInt64,UInt64}
end

"""
    prepare_v5_plan(G, V5, need; beta, rank_table=nothing, work=nothing,
                    walsh_buffer=nothing)

Prepare the invariant Fourier transforms once for disjoint coset-range calls to
`v5_extensions(...; plan)`. `work`, when supplied, lends only its private count
buffer during construction. Reusing that builder cannot mutate the finished
plan. The plan retains no count transform or per-range candidate/DU7 buffers.

By default the plan allocates and owns its Walsh array. An explicit
`walsh_buffer::Vector{Int16}` must have exactly `1 << (G.N-rank(V5))` elements
and must not alias inputs or builder scratch. Its contents are overwritten;
it is never resized. Successful return transfers its ownership to the plan.
If construction throws, the caller retains its possibly modified buffer.
The caller may reclaim/recycle it only after the plan lifetime has ended and
every consumer has finished. Such an expired plan must never be used again.

Consumers must use the same read-only geometry instance, equal `beta` and
canonical V5 basis, and the same rank-lookup binding. A consumer's `V5Work(0,n)`
is sufficient: the planned path does not read or write its `cnt` or `g5` arrays.
"""
function prepare_v5_plan(G::Geometry,V5::AbstractVector{UInt32},need::Int;
                         beta::Vector{Int},rank_table::Union{Nothing,_PolarRankLookup}=nothing,
                         work::Union{Nothing,V5Work}=nothing,
                         walsh_buffer::Union{Nothing,Vector{Int16}}=nothing)
    walsh_buffer===nothing || _validate_v5_walsh_buffer(walsh_buffer,G,V5,beta,rank_table,work)
    cnt=work===nothing ? Int32[] : work.cnt
    prepared=coset_bent_counts!(cnt,G,V5,beta;rank_table)
    R,Qmask,D=prepared.R,prepared.Qmask,prepared.D
    hc,X=_v5_bent_histogram(cnt,prepared.scale,need,length(R))
    C=UInt32[];Cidx=Int[]
    @inbounds for (fi,w) in enumerate(G.flats)
        ok=true
        for rr in R
            par(w&rr) && (ok=false;break)
        end
        ok && (push!(C,pext(w,Qmask));push!(Cidx,fi))
    end
    _v5_order_constraints!(C,Cidx)
    g5=walsh_buffer===nothing ? zeros(Int16,1<<D) : walsh_buffer
    walsh_buffer===nothing || fill!(g5,Int16(0))
    @inbounds for c in C;g5[c+1]=Int16(1);end
    fwht!(g5)
    counts=Int[]
    hg=_v5_flat_histogram(g5,counts)
    key=hist_key(Dict(vcat([(Int(k),v) for (k,v) in hc],
        [(100_000_000+Int(k),v) for (k,v) in hg])))
    V5Plan(G,copy(R),copy(beta),need,rank_table,Qmask,D,X,C,Cidx,g5,counts,key)
end

"""Reject known scratch/input aliases before a transferred buffer is mutated."""
function _validate_v5_walsh_buffer(buffer,G,V5,beta,rank_table,work)
    D=G.N-length(first(rref(V5)))
    0<=D<=G.N && length(buffer)==1<<D ||
        throw(ArgumentError("walsh_buffer must have exactly 1 << (G.N-rank(V5)) elements"))
    for array in (V5,beta,G.pair,G.pairs,G.flats,G.flatpts,G.rt)
        Base.mightalias(buffer,array) && throw(ArgumentError("walsh_buffer must not alias plan inputs"))
    end
    if rank_table!==nothing
        for name in fieldnames(typeof(rank_table))
            array=getfield(rank_table,name)
            array isa AbstractArray || continue
            Base.mightalias(buffer,array) && throw(ArgumentError("walsh_buffer must not alias the rank lookup"))
        end
    end
    if work!==nothing
        for array in (work.cnt,work.g5,work.pts,work.flat_histogram,work.bitmap,
                work.du7.zeroes,work.du7.signatures,work.du7.bad)
            Base.mightalias(buffer,array) && throw(ArgumentError("walsh_buffer must not alias builder scratch"))
        end
    end
    nothing
end

"""Reject a plan bound to another mathematical domain before processing a coset."""
function _validate_v5_plan(plan::V5Plan,G::Geometry,V5,need,beta,rank_table)
    plan.geometry===G || throw(ArgumentError("V5 plan belongs to another geometry instance"))
    plan.need==need || throw(ArgumentError("V5 plan has another required bent count"))
    plan.beta==beta || throw(ArgumentError("V5 plan has another beta vector"))
    plan.rank_table===rank_table || throw(ArgumentError("V5 plan has another rank lookup binding"))
    first(rref(V5))==plan.basis || throw(ArgumentError("V5 plan has another canonical basis"))
    nothing
end

"""Restore cached counts into private scratch before stable candidate counting-sort."""
function _restore_v5_plan_histogram!(bins::Vector{Int},plan::V5Plan)
    isempty(plan.flat_counts) && return nothing
    length(bins)==length(plan.flat_counts) || resize!(bins,length(plan.flat_counts))
    copyto!(bins,plan.flat_counts)
    nothing
end

"""Owned retained bytes, excluding the externally shared geometry and rank lookup."""
function v5_plan_bytes(plan::V5Plan)
    sizeof(plan)+sum(Base.summarysize,(plan.basis,plan.beta,plan.eligible_cosets,
        plan.constraints,plan.constraint_flat_indices,plan.walsh,plan.flat_counts))
end
