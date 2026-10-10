"""
Bounded binary-code permutation recovery through column-multiset linear maps.

After row reduction, equal-rank generator matrices represent equivalent codes
iff an invertible linear map matches their column multisets. Search basis images,
propagate linear relations, and retain column multiplicities. This reuses the
incremental GF(2) isomorphism machinery used by Kaleyski–Sunde function recovery;
its function-graph partition-refinement algorithm is not applied verbatim.
"""

"""A rowspace basis and its source pivot columns, using the existing wide reducer."""
function _code_row_basis(G)
    reduced=BitMatrix(G)
    pivots,_=rref_f2!(reduced)
    reduced[1:length(pivots),:],pivots
end

"""Encode reduced generator columns without an ambient 2^rank allocation."""
function _code_columns(B,r)
    T=r<=32 ? UInt32 : BigInt
    cols=T[]
    for j in axes(B,2)
        value=T(0)
        for i in 1:r
            B[i,j] && (value |= T(1) << (i-1))
        end
        push!(cols,value)
    end
    cols
end

"""Preserve multiplicities, including zero and duplicate columns."""
function _code_column_counts(cols::Vector{T}) where T
    counts=Dict{T,Int}()
    for x in cols;counts[x]=get(counts,x,0)+1;end
    counts
end

_code_image(A::_PartialF2Isomorphism,x::UInt32,depth)=_partial_image(A,x)

"""Wide variant of the same basis-image propagation; undefined outside its span."""
function _code_image(images::Vector{BigInt},x::BigInt,depth)
    iszero(x >> depth) || return nothing
    y=big(0)
    for j in 1:depth
        isodd(x >> (j-1)) && (y ⊻= images[j])
    end
    y
end

"""Reject a dependent target image with the shared partial-isomorphism primitive."""
function _code_extend(A::_PartialF2Isomorphism,y::UInt32,depth,r)
    next=copy(A)
    _partial_insert!(next,UInt32(1) << depth,y) ? next : nothing
end

"""For rank>32, the existing wide GF(2) oracle checks target independence."""
function _code_extend(images::Vector{BigInt},y::BigInt,depth,r)
    next=[images;y]
    columns=BitMatrix([isodd(v >> j) for j in 0:r-1,v in next])
    rank_f2(columns)==depth+1 ? next : nothing
end

"""Recover target-column order from a full multiset linear correspondence."""
function _code_permutation(state,left,right,r)
    T=eltype(left)
    queues=Dict{T,Vector{Int}}()
    for (i,x) in pairs(left)
        y=_code_image(state,x,r)
        push!(get!(queues,y,Int[]),i)
    end
    p=Int[]
    for y in right
        queue=get(queues,y,nothing)
        (queue===nothing || isempty(queue)) && return nothing
        push!(p,pop!(queue))
    end
    p
end

"""
    verify_code_equivalence(G::AbstractMatrix{Bool},H::AbstractMatrix{Bool},p) -> Bool

Replay a coordinate-permutation witness independently of the search. `p[j]`
is the source column placed at target position `j`: the assertion is
`rowspace(G[:,p]) == rowspace(H)`. Checks bijectivity, both ranks, and the rank
of their stacked generator matrices. Redundant rows and arbitrary rank are
allowed. This explicit verifier is not budgeted; the bounded search charges
its verification to the overall deadline and allocation estimate.
"""
function verify_code_equivalence(G::AbstractMatrix{Bool},H::AbstractMatrix{Bool},p::AbstractVector)
    Base.require_one_based_indexing(G,H,p)
    n=size(G,2)
    size(H,2)==n && length(p)==n || return false
    all(x->x isa Integer && 1<=x<=n,p) || return false
    permutation=Int.(p)
    sort(permutation)==collect(1:n) || return false
    rg,rh=rank_f2(G),rank_f2(H)
    rg==rh && rank_f2(vcat(G[:,permutation],H))==rg
end

"""
    binary_code_equivalence(G,H;max_nodes=10^6,timeout_seconds=60,
        max_memory_bytes=512*1024^2) -> SearchOutcome{Vector{Int}}

Decide permutation equivalence of arbitrary Boolean generator matrices.
`Found` contains one independently verified permutation `p` with
`rowspace(G[:,p]) == rowspace(H)`; `Exhausted` proves inequivalence after a
separating invariant or complete basis-image search; `BudgetHit` is inconclusive.
Generator row counts may differ. Zero/redundant rows, duplicate/zero columns,
rank-zero codes and zero-length codes are supported.

Reduce to linear equivalence of the full-rank column **multisets**, then branch
only on images of source pivot columns. Reuses Kaleyski–Sunde's incremental
partial-isomorphism core at rank<=32, and the existing wide GF(2) rank oracle
above it. This is separate orchestration, not the function-graph paper algorithm:
that algorithm assumes graph-point indexing and affine anchors, and the older
set-equivalence API loses multiplicities and allocates 2^rank membership tables.

No external dependency or ambient 2^rank allocation is needed. Worst-case
search is exponential; no practical large-code classification is promised.
The deadline includes row reduction and witness replay. Time checks are
cooperative around core linear-algebra calls; memory is a conservative
allocation estimate, not a process RSS limit. `max_nodes` counts search nodes.
"""
function binary_code_equivalence(G::AbstractMatrix{Bool},H::AbstractMatrix{Bool};
    max_nodes::Int=10^6,timeout_seconds::Real=60,max_memory_bytes::Int=512*1024^2)
    Base.require_one_based_indexing(G,H)
    max_nodes>=0 && timeout_seconds>=0 && max_memory_bytes>=0 ||
        throw(ArgumentError("code-equivalence budgets must be nonnegative"))
    start=time_ns()
    budget=_PRBudget(start,Float64(timeout_seconds),max_nodes,0,:none)
    region=SearchRegion(:binary_code_equivalence,"coordinate permutations of binary generator rowspaces";
        params=Dict{String,Any}("source_size"=>collect(size(G)),"target_size"=>collect(size(H)),
            "witness_convention"=>"rowspace(G[:,p]) == rowspace(H)","method"=>"column-multiset basis images"))
    finish=function(p=nothing)
        # Also charge final invariant comparisons or a last rejected branch to
        # the deadline, even when they bypass a subsequent recursive check.
        _pr_check!(budget)
        elapsed=(time_ns()-start)*1e-9
        p!==nothing && budget.stopped===:none &&
            return Found([p],region;nodes_visited=budget.nodes,elapsed_seconds=elapsed)
        budget.stopped!==:none && return BudgetHit(StopPoint(budget.stopped),region,Vector{Int}[];
            nodes_visited=budget.nodes,elapsed_seconds=elapsed)
        Exhausted(region,Vector{Int}[];nodes_visited=budget.nodes,elapsed_seconds=elapsed)
    end
    _pr_check!(budget) || return finish()
    size(G,2)==size(H,2) || return finish()
    max_nodes==0 && (budget.stopped=:nodes;return finish())
    n=size(G,2);bound=min(n,size(G,1),size(H,1))
    # Include reducer copies, witness replay stack, column dictionaries and the
    # live recursive chain (wide independence matrices and partial-map copies).
    nb,rb=Int128(n),Int128(bound)
    estimate=Int128(16)*(length(G)+Int128(length(H))) +
        Int128(256)*(nb+rb*rb+1) + Int128(16)*nb*rb +
        Int128(4)*rb*rb*cld(rb,8)
    region.params["allocation_estimate_bytes"]=string(estimate)
    estimate<=max_memory_bytes || (budget.stopped=:memory;return finish())
    B,pivots=_code_row_basis(G)
    _pr_check!(budget) || return finish()
    C,_=_code_row_basis(H)
    _pr_check!(budget) || return finish()
    r=size(B,1)
    region.params["rank"]=r
    r==size(C,1) || return finish()
    function verified(p)
        p===nothing && return nothing
        verify_code_equivalence(G,H,p) || error("invalid binary-code permutation witness")
        _pr_check!(budget) ? p : nothing
    end
    B==C && return finish(verified(collect(1:n)))
    left,right=_code_columns(B,r),_code_columns(C,r)
    lc,rc=_code_column_counts(left),_code_column_counts(right)
    _pr_check!(budget) || return finish()
    zero_column=eltype(left)(0)
    get(lc,zero_column,0)==get(rc,zero_column,0) || return finish()
    sort!(collect(values(lc)))==sort!(collect(values(rc))) || return finish()
    # RREF's pivot columns are e_i, so a partial source basis is standardized.
    choices=[sort!([y for (y,count) in rc if !iszero(y) && count==lc[left[pivots[i]]]]) for i in 1:r]
    state=r<=32 ? _PartialF2Isomorphism(r) : BigInt[]
    function visit(state,depth)
        _pr_check!(budget) || return nothing
        budget.nodes<budget.max_nodes || (budget.stopped=:nodes;return nothing)
        budget.nodes+=1
        for (x,count) in lc
            y=_code_image(state,x,depth)
            y===nothing || get(rc,y,0)==count || return nothing
        end
        _pr_check!(budget) || return nothing
        depth==r && return verified(_code_permutation(state,left,right,r))
        for y in choices[depth+1]
            _pr_check!(budget) || return nothing
            budget.nodes<budget.max_nodes || (budget.stopped=:nodes;return nothing)
            child=_code_extend(state,y,depth,r)
            child===nothing && continue
            p=visit(child,depth+1)
            p===nothing || return p
            budget.stopped===:none || return nothing
        end
        nothing
    end
    finish(visit(state,0))
end

"""
    are_codes_equivalent(G,H;on_inconclusive=:throw,kwargs...) -> Union{Bool,Missing}

Predicate wrapper for [`binary_code_equivalence`](@ref). The default raises
`InconclusiveEquivalence` on a budget stop. `:missing` preserves uncertainty;
`:best_effort` warns and returns false, which is not an inequivalence proof.
"""
function are_codes_equivalent(G::AbstractMatrix{Bool},H::AbstractMatrix{Bool};
    on_inconclusive::Symbol=:throw,kwargs...)
    _pr_validate_policy(on_inconclusive)
    _pr_decision(binary_code_equivalence(G,H;kwargs...),on_inconclusive,:are_codes_equivalent)
end
