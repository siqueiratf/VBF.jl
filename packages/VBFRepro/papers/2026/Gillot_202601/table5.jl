# Implements 5.4 — Counting function; Table 5.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 5.4 — Counting function; Table 5
#
# Pseudocode:
#   1. Build all nonzero derivative-support Boolean counting functions.
#   2. Preserve their full degree distributions and compare the printed partial table.
# VBF API used: differential_uniformity, algebraic_degree

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

if !isdefined(@__MODULE__,:gl_counting_functions)
    include("section3.jl")
end
const GL_TABLE5_PRINTED = Dict((2,63,0,0)=>13,(3,13,50,0)=>3,(3,15,48,0)=>3,
    (3,21,42,0)=>1,(3,3,60,0)=>114,(3,5,58,0)=>219,(3,7,56,0)=>117,
    (3,9,54,0)=>31,(4,7,0,56)=>2)

"""Fresh full counting-degree census for GL Table 5 and Fact 2."""
function gl_table5(functions=[gold_apn(4)];limit=length(functions),timeout_seconds=60,save_results=false)
    started=time_ns()
    distribution=Dict{Tuple{Int,Tuple},Int}()
    processed=0
    affine_count=0
    for F in Iterators.take(functions,limit)
        (time_ns()-started)*1e-9>=timeout_seconds && break
        functions_u=gl_counting_functions(F;verify_identity=false).functions
        degrees=[algebraic_degree(f) for f in functions_u]
        key=(algebraic_degree(F),Tuple(count(==(d),degrees) for d in 0:inputbits(F)))
        distribution[key]=get(distribution,key,0)+1
        any(<=(1),degrees) && (affine_count+=1)
        processed+=1
    end
    complete=processed==min(limit,length(functions))
    rows=[(;apn_degree=key[1],degree_counts=collect(key[2]),count=value)
        for (key,value) in sort!(collect(distribution);by=first)]
    r=(;parameters=(;limit,timeout_seconds),complete,processed,input_sha256=gl_dataset_hash(functions),rows,all_affine=affine_count==processed,
        full_sixbit=complete && processed==716,published_multiplicity_sum=sum(values(GL_TABLE5_PRINTED)),
        matches_printed=false,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :time)
    gl_save("table5",r;save_results)
    return r
end

function gl_table5_report(io::IO=stdout;kwargs...)
    return gl_report("Table 5 — counting-function degrees",gl_table5(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table5_report()
end
