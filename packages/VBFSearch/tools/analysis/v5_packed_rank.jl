"""Exact two-bit polar-rank experiment; all ranks originate in VBF's rank table.

Nonzero alternating forms in at most eight variables have ranks 2, 4, 6 or 8.
Encode rank/2-1 in two bits, with the unique zero form handled explicitly.
Only the rank lookup in a frozen source-derived Fourier preparation changes.
"""
module V5PackedRank
using VBF,SHA
using VBF.QuadraticExtensions
const Q=VBF.QuadraticExtensions
for name in (:hist_key,:par,:solve_ones,:sort3,:pext,:pivots_masks,:_du7_prepare,:_DU7Bits,
        :_du7_state,:_du7_valid_indices!,:_du7_triangle_reject,:_DU7ValidIndices,
        :_v5_bent_histogram,:_v5_flat_histogram,:_solve_ones_annihilating,
        :_PolarRankLookup,:_polar_rank)
    @eval const $name=getproperty(Q,$(QuoteNode(name)))
end

struct PackedPolarRanks
    n::Int
    codes::Vector{UInt8}
    function PackedPolarRanks(full::Q.PolarRankTable)
        count=length(full.ranks);codes=zeros(UInt8,cld(count,4))
        @inbounds for byte in eachindex(codes)
            word=UInt8(0)
            for part in 0:3
                q=4(byte-1)+part
                (q==0 || q>=count) && continue
                rank=full.ranks[q+1]
                rank in (2,4,6,8) || error("invalid nonzero alternating-form rank")
                word|=((rank>>1)-UInt8(1))<<(2part)
            end
            codes[byte]=word
        end
        new(full.n,codes)
    end
end

@inline function packed_rank(table::PackedPolarRanks,q::UInt32)
    iszero(q) && return 0
    index=Int(q)
    @inbounds code=(table.codes[(index>>2)+1]>>(2(index&3)))&UInt8(3)
    2(Int(code)+1)
end

function replace_once(source,old,new)
    length(findall(old,source))==1 || error("frozen rank-lookup source changed")
    replace(source,old=>new;count=1)
end
const source_file=abspath(get(ENV,"VBF_PACKED_RANK_BASELINE",
    joinpath(dirname(pathof(VBF)),"constructions","quadratic_extensions.jl")))
const source_sha256=bytes2hex(open(SHA.sha256,source_file))
const source=read(source_file,String)
const coset_fragment=match(r"function coset_bent_counts!\(.*?(?=\n# --- extensions through)"s,source)
coset_fragment===nothing && error("cannot locate Fourier preparation")
coset=replace_once(String(coset_fragment.match),"function coset_bent_counts!(","function packed_coset_bent_counts!(")
coset=replace_once(coset,"rank_table::Union{Nothing,_PolarRankLookup}=nothing","rank_table::PackedPolarRanks")
coset=replace_once(coset,
    "rk=rank_table===nothing ? form_rank(G,y) : _polar_rank(rank_table,y)",
    "rk=packed_rank(rank_table,y)")
const coset_variant=coset
Core.eval(@__MODULE__,Meta.parse(coset_variant))
const main_fragment=match(r"function v5_extensions\(.*?(?=\n\"\"\"Construct)"s,source)
main_fragment===nothing && error("cannot locate native V5 body")
const clone=replace_once(String(main_fragment.match),"function v5_extensions(","function clone_v5_extensions(")
Core.eval(@__MODULE__,Meta.parse(clone))
variant=replace_once(String(main_fragment.match),"function v5_extensions(","function packed_v5_extensions(")
variant=replace_once(variant,"rank_table::Union{Nothing,_PolarRankLookup}=nothing","rank_table::PackedPolarRanks")
variant=replace_once(variant,"r = coset_bent_counts!(work.cnt, G, V5, beta;rank_table)",
    "r = packed_coset_bent_counts!(work.cnt, G, V5, beta;rank_table)")
const main_variant=variant
const variant_sha256=bytes2hex(sha256(coset_variant*"\n"*main_variant))
Core.eval(@__MODULE__,Meta.parse(main_variant))
end
