"""Isolated V5 histogram prototype, derived from a pinned pre-optimization source.

Only two histogram accumulators and their serialization input are replaced.
The source guard fails if either upstream fragment changes. No mathematical
kernel, cursor, cap, selected scope, observer, or completion operation changes.
After native adoption, set both `VBF_V5_HISTOGRAM_SOURCE` and its exact
`VBF_V5_HISTOGRAM_SHA256`; opt-in tests use checked historical fixtures.
"""
module V5DenseHistogram
using VBF,SHA
using VBF.QuadraticExtensions
const Q=VBF.QuadraticExtensions
const hist_key=Q.hist_key
const par=Q.par
const solve_ones=Q.solve_ones
const sort3=Q.sort3
const pext=Q.pext

function replace_once(source,old,new)
    length(findall(old,source))==1 || error("upstream histogram fragment changed")
    replace(source,old=>new;count=1)
end

"Apply the dense-only substitutions to a source-derived V5 variant."
function dense_histogram_source(source)
    source=replace_once(source,"hc = Dict{Int32,Int}()", """
        hc = zeros(Int, (1 << length(R)) + 1)
        hc_overflow = Dict{Int32,Int}()
        histogram_shift = ispow2(r.scale) ? trailing_zeros(r.scale) : -1""")
    source=replace_once(source,"hc[v] = get(hc, v, 0) + 1", """
        histogram_bin = histogram_shift >= 0 ? Int(v) >> histogram_shift : Int(v) ÷ r.scale
        histogram_exact = histogram_shift >= 0 ? (Int(v) & (r.scale-1)) == 0 : rem(Int(v),r.scale) == 0
        if histogram_exact && 0 <= histogram_bin < length(hc)
            hc[histogram_bin+1] += 1
        else
            hc_overflow[v] = get(hc_overflow,v,0) + 1
        end""")
    source=replace_once(source,"hg = Dict{Int16,Int}()", "hg = zeros(Int, 65536)")
    source=replace_once(source,"@inbounds for v in g5; hg[v] = get(hg, v, 0) + 1; end",
        "@inbounds for v in g5; hg[Int(v) + 32769] += 1; end")
    source=replace_once(source,
        "key = hist_key(Dict(vcat([(Int(k), v) for (k, v) in hc], [(100_000_000 + Int(k), v) for (k, v) in hg])))",
        """key = hist_key(Dict(vcat(
            [((i-1)*r.scale, hc[i]) for i in eachindex(hc) if hc[i] != 0],
            [(Int(k),v) for (k,v) in hc_overflow],
            [(100_000_000 + i - 32769, hg[i]) for i in eachindex(hg) if hg[i] != 0])))""")
    source
end

const source_file=abspath(get(ENV,"VBF_V5_HISTOGRAM_SOURCE",
    joinpath(dirname(pathof(VBF)),"constructions","quadratic_extensions.jl")))
const source_sha256=bytes2hex(open(SHA.sha256,source_file))
if haskey(ENV,"VBF_V5_HISTOGRAM_SOURCE")
    source_sha256==get(ENV,"VBF_V5_HISTOGRAM_SHA256","") ||
        error("explicit histogram baseline requires its exact VBF_V5_HISTOGRAM_SHA256")
end
const installed_source=read(source_file,String)
const fragment=match(r"function v5_extensions\(.*?(?=\n\"\"\"Construct)"s,installed_source)
fragment===nothing && error("cannot locate installed V5 kernel")
const variant=dense_histogram_source(replace_once(String(fragment.match),
    "function v5_extensions(","function dense_v5_extensions("))
const variant_sha256=bytes2hex(sha256(variant))
Core.eval(@__MODULE__,Meta.parse(variant))
const original_variant=replace_once(String(fragment.match),
    "function v5_extensions(","function original_v5_extensions(")
const original_variant_sha256=bytes2hex(sha256(original_variant))
Core.eval(@__MODULE__,Meta.parse(original_variant))
end
