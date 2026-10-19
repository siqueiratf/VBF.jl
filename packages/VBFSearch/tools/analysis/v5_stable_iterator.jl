"""Isolated concrete-iterator experiment for the current native V5 algorithm.

The mathematical filter and existing iterator implementation are unchanged.
Both branches now produce `_DU7ValidIndices`, including an all-zero rejection
bitmap for the unfiltered fallback, so iteration state has one concrete type.
After the native loop has been repaired, set `VBF_ITERATOR_BASELINE` to the
archived pre-repair `quadratic_extensions.jl` and `VBF_ITERATOR_BASELINE_SHA256`
to its exact digest; source guards reject reinjection.
"""
module V5StableIterator
using VBF,SHA
using VBF.QuadraticExtensions
const Q=VBF.QuadraticExtensions
for name in (:hist_key,:par,:solve_ones,:sort3,:pext,:_du7_prepare,:_DU7Bits,
        :_du7_state,:_du7_valid_indices!,:_du7_triangle_reject,:_DU7ValidIndices)
    @eval const $name=getproperty(Q,$(QuoteNode(name)))
end
function replace_once(source,old,new)
    length(findall(old,source))==1 || error("upstream iterator fragment changed")
    replace(source,old=>new;count=1)
end
const source_file=abspath(get(ENV,"VBF_ITERATOR_BASELINE",
    joinpath(dirname(pathof(VBF)),"constructions","quadratic_extensions.jl")))
const source_sha256=bytes2hex(open(SHA.sha256,source_file))
if haskey(ENV,"VBF_ITERATOR_BASELINE")
    source_sha256==get(ENV,"VBF_ITERATOR_BASELINE_SHA256","") ||
        error("explicit iterator baseline requires its exact VBF_ITERATOR_BASELINE_SHA256")
end
const fragment=match(r"function v5_extensions\(.*?(?=\n\"\"\"Construct)"s,read(source_file,String))
fragment===nothing && error("cannot locate native V5 loop")
const original=String(fragment.match)
const baseline=replace_once(original,"function v5_extensions(","function baseline_v5_extensions(")
Core.eval(@__MODULE__,Meta.parse(baseline))
source=replace_once(original,"function v5_extensions(","function stable_v5_extensions(")
source=replace_once(source,"du7_bits=du7_plan===nothing ? nothing : _DU7Bits(du7_plan)",
    "du7_bits=du7_plan===nothing ? nothing : _DU7Bits(du7_plan)\n    unfiltered_bad=du7_bits===nothing ? zeros(UInt64,cld(length(L),64)) : UInt64[]")
source=replace_once(source,"candidate_indices=du7_bits===nothing ? (1:last_candidate) :",
    "candidate_indices=du7_bits===nothing ? _DU7ValidIndices(unfiltered_bad,last_candidate) :")
const variant=source
const variant_sha256=bytes2hex(sha256(variant))
Core.eval(@__MODULE__,Meta.parse(variant))
end
