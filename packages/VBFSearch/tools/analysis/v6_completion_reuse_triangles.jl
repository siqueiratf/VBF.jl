"""Minimal offline variant of the existing V5 loop with an odd-circuit filter.

For flats c1,c2,c3 with c1+c2+c3=0, a candidate t annihilating c1,c2
also annihilates c3. Its completion equations c⋅v=1 then contain 0=1.
Three flats through one input point in a DU≤8 U6 provide these circuits.
The instrumented function below is generated from the exact installed VBF
source; all other mathematics, Fourier transforms and solving remain VBF's.
"""
module V6CompletionReuseTriangles
using VBF, SHA
using VBF.QuadraticExtensions
const Q=VBF.QuadraticExtensions
const hist_key=Q.hist_key
const par=Q.par
const solve_ones=Q.solve_ones
const sort3=Q.sort3
const pext=Q.pext

"""Work counters for logical candidates and certified skipped solves."""
Base.@kwdef mutable struct TriangleStats
    candidates::Int=0
    rejected::Int=0
    pair_tests::Int=0
    pairs::Int=0
    cosets::Int=0
end

"""First odd three-circuit annihilated by t, or zero if none was found."""
@inline function triangle_rejection(pairs,t)
    @inbounds for i in eachindex(pairs)
        a,b=pairs[i]
        !par(a&t) && !par(b&t) && return i
    end
    0
end

"""Replace one known source fragment, failing on upstream drift."""
function replace_once(source,old,new)
    length(findall(old,source))==1 || error("upstream V5 source fragment changed")
    replace(source,old=>new;count=1)
end

const source_file=get(ENV,"VBF_V5_BASELINE_SOURCE",
    joinpath(dirname(pathof(VBF)),"constructions","quadratic_extensions.jl"))
const source_sha256=bytes2hex(open(SHA.sha256,source_file))
source_sha256==get(ENV,"VBF_V5_BASELINE_SHA256",
    "b90eaee972f215f465b0ab590c5e28295a841baedcafa66b1ea7cd24a66cc3a1") ||
    error("baseline source changed; supply VBF_V5_BASELINE_SOURCE and VBF_V5_BASELINE_SHA256 explicitly")
source=read(source_file,String)
fragment=match(r"function v5_extensions\(.*?(?=\n\"\"\"Construct)"s,source)
fragment===nothing && error("cannot locate installed V5 kernel")
reference_variant=replace_once(String(fragment.match),"function v5_extensions(",
    "function reference_v5_extensions(")
Core.eval(@__MODULE__,Meta.parse(reference_variant))
variant=String(fragment.match)
variant=replace_once(variant,"function v5_extensions(","function triangle_v5_extensions(")
variant=replace_once(variant,"selected_coset_indices = nothing)",
    "selected_coset_indices = nothing, audit_stats::TriangleStats = TriangleStats())")
variant=replace_once(variant,"Z = UInt32[]; pts = work.pts", """
    Z = UInt32[]; pts = work.pts
    triangle_pairs = NTuple{2,UInt32}[]
    triangle_first = zeros(UInt32,1 << G.n)
    triangle_second = zeros(UInt32,1 << G.n)""")
variant=replace_once(variant,"du_filter && fill!(pts, 0)",
    "fill!(pts, 0); empty!(triangle_pairs)")
du_fragment=match(r"(?ms)^            if du_filter[^\n]*\n.*?^            end",variant)
du_fragment===nothing && error("cannot locate original DU block")
variant=replace_once(variant,String(du_fragment.match), """
            for p in G.flatpts[fi]
                pts[p+1] += 1
                degree=pts[p+1]
                if degree==1
                    triangle_first[p+1]=c
                elseif degree==2
                    triangle_second[p+1]=c
                elseif degree==3 && triangle_first[p+1] ⊻ triangle_second[p+1] == c
                    push!(triangle_pairs,(triangle_first[p+1],triangle_second[p+1]))
                end
                if du_filter && degree>3
                    bad=true
                    break
                end
            end
            bad && break""")
variant=replace_once(variant,"empty!(Tseen)\n        last_candidate=", """
        empty!(Tseen)
        audit_stats.cosets+=1
        audit_stats.pairs+=length(triangle_pairs)
        last_candidate=""")
variant=replace_once(variant,"ncand += 1\n            empty!(Z)", """
            ncand += 1
            audit_stats.candidates+=1
            rejected_at=triangle_rejection(triangle_pairs,t)
            audit_stats.pair_tests+=rejected_at==0 ? length(triangle_pairs) : rejected_at
            if rejected_at!=0
                audit_stats.rejected+=1
                continue
            end
            empty!(Z)""")
Core.eval(@__MODULE__,Meta.parse(variant))

end
