# Implements 2 — Boolean functions; Table 1.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 2 — Boolean functions; Table 1
#
# Pseudocode:
#   1. Read the 150356 primary author Boolean ANF representatives.
#   2. Aggregate exact moment/degree bins below 2 and compare rounded printed bins.
# VBF API used: mobius!, walsh_hadamard, algebraic_degree

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

using Printf
const GL_TABLE1_EXPECTED = Dict((2,"1.0000")=>1,(3,"1.0000")=>3,
    (4,"1.7500")=>8,(4,"1.9375")=>54,
    (5,"1.4688")=>8,(5,"1.6562")=>13,(5,"1.7500")=>17,(5,"1.8438")=>84,(5,"1.9375")=>213,
    (6,"1.6211")=>11,(6,"1.7148")=>10,(6,"1.8086")=>56,(6,"1.9023")=>161,(6,"1.2461")=>4,(6,"1.9961")=>444)

"""Recompute Table 1 from the primary Boolean classification, with exact moments."""
function gl_table1(;path=joinpath(@__DIR__, "input", "author_data", "class-2-6.txt"),
    limit=150356,timeout_seconds=60,save_results=false)
    started=time_ns()
    limit>=0 && timeout_seconds>=0 || throw(ArgumentError("invalid bounds"))
    input=gl_author_boolean_classes(path;limit,timeout_seconds)
    bins=Dict{Tuple{Int,Rational{Int128}},Int}()
    processed=0
    for f in input.functions
        (time_ns()-started)*1e-9>=timeout_seconds && break
        k=gl_kappa(f)
        if k<2
            key=(algebraic_degree(f),k)
            bins[key]=get(bins,key,0)+1
        end
        processed+=1
    end
    complete=processed==150356 && input.sha256=="74cee20ea2db689ea6cebe4cc4f482e44d64eae4444b83cb93a32a425ce43628"
    rounded=Dict((d,@sprintf("%.4f",Float64(k)))=>c for ((d,k),c) in bins)
    agrees=complete && rounded==GL_TABLE1_EXPECTED
    rows=[(;degree=d,moment=k,count=c) for ((d,k),c) in sort!(collect(bins);by=first)]
    r=(;parameters=(;limit,timeout_seconds,input_file=relpath(path,@__DIR__)),complete,processed,agrees,rows,source_sha256=input.sha256,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :budget)
    gl_save("table1",r;save_results)
    return r
end

function gl_table1_report(io::IO=stdout;kwargs...)
    return gl_report("Table 1 — Boolean moments",gl_table1(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table1_report(limit=25)
end
