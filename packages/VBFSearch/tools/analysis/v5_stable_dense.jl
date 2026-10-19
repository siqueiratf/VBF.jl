"""Compose frozen concrete iteration with the existing dense setup helpers.

The stable reference and composed variant are evaluated in the same module to
control for module/code-generation differences. Mathematical decisions, output
sets, observer ordering and cursors remain identical.
"""
module V5StableDense
using VBF,SHA
include(joinpath(@__DIR__,"v5_stable_iterator.jl"))
include(joinpath(@__DIR__,"v5_dense_histogram_helper.jl"))
const S=V5StableIterator
const H=V5DenseHistogramHelper
Core.eval(S,:(const dense_hc_candidates=$(H.dense_hc_candidates)))
Core.eval(S,:(const dense_hg=$(H.dense_hg)))
source=S.replace_once(S.variant,"function stable_v5_extensions(","function stable_dense_v5_extensions(")
source=S.replace_once(source,join([
    "hc = Dict{Int32,Int}()",
    "    X = UInt32[]",
    "    @inbounds for t in 2:length(cnt)",
    "        v = cnt[t]",
    "        hc[v] = get(hc, v, 0) + 1",
    "        v == need * r.scale && push!(X, UInt32(t - 1))",
    "    end"],"\n"), "hc, X = dense_hc_candidates(cnt,r.scale,need,length(R))")
source=S.replace_once(source,join([
    "hg = Dict{Int16,Int}()",
    "    @inbounds for v in g5; hg[v] = get(hg, v, 0) + 1; end"],"\n"), "hg = dense_hg(g5)")
const variant=source
const variant_sha256=bytes2hex(sha256(variant))
Core.eval(S,Meta.parse(variant))
const stable_dense_v5_extensions=S.stable_dense_v5_extensions
end
