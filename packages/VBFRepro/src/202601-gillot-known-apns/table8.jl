# Implements 9 — Extension of bent; Table 8.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 9 — Extension of bent; Table 8
#
# Pseudocode:
#   1. Select output component masks whose fourth moment is exactly 1.
#   2. Enumerate all three-dimensional subspaces contained in these masks.
# VBF API used: walsh_hadamard, extract_linear_subspaces_bounded

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

const GL_TABLE8_EXPECTED = Dict(0=>504,8=>99,16=>78,21=>1,24=>21,44=>2,48=>2,60=>2,74=>4,75=>2,140=>1)

"""Count bent three-component spaces exactly, GL Section 9, Table 8."""
function gl_table8(functions=[gold_apn(4)];limit=length(functions),timeout_seconds=60,
    max_nodes=10^7,save_results=false)
    started=time_ns()
    distribution=Dict{Int,Int}()
    processed=0
    total=0
    stage_complete=true
    for F in Iterators.take(functions,limit)
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        remaining<=0 && break
        N=inputbits(F)
        bent=UInt32[b for b in 1:length(F)-1 if gl_kappa(gl_component(F,b))==1]
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        remaining<=0 && break
        spaces=extract_linear_subspaces_bounded(bent,3;max_bits=N,max_nodes,
            timeout_seconds=remaining,algorithm=:optimized)
        if !(spaces isa Exhausted)
            stage_complete=false
            break
        end
        count_spaces=length(search_solutions(spaces))
        distribution[count_spaces]=get(distribution,count_spaces,0)+1
        total+=count_spaces
        processed+=1
    end
    complete=stage_complete && processed==min(limit,length(functions))
    rows=[(;bent_spaces=k,count=v) for (k,v) in sort!(collect(distribution);by=first)]
    r=(;parameters=(;limit,timeout_seconds,max_nodes),complete,processed,input_sha256=gl_dataset_hash(functions),rows,total,full_sixbit=complete && processed==716,
        agrees=complete && distribution==GL_TABLE8_EXPECTED && total==3455,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :budget)
    gl_save("table8",r;save_results)
    return r
end

function gl_table8_report(io::IO=stdout;kwargs...)
    return gl_report("Table 8 — bent component spaces",gl_table8(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table8_report()
end
