# Implements 4 — Spectral moments; Lemma 1.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 4 — Spectral moments; Lemma 1
#
# Pseudocode:
#   1. Compute exact fourth moments of every nonzero component of an even APN.
#   2. Verify the APN moment sum and the existence of at least two levels.
# VBF API used: differential_uniformity, walsh_hadamard

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

"""Verify GL Lemma 1 and the exact APN fourth-moment identity on finite even inputs."""
function gl_lemma1(functions=[gold_apn(4)];limit=length(functions),timeout_seconds=60,save_results=false)
    started=time_ns()
    rows=NamedTuple[]
    for F in Iterators.take(functions,limit)
        (time_ns()-started)*1e-9>=timeout_seconds && break
        iseven(inputbits(F)) && differential_uniformity(F)==2 || throw(ArgumentError("requires even-dimensional APN"))
        moments=[gl_kappa(gl_component(F,b)) for b in 1:length(F)-1]
        push!(rows,(;levels=length(Set(moments)),identity=sum(moments)==2(length(F)-1)))
    end
    r=(;parameters=(;limit,timeout_seconds),complete=length(rows)==min(limit,length(functions)),processed=length(rows),
        verified=all(row.levels>=2 && row.identity for row in rows),rows,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=length(rows)==min(limit,length(functions)) ? :none : :time)
    gl_save("lemma1",r;save_results)
    return r
end

function gl_lemma1_report(io::IO=stdout;kwargs...)
    return gl_report("Lemma 1 — even moment levels",gl_lemma1(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_lemma1_report()
end
