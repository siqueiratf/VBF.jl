"""Dense V5 histograms confined to non-inlined setup helpers.

The main completion loop keeps the original Dict types and serialization.
The dense buffers and binning variables live only in the setup helpers.
"""
module V5DenseHistogramHelper
using VBF,SHA
using VBF.QuadraticExtensions
include(joinpath(@__DIR__,"v5_dense_histogram.jl"))
const Q=VBF.QuadraticExtensions
const hist_key=Q.hist_key
const par=Q.par
const solve_ones=Q.solve_ones
const sort3=Q.sort3
const pext=Q.pext

Base.@noinline function dense_hc_candidates(cnt,scale,need,d)
    bins=zeros(Int,(1<<d)+1);overflow=Dict{Int32,Int}();X=UInt32[]
    shift=ispow2(scale) ? trailing_zeros(scale) : -1
    @inbounds for t in 2:length(cnt)
        v=cnt[t]
        bin=shift>=0 ? Int(v)>>shift : Int(v)÷scale
        exact=shift>=0 ? (Int(v)&(scale-1))==0 : rem(Int(v),scale)==0
        if exact && 0<=bin<length(bins)
            bins[bin+1]+=1
        else
            overflow[v]=get(overflow,v,0)+1
        end
        v==need*scale && push!(X,UInt32(t-1))
    end
    h=Dict{Int32,Int}(Int32((i-1)*scale)=>bins[i] for i in eachindex(bins) if bins[i]>0)
    merge!(h,overflow)
    return h,X
end

Base.@noinline function dense_hg(g5)
    bins=zeros(Int,65536)
    @inbounds for v in g5;bins[Int(v)+32769]+=1;end
    return Dict{Int16,Int}(Int16(i-32769)=>bins[i] for i in eachindex(bins) if bins[i]>0)
end

const source_file=V5DenseHistogram.source_file
const source_sha256=V5DenseHistogram.source_sha256
const original=String(V5DenseHistogram.fragment.match)
source=V5DenseHistogram.replace_once(original,"function v5_extensions(","function dense_v5_extensions(")
source=V5DenseHistogram.replace_once(source,join([
    "hc = Dict{Int32,Int}()",
    "    X = UInt32[]",
    "    @inbounds for t in 2:length(cnt)",
    "        v = cnt[t]",
    "        hc[v] = get(hc, v, 0) + 1",
    "        v == need * r.scale && push!(X, UInt32(t - 1))",
    "    end"],"\n"), "hc, X = dense_hc_candidates(cnt,r.scale,need,length(R))")
source=V5DenseHistogram.replace_once(source,join([
    "hg = Dict{Int16,Int}()",
    "    @inbounds for v in g5; hg[v] = get(hg, v, 0) + 1; end"],"\n"), "hg = dense_hg(g5)")
const variant=source
const variant_sha256=bytes2hex(sha256(variant))
Core.eval(@__MODULE__,Meta.parse(variant))
end
