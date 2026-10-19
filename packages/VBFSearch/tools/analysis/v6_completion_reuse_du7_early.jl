"""Early exact DU7 filter before the random partner-Walsh lookup.

This variant preserves all completion sets, caps, logical coset indices and
cursors. Its ncand counts candidates surviving the DU7 prefilter; baseline
ncand included candidates whose completion systems are already impossible.
The separate early_rejected counter counts loop items, including items that
would later have failed the Fourier gate; it is not a baseline candidate count.
"""
module V6CompletionReuseDU7Early
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

"""Actual downstream work and early rejected loop items."""
Base.@kwdef mutable struct TriangleStats
    candidates::Int=0
    rejected::Int=0
    pair_tests::Int=0
    pairs::Int=0
    cosets::Int=0
    early_rejected::Int=0
end

variant=M.T.replace_once(M.variant,"function du7_v5_extensions(","function early_du7_v5_extensions(")
variant=M.T.replace_once(variant,"b = Int(g5[tx+1])", """
    if du7_plan!==nothing
        audit_stats.pair_tests+=1
        if reject(du7_plan,du7_xstate,du7_plan.states[i])
            audit_stats.early_rejected+=1
            continue
        end
    end
    b = Int(g5[tx+1])""")
variant=M.T.replace_once(variant,"(reject(du7_plan,du7_xstate,du7_plan.states[i]) ? 1 : 0)","0")
Core.eval(@__MODULE__,Meta.parse(variant))
end
