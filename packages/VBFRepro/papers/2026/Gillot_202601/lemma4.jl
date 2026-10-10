# Implements 8 — Two-level APNs; Lemma 4.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 8 — Two-level APNs; Lemma 4
#
# Pseudocode:
#   1. Linearize every zero-flat GF(4)-cube constraint.
#   2. Test affine consistency; preserve budget stops as inconclusive.
# VBF API used: apn_extension_tests

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

"""Run the necessary APN-extension test of GL Lemma 4."""
function gl_lemma4(G=VBFTable{3,1}(Int.(gold_apn(3).lut).>>2);max_nodes=10^6,timeout_seconds=60,save_results=false)
    started=time_ns()
    outcome=apn_extension_tests(G;max_nodes,timeout_seconds)
    complete=outcome isa Exhausted
    r=(;parameters=(;max_nodes,timeout_seconds),complete,processed=nodes_visited(outcome),tests=complete ? only(search_solutions(outcome)) : nothing,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : outcome.where_it_stopped.reason)
    gl_save("lemma4",r;save_results)
    return r
end

function gl_lemma4_report(io::IO=stdout;kwargs...)
    return gl_report("Lemma 4 — necessary extension test",gl_lemma4(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_lemma4_report()
end
