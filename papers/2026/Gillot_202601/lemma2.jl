# Implements 6 — Switchings; Lemma 2.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 6 — Switchings; Lemma 2
#
# Pseudocode:
#   1. Project away one output coordinate and solve the full affine flat system.
#   2. Compare full kernel dimension with 2m and the normalized quotient.
# VBF API used: apn_extension_space, differential_uniformity

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

"""Compare complete and normalized parity kernels, GL Section 6, Lemma 2."""
function gl_lemma2(F=gold_apn(4);max_nodes=10^6,timeout_seconds=60,save_results=false)
    started=time_ns()
    N=inputbits(F)
    differential_uniformity(F)==2 || throw(ArgumentError("requires APN input"))
    G=VBFTable{N,N-1}(Int.(F.lut).>>1)
    outcome=apn_extension_space(G;max_nodes,timeout_seconds)
    complete=outcome isa Exhausted
    space=complete ? only(search_solutions(outcome)) : nothing
    dimension=complete ? space.kernel_dimension : nothing
    quotient=complete ? space.normalized_dimension : nothing
    r=(;parameters=(;max_nodes,timeout_seconds),complete,processed=nodes_visited(outcome),kernel_dimension=dimension,quotient_dimension=quotient,
        switchable=complete ? dimension>2N : nothing,
        trivial_dimension_checked=complete ? length(space.normalization_points)==2N : false,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : outcome.where_it_stopped.reason)
    gl_save("lemma2",r;save_results)
    return r
end

function gl_lemma2_report(io::IO=stdout;kwargs...)
    return gl_report("Lemma 2 — switching kernel",gl_lemma2(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_lemma2_report()
end
