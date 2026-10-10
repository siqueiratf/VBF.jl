# Implements 5.5 — Proposition 1.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 5.5 — Proposition 1
#
# Pseudocode:
#   1. Select finite APN inputs with exact component moment levels {1,4}.
#   2. Check that each selected input is quadratic; do not infer a universal proof.
# VBF API used: walsh_hadamard, algebraic_degree

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

"""Check GL Proposition 1 on a stated finite input set, without claiming a universal proof."""
function gl_proposition1(functions=[gold_apn(4)];limit=length(functions),timeout_seconds=60,save_results=false)
    started=time_ns()
    processed=0
    selected=0
    verified=true
    for F in Iterators.take(functions,limit)
        (time_ns()-started)*1e-9>=timeout_seconds && break
        levels=Set(gl_kappa(gl_component(F,b)) for b in 1:length(F)-1)
        if levels==Set([1//1,4//1])
            selected+=1
            verified &= algebraic_degree(F)==2
        end
        processed+=1
    end
    complete=processed==min(limit,length(functions))
    r=(;parameters=(;limit,timeout_seconds),complete,processed,input_sha256=gl_dataset_hash(functions),selected,verified,universal_proof=false,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :time)
    gl_save("proposition1",r;save_results)
    return r
end

function gl_proposition1_report(io::IO=stdout;kwargs...)
    return gl_report("Proposition 1 — finite type (1,4) check",gl_proposition1(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_proposition1_report()
end
