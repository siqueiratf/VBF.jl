"""Bounded exact finite-field-domain solver for simultaneous APN completion.

After restricting decomposable flats to U-perp, the missing r coordinates form
a linear map to F2^r, required to be nonzero on every residual flat. A state
stores constraints L(mask) notin forbidden. Assigning L(a)=v eliminates one
binary input pivot from every mask; constraints on equal remaining masks merge
their forbidden sets. A zero mask forbidding zero proves contradiction, and a
mask forbidding all but one value forces that value.

Global GL(r,2) acts on the output labels before they are fixed. At each
branch all labels outside the span of previous labels form one orbit under the
pointwise stabilizer of that span. Branching once on that orbit is complete;
labels already in the span remain separate branches. Budget exits are unknown.

This is a research prototype, not a production search. Optional UNSAT trees
record every output-label orbit branch; a separate checker reconstructs all
residual constraints directly from the original flats and assignment equations.
Positive witnesses are independently replayed by QuadraticCompletionSMT/VBF.
"""
module QuadraticCompletionDomains
using VBF

mutable struct Work
    nodes::Int
    merges::Int
    forced::Int
    contradictions::Int
    max_nodes::Int
    deadline::UInt64
    unknown::Bool
end

"XOR-translate a bitset of forbidden output labels."
function translate(forbidden::UInt16,value::Int,q::Int)
    result=UInt16(0)
    for a in 0:q-1
        isodd(forbidden>>a) && (result|=UInt16(1)<<(a⊻value))
    end
    result
end

"Eliminate one chosen input functional and merge equal residual constraints."
function eliminate(groups,a::UInt32,value::Int,q::Int,w::Work)
    pivot=UInt32(1)<<trailing_zeros(a)
    result=Dict{UInt32,UInt16}()
    for (b,forbidden) in groups
        if b&pivot!=0
            b⊻=a;forbidden=translate(forbidden,value,q)
        end
        if b==0
            isodd(forbidden) && return nothing
        else
            old=get(result,b,UInt16(0))
            old!=0 && (w.merges+=1)
            merged=old|forbidden
            count_ones(merged)==q && return nothing
            result[b]=merged
        end
    end
    result
end

"Extend the bitset of a binary output-label subspace by one label."
function extend_span(span::UInt16,value::Int,q::Int)
    result=span
    for a in 0:q-1
        isodd(span>>a) && (result|=UInt16(1)<<(a⊻value))
    end
    result
end

"Bounded exact recursion; a returned equation list is a positive witness."
function search(groups,q::Int,span::UInt16,equations,work::Work,capture::Bool)
    work.nodes+=1
    if work.nodes>work.max_nodes || time_ns()>=work.deadline
        work.unknown=true;return nothing,nothing
    end
    isempty(groups) && return copy(equations),nothing
    a=UInt32(0);forbidden=UInt16(0);best=-1
    for (b,excluded) in groups
        score=count_ones(excluded)
        if score>best || (score==best && b<a)
            a=b;forbidden=excluded;best=score
        end
    end
    allowed=Int[v for v in 0:q-1 if !isodd(forbidden>>v)]
    isempty(allowed) && (work.contradictions+=1;return nothing,(;kind="conflict"))
    if length(allowed)==1
        work.forced+=1
    else
        outside=findfirst(v->!isodd(span>>v),allowed)
        allowed=Int[v for (i,v) in enumerate(allowed) if isodd(span>>v) || i==outside]
    end
    branches=capture ? Any[] : nothing
    for value in allowed
        residual=eliminate(groups,a,value,q,work)
        if residual===nothing
            work.contradictions+=1
            capture && push!(branches,(;value,child=(;kind="conflict")))
            continue
        end
        push!(equations,(a,value))
        answer,proof=search(residual,q,extend_span(span,value,q),equations,work,capture)
        pop!(equations)
        answer===nothing || return answer,nothing
        work.unknown && return nothing,nothing
        capture && push!(branches,(;value,child=proof))
    end
    nothing,capture ? (;kind="branch",mask=a,branches) : nothing
end

"Reconstruct quotient-coordinate vectors from the triangular assignment trace."
function vectors_from_equations(equations,r,D)
    labels=zeros(Int,D)
    for (mask,value) in reverse(equations)
        pivot=trailing_zeros(mask)
        for i in 0:D-1
            i!=pivot && isodd(mask>>i) && (value⊻=labels[i+1])
        end
        labels[pivot+1]=value
    end
    vectors=UInt32[foldl(|,(UInt32((labels[i+1]>>j)&1)<<i for i in 0:D-1);init=UInt32(0)) for j in 0:r-1]
    VBF.linear_basis(vectors;nbits=D)
end

"Solve one completion problem under explicit node and wall-clock budgets."
function solve(p;max_nodes::Int=10000,timeout_seconds::Real=1,capture_proof::Bool=false)
    max_nodes>=0 && timeout_seconds>=0 || throw(ArgumentError("negative bound"))
    q=1<<p.r;start=time_ns()
    deadline=isinf(timeout_seconds) ? typemax(UInt64) : start+UInt64(round(timeout_seconds*1e9))
    work=Work(0,0,0,0,max_nodes,deadline,false)
    groups=Dict(c=>UInt16(1) for c in p.flats)
    answer,proof=search(groups,q,UInt16(1),Tuple{UInt32,Int}[],work,capture_proof)
    vectors=answer===nothing ? nothing : vectors_from_equations(answer,p.r,p.D)
    (;status=answer===nothing ? (work.unknown ? "unknown" : "unsat") : "sat",
        vectors,equations=answer,proof,nodes=work.nodes,merges=work.merges,forced=work.forced,
        contradictions=work.contradictions,seconds=(time_ns()-start)*1e-9,max_nodes,timeout_seconds)
end

"Reconstruct grouped constraints independently from all original input flats."
function replay_constraints(flats,equations,q)
    groups=Dict{UInt32,Set{Int}}()
    for c in flats
        mask=UInt32(c);constant=0
        for (a,value) in equations
            isodd(mask>>trailing_zeros(a)) || continue
            mask⊻=a;constant⊻=value
        end
        if mask==0
            constant==0 && return nothing
        else
            forbidden=get!(Set{Int},groups,mask)
            push!(forbidden,constant)
            length(forbidden)==q && return nothing
        end
    end
    groups
end

"Replay a complete UNSAT branching tree without invoking the search routine."
function replay_unsat(p,proof)
    q=1<<p.r
    function visit(node,equations,fixed_span)
        node===nothing && return false
        groups=replay_constraints(p.flats,equations,q)
        groups===nothing && return node.kind=="conflict"
        node.kind=="branch" || return false
        a=UInt32(node.mask)
        a!=0 && haskey(groups,a) || return false
        forbidden=groups[a]
        allowed=Int[v for v in 0:q-1 if !(v in forbidden)]
        outside=findfirst(v->!(v in fixed_span),allowed)
        expected=Int[v for (i,v) in enumerate(allowed) if v in fixed_span || i==outside]
        [Int(b.value) for b in node.branches]==expected || return false
        for branch in node.branches
            value=Int(branch.value)
            extended=union(fixed_span,Set(x⊻value for x in fixed_span))
            visit(branch.child,vcat(equations,[(a,value)]),extended) || return false
        end
        true
    end
    visit(proof,Tuple{UInt32,Int}[],Set([0]))
end
end
