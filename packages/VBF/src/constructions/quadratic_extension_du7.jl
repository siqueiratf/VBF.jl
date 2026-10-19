"""Exact DU≤4 pruning of seven-dimensional intermediate component spaces.

For each input direction p, decomposable flats of V5⊥ through p form a binary
space W_p. A square APN completion of V5+<x,t> can add only one further output,
so W_p∩x⊥∩t⊥ must have dimension at most one. For dim W_p=2 this excludes
simultaneous zero signatures; for dimension three both signatures must be
nonzero and distinct. The packed bitsets implement these necessary tests over
the sorted candidate list, preserving its order. A surviving position asserts
no completion: the existing exact affine solver still decides it.

Unsupported point-space dimensions use the separate verified triangle test or
the original algorithm. The bitset domain and all scratch buffers belong to one
invocation; no shared mutable work buffers or probabilistic decisions are used.
"""
struct _DU7Plan
    pairs::Vector{NTuple{2,UInt32}}
    triples::Vector{NTuple{3,UInt32}}
    groupmask::UInt64
    validmask::NTuple{4,UInt64}
    tables::Vector{Vector{NTuple{9,UInt64}}}
    states::Vector{Tuple{NTuple{4,UInt64},UInt64}}
end

"""Linear evaluation signatures, used only to build the byte lookup tables."""
function _du7_linear_state(plan::_DU7Plan,t::UInt32)
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
@inline function _du7_state(plan::_DU7Plan,t::UInt32)
    @inbounds a=plan.tables[1][Int(t&0xff)+1]
    @inbounds b=plan.tables[2][Int((t>>8)&0xff)+1]
    @inbounds c=plan.tables[3][Int((t>>16)&0xff)+1]
    v=ntuple(i->a[i]⊻b[i]⊻c[i],Val(9))
    masks=ntuple(i->~(v[i]|v[i+4])&plan.validmask[i],Val(4))
    (masks,v[9])
end

"""Prepare reusable masks from the installed VBF flat geometry."""
function _du7_prepare(C,Cidx,G,L)
    points=[UInt32[] for _ in 1:1<<G.n]
    for (c,fi) in zip(C,Cidx),p in G.flatpts[fi]
        push!(points[p+1],c)
    end
    pairs=NTuple{2,UInt32}[];triples=NTuple{3,UInt32}[]
    for rows in points
        isempty(rows) && continue
        R=first(rref(rows))
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
    plan=_DU7Plan(pairs,triples,groupmask,validmask,Vector{NTuple{9,UInt64}}[],
        Tuple{NTuple{4,UInt64},UInt64}[])
    columns=[_du7_linear_state(plan,UInt32(1)<<j) for j in 0:23]
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
    for t in L;push!(plan.states,_du7_state(plan,t));end
    plan
end

"""Exact DU7 obstruction for two already prepared quotient signatures."""
@inline function _du7_reject(plan::_DU7Plan,xstate,tstate)
    a,x=xstate;b,t=tstate
    ((a[1]&b[1])|(a[2]&b[2])|(a[3]&b[3])|(a[4]&b[4]))!=0 && return true
    z=x⊻t;mask=plan.groupmask
    ((t|(t>>1)|(t>>2))&mask)!=mask && return true
    ((z|(z>>1)|(z>>2))&mask)!=mask
end

struct _DU7Bits
    zeroes::Matrix{UInt64}
    signatures::Matrix{UInt64}
    bad::Vector{UInt64}
end

"""Transpose previously certified point signatures into candidate bitsets."""
function _DU7Bits(plan)
    words=cld(length(plan.states),64)
    zeroes=zeros(UInt64,words,length(plan.pairs))
    signatures=zeros(UInt64,words,8length(plan.triples))
    for i in eachindex(plan.states)
        masks,sig=plan.states[i];word=((i-1)>>6)+1;bit=UInt64(1)<<((i-1)&63)
        for block in 1:4
            mask=masks[block]
            while mask!=0
                p=trailing_zeros(mask)+64(block-1)+1
                zeroes[word,p]|=bit
                mask&=mask-1
            end
        end
        for p in eachindex(plan.triples)
            value=Int((sig>>(3(p-1)))&7)
            signatures[word,8(p-1)+value+1]|=bit
        end
    end
    _DU7Bits(zeroes,signatures,zeros(UInt64,words))
end

"""Ordered iterator over the complement of an impossible-candidate bitset."""
struct _DU7ValidIndices
    bad::Vector{UInt64}
    last::Int
end
Base.IteratorSize(::Type{_DU7ValidIndices})=Base.SizeUnknown()
Base.eltype(::Type{_DU7ValidIndices})=Int

"""Iterate only positions allowed by the bitset, masking the final partial word."""
function Base.iterate(indices::_DU7ValidIndices,iteration=(0,UInt64(0)))
    word,remaining=iteration
    while remaining==0
        word+=1
        word>cld(indices.last,64) && return nothing
        remaining=~indices.bad[word]
        bits=indices.last-64(word-1)
        bits<64 && (remaining&=(UInt64(1)<<bits)-1)
    end
    bit=trailing_zeros(remaining)
    (64(word-1)+bit+1,(word,remaining&(remaining-1)))
end

"""OR one incompatibility column into the reused per-x word buffer."""
@inline function _du7_or_column!(bits,column,source,words)
    @inbounds @simd for word in 1:words
        bits[word]|=source[word,column]
    end
end

"""Prepare ordered surviving candidate positions for the current x."""
function _du7_valid_indices!(bits::_DU7Bits,xstate,last)
    words=cld(last,64)
    fill!(bits.bad,0)
    masks,sig=xstate
    for block in 1:4
        mask=masks[block]
        while mask!=0
            p=trailing_zeros(mask)+64(block-1)+1
            _du7_or_column!(bits.bad,p,bits.zeroes,words)
            mask&=mask-1
        end
    end
    for p in 1:size(bits.signatures,2)÷8
        value=Int((sig>>(3(p-1)))&7)
        _du7_or_column!(bits.bad,8(p-1)+1,bits.signatures,words)
        _du7_or_column!(bits.bad,8(p-1)+value+1,bits.signatures,words)
    end
    _DU7ValidIndices(bits.bad,last)
end

"Return true only for an exactly replayable odd three-flat contradiction."
@inline function _du7_triangle_reject(pairs,t)
    @inbounds for (a,b) in pairs
        !par(a&t) && !par(b&t) && return true
    end
    false
end
