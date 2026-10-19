"""Offline experiment fusing constraint selection with exact affine elimination.

This preserves the installed V5 traversal and replaces only the gather/solve
pair. A contradictory affine row ends the scan immediately. Production code
must never depend on this source-generated comparison experiment.
"""
module V5FusedSolver
using VBF,SHA
using VBF.QuadraticExtensions
const Q=VBF.QuadraticExtensions
for name in (:hist_key,:par,:solve_ones,:sort3,:pext,:_du7_prepare,:_DU7Bits,
             :_du7_state,:_du7_valid_indices!,:_du7_triangle_reject,:_DU7ValidIndices)
    @eval const $name=Q.$name
end

"""Solve selected nonempty c⋅v=1 constraints, stopping on first contradiction."""
function selected_ones(C,t,D,rows=UInt32[],piv=Int[],K=UInt32[])
    aug=UInt32(1)<<D;mask=aug-UInt32(1)
    empty!(piv);empty!(K);resize!(rows,D);fill!(rows,UInt32(0));found=false
    @inbounds for c in C
        par(c&t) && continue
        found=true;row=c|aug
        while !iszero(row&mask)
            p=trailing_zeros(row&mask)+1;basis=rows[p]
            if iszero(basis)
                rows[p]=row
                break
            end
            row⊻=basis
        end
        row==aug && return nothing
    end
    found || return nothing
    filter!(!iszero,rows)
    rank=Q.rref_from_echelon!(rows);resize!(rows,rank)
    append!(piv,(trailing_zeros(r) for r in rows))
    v0=UInt32(0)
    for (r,p) in zip(rows,piv)
        (r>>D)&1==1 && (v0|=UInt32(1)<<p)
    end
    pivset=UInt32(0)
    for p in piv;pivset|=UInt32(1)<<p;end
    for f in 0:D-1
        (pivset>>f)&1==1 && continue
        k=UInt32(1)<<f
        for (r,p) in zip(rows,piv)
            (r>>f)&1==1 && (k|=UInt32(1)<<p)
        end
        push!(K,k)
    end
    v0,K
end

"""Change exactly one known source fragment, failing on unexpected drift."""
function replace_once(source,old,new)
    length(findall(old,source))==1 || error("installed V5 source fragment changed")
    replace(source,old=>new;count=1)
end
const source_file=get(ENV,"VBF_FUSED_BASELINE_SOURCE",
    joinpath(dirname(pathof(VBF)),"constructions","quadratic_extensions.jl"))
const source_sha256=bytes2hex(open(SHA.sha256,source_file))
source_sha256==get(ENV,"VBF_FUSED_BASELINE_SHA256",
    "80809758434abb24e35b11ad7d863cb2abd641351dc34deb276c639fcbf89aea") ||
    error("fused solver baseline changed; pin the archived pre-fusion source explicitly")
const source=read(source_file,String)
const fragment=match(r"function v5_extensions\(.*?(?=\n\"\"\"Construct)"s,source)
fragment===nothing && error("cannot locate installed V5 kernel")
control=replace_once(String(fragment.match),"function v5_extensions(","function control_v5_extensions(")
Core.eval(@__MODULE__,Meta.parse(control))
variant=replace_once(String(fragment.match),"function v5_extensions(","function fused_v5_extensions(")
selection=match(r"(?ms)^            empty!\(Z\)\n.*?^            sol = solve_ones\(Z, D, srows, spiv, sK\)",variant)
selection===nothing && error("cannot locate installed gather/solve block")
variant=replace_once(variant,String(selection.match),"            sol = selected_ones(Cx, t, D, srows, spiv, sK)")
Core.eval(@__MODULE__,Meta.parse(variant))
end
