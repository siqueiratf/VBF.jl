"""Amortize DU7 feasibility across64 candidate positions per word.

For every V5-point signature, retain a bitset of the sorted L positions
having that signature. A fixed x excludes the union of its incompatible
signature bitsets. Iterating the complement preserves the order of L and
skips impossible completion systems before touching their partner Walsh cell.
"""
module V6CompletionReuseDU7Bitsets
using VBF, SHA
using VBF.QuadraticExtensions
include("v6_completion_reuse_du7_masks.jl")
const M=V6CompletionReuseDU7Masks
const Q=VBF.QuadraticExtensions
const hist_key=Q.hist_key
const par=Q.par
const solve_ones=Q.solve_ones
const sort3=Q.sort3
const pext=Q.pext
const prepare=M.prepare
const state=M.state
const reject=M.reject
const triangle_rejection=M.triangle_rejection
Base.@kwdef mutable struct TriangleStats
    candidates::Int=0
    rejected::Int=0
    pair_tests::Int=0
    pairs::Int=0
    cosets::Int=0
    early_rejected::Int=0
end

"""Sorted-L position bitsets for point-wise zero and three-bit signatures."""
struct DU7Bits
    zeroes::Matrix{UInt64}
    signatures::Matrix{UInt64}
    bad::Vector{UInt64}
end

"""Transpose previously certified point signatures into candidate bitsets."""
function DU7Bits(plan)
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
    DU7Bits(zeroes,signatures,zeros(UInt64,words))
end

"""Ordered iterator over the complement of an impossible-candidate bitset."""
struct ValidIndices
    bad::Vector{UInt64}
    last::Int
end
Base.IteratorSize(::Type{ValidIndices})=Base.SizeUnknown()
Base.eltype(::Type{ValidIndices})=Int

"""Iterate only positions allowed by the bitset, masking the final partial word."""
function Base.iterate(indices::ValidIndices,iteration=(0,UInt64(0)))
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
@inline function or_column!(bits,column,source,words)
    @inbounds @simd for word in 1:words
        bits[word]|=source[word,column]
    end
end

"""Prepare ordered surviving candidate positions for the current x."""
function valid_indices!(bits::DU7Bits,xstate,last,stats)
    words=cld(last,64)
    fill!(bits.bad,0)
    masks,sig=xstate
    for block in 1:4
        mask=masks[block]
        while mask!=0
            p=trailing_zeros(mask)+64(block-1)+1
            or_column!(bits.bad,p,bits.zeroes,words)
            mask&=mask-1
        end
    end
    for p in 1:size(bits.signatures,2)÷8
        value=Int((sig>>(3(p-1)))&7)
        or_column!(bits.bad,8(p-1)+1,bits.signatures,words)
        or_column!(bits.bad,8(p-1)+value+1,bits.signatures,words)
    end
    for word in 1:words
        value=bits.bad[word]
        remainder=last-64(word-1)
        remainder<64 && (value&=(UInt64(1)<<remainder)-1)
        stats.early_rejected+=count_ones(value)
    end
    ValidIndices(bits.bad,last)
end

variant=M.T.replace_once(M.variant,"function du7_v5_extensions(","function bitset_du7_v5_extensions(")
variant=M.T.replace_once(variant,"du7_plan=prepare(C,Cidx,G,L)",
    "du7_plan=prepare(C,Cidx,G,L)\n    du7_bits=du7_plan===nothing ? nothing : DU7Bits(du7_plan)")
variant=M.T.replace_once(variant,"@inbounds for i in 1:last_candidate", """
    candidate_indices=du7_bits===nothing ? (1:last_candidate) :
        valid_indices!(du7_bits,du7_xstate,last_candidate,audit_stats)
    @inbounds for i in candidate_indices""")
variant=M.T.replace_once(variant,"(reject(du7_plan,du7_xstate,du7_plan.states[i]) ? 1 : 0)","0")
Core.eval(@__MODULE__,Meta.parse(variant))
end
