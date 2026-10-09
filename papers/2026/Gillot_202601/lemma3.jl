# Implements 8 — Two-level APNs; Lemma 3.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 8 — Two-level APNs; Lemma 3
#
# Pseudocode:
#   1. Measure the rectangular differential uniformity by a square embedding.
#   2. Compare it with the exact necessary bound 2^(m−n+1).
# VBF API used: apn_extension_tests, differential_uniformity

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

"""Run the necessary APN-extension test of GL Lemma 3."""
function gl_lemma3(G=VBFTable{3,1}(Int.(gold_apn(3).lut).>>2);max_nodes=10^6,timeout_seconds=60,save_results=false)
    started=time_ns()
    outcome=apn_extension_tests(G;max_nodes,timeout_seconds)
    complete=outcome isa Exhausted
    r=(;parameters=(;max_nodes,timeout_seconds),complete,processed=nodes_visited(outcome),tests=complete ? only(search_solutions(outcome)) : nothing,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : outcome.where_it_stopped.reason)
    gl_save("lemma3",r;save_results)
    return r
end

function gl_lemma3_report(io::IO=stdout;kwargs...)
    return gl_report("Lemma 3 — necessary extension test",gl_lemma3(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_lemma3_report()
end
