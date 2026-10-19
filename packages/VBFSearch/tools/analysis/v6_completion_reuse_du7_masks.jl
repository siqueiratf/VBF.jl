"""V5-amortized exact DU≤4 necessary filter on the candidate U7.

At each input direction p, flats of V5⊥ through p form a binary space
W_p. Adding x,t must leave its dimension at most1. For dim W_p=2,
x,t cannot both annihilate W_p; for dimension3 their evaluation signatures
must be distinct and nonzero. Four word masks and packed3-bit signatures
test this after each t signature is prepared only once for the whole V5.
Unsupported point-space dimensions fall back to the verified triangle filter.
"""
module V6CompletionReuseDU7Masks
using VBF, SHA
using VBF.QuadraticExtensions
include("v6_completion_reuse_triangles.jl")
const T=V6CompletionReuseTriangles
const Q=VBF.QuadraticExtensions
const hist_key=Q.hist_key
const par=Q.par
const solve_ones=Q.solve_ones
const sort3=Q.sort3
const pext=Q.pext
const TriangleStats=T.TriangleStats
const triangle_rejection=T.triangle_rejection

"""Exact per-direction annihilation data in V/V5 coordinates."""
struct DU7Plan
    pairs::Vector{NTuple{2,UInt32}}
    triples::Vector{NTuple{3,UInt32}}
    groupmask::UInt64
    validmask::NTuple{4,UInt64}
    tables::Vector{Vector{NTuple{9,UInt64}}}
    states::Vector{Tuple{NTuple{4,UInt64},UInt64}}
end

"""Linear evaluation signatures, used only to build the byte lookup tables."""
function linear_state(plan::DU7Plan,t::UInt32)
    a=zeros(UInt64,4);b=zeros(UInt64,4)
    @inbounds for i in eachindex(plan.pairs)
        u,v=plan.pairs[i]
        bit=UInt64(1)<<((i-1)&63);word=((i-1)>>6)+1
        par(u&t) && (a[word]|=bit)
        par(v&t) && (b[word]|=bit)
    end
    signature=UInt64(0)
    @inbounds for i in eachindex(plan.triples)
        u,v,w=plan.triples[i]
        sig=UInt64(par(u&t))|(UInt64(par(v&t))<<1)|(UInt64(par(w&t))<<2)
        signature|=sig<<(3(i-1))
    end
    (a[1],a[2],a[3],a[4],b[1],b[2],b[3],b[4],signature)
end

"""Zero signatures via three byte lookups instead of per-point parities."""
@inline function state(plan::DU7Plan,t::UInt32)
    @inbounds a=plan.tables[1][Int(t&0xff)+1]
    @inbounds b=plan.tables[2][Int((t>>8)&0xff)+1]
    @inbounds c=plan.tables[3][Int((t>>16)&0xff)+1]
    v=ntuple(i->a[i]⊻b[i]⊻c[i],Val(9))
    masks=ntuple(i->~(v[i]|v[i+4])&plan.validmask[i],Val(4))
    (masks,v[9])
end

"""Prepare reusable masks from the installed VBF flat geometry."""
function prepare(C,Cidx,G,L)
    points=[UInt32[] for _ in 1:1<<G.n]
    for (c,fi) in zip(C,Cidx),p in G.flatpts[fi]
        push!(points[p+1],c)
    end
    pairs=NTuple{2,UInt32}[];triples=NTuple{3,UInt32}[]
    for rows in points
        isempty(rows) && continue
        R=first(Q.rref(rows))
        if length(R)==2
            push!(pairs,(R[1],R[2]))
        elseif length(R)==3
            push!(triples,(R[1],R[2],R[3]))
        elseif length(R)>3
            return nothing
        end
    end
    length(pairs)<=256 && length(triples)<=21 && all(c->c<1<<24,C) || return nothing
    groupmask=foldl(|,(UInt64(1)<<(3(i-1)) for i in eachindex(triples));init=UInt64(0))
    validmask=ntuple(word->foldl(|,(UInt64(1)<<((i-1)&63) for i in eachindex(pairs)
        if ((i-1)>>6)+1==word);init=UInt64(0)),Val(4))
    plan=DU7Plan(pairs,triples,groupmask,validmask,Vector{NTuple{9,UInt64}}[],
        Tuple{NTuple{4,UInt64},UInt64}[])
    columns=[linear_state(plan,UInt32(1)<<j) for j in 0:23]
    for chunk in 0:2
        table=Vector{NTuple{9,UInt64}}(undef,256)
        table[1]=ntuple(_->UInt64(0),Val(9))
        for value in 1:255
            previous=table[(value&(value-1))+1]
            column=columns[chunk*8+trailing_zeros(value)+1]
            table[value+1]=ntuple(i->previous[i]⊻column[i],Val(9))
        end
        push!(plan.tables,table)
    end
    sizehint!(plan.states,length(L))
    for t in L;push!(plan.states,state(plan,t));end
    plan
end

"""Exact DU7 obstruction for two already prepared quotient signatures."""
@inline function reject(plan::DU7Plan,xstate,tstate)
    a,x=xstate;b,t=tstate
    ((a[1]&b[1])|(a[2]&b[2])|(a[3]&b[3])|(a[4]&b[4]))!=0 && return true
    z=x⊻t;mask=plan.groupmask
    ((t|(t>>1)|(t>>2))&mask)!=mask && return true
    ((z|(z>>1)|(z>>2))&mask)!=mask
end

variant=T.replace_once(T.variant,"function triangle_v5_extensions(","function du7_v5_extensions(")
variant=T.replace_once(variant,"lifted = [lift(x, Qmask) for x in X]",
    "du7_plan=prepare(C,Cidx,G,L)\n    lifted = [lift(x, Qmask) for x in X]")
variant=T.replace_once(variant,"empty!(Tseen)\n", "empty!(Tseen)\n        du7_xstate=du7_plan===nothing ? nothing : state(du7_plan,x)\n")
old_filter=match(r"rejected_at=triangle_rejection\(triangle_pairs,t\)\n[ \t]*audit_stats.pair_tests[^\n]*",variant)
old_filter===nothing && error("cannot locate triangle filter")
variant=T.replace_once(variant,String(old_filter.match), """
            rejected_at=du7_plan===nothing ? triangle_rejection(triangle_pairs,t) :
                (reject(du7_plan,du7_xstate,du7_plan.states[i]) ? 1 : 0)
            audit_stats.pair_tests+=du7_plan===nothing ?
                (rejected_at==0 ? length(triangle_pairs) : rejected_at) : 1""")
Core.eval(@__MODULE__,Meta.parse(variant))
end
