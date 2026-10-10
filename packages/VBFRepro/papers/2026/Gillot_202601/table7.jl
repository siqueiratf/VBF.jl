# Implements 8 — Two level; Table 7.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 8 — Two level; Table 7
#
# Pseudocode:
#   1. Check the four exact moment/multiplicity balance equations.
#   2. Count seed classes by exact moments and printed degree restrictions in primary author data.
# VBF API used: walsh_hadamard, algebraic_degree

if !isdefined(@__MODULE__,:gl_kappa)
    include("helpers.jl")
end

const GL_TABLE7_CONFIGURATIONS = [
    (alpha=1//1,A=7,alpha_degrees=[2,3],alpha_classes=4,beta=17//8,B=56,beta_degrees=[4],beta_classes=49),
    (alpha=7//4,A=56,alpha_degrees=[4,5],alpha_classes=25,beta=4//1,B=7,beta_degrees=[2,3],beta_classes=6),
    (alpha=31//16,A=56,alpha_degrees=[4],alpha_classes=54,beta=5//2,B=7,beta_degrees=[3],beta_classes=5),
    (alpha=31//16,A=62,alpha_degrees=[4],alpha_classes=54,beta=47//8,B=1,beta_degrees=[4],beta_classes=19)]

"""Validate exact moment balances and primary author seed counts of GL Table 7."""
function gl_table7(;path=joinpath(@__DIR__,"input","author_data","class-2-6.txt"),
    limit=150356,timeout_seconds=60,save_results=false)
    started=time_ns()
    input=gl_author_boolean_classes(path;limit,timeout_seconds)
    bins=Dict{Tuple{Int,Rational{Int128}},Int}()
    processed=0
    for f in input.functions
        (time_ns()-started)*1e-9>=timeout_seconds && break
        key=(algebraic_degree(f),gl_kappa(f))
        bins[key]=get(bins,key,0)+1
        processed+=1
    end
    rows=[merge(c,(;balance=c.A+c.B==63 && c.A*c.alpha+c.B*c.beta==126,
        alpha_observed=sum(get(bins,(d,c.alpha),0) for d in c.alpha_degrees),
        beta_observed=sum(get(bins,(d,c.beta),0) for d in c.beta_degrees)))
        for c in GL_TABLE7_CONFIGURATIONS]
    complete=processed==150356 && input.sha256=="74cee20ea2db689ea6cebe4cc4f482e44d64eae4444b83cb93a32a425ce43628"
    r=(;parameters=(;limit,timeout_seconds,input_file=relpath(path,@__DIR__)),complete,processed,rows,agrees=complete && all(r.balance &&
        r.alpha_classes==r.alpha_observed && r.beta_classes==r.beta_observed for r in rows),
        source_sha256=input.sha256,elapsed_seconds=(time_ns()-started)*1e-9,
        stop_reason=complete ? :none : :budget)
    gl_save("table7",r;save_results)
    return r
end

function gl_table7_report(io::IO=stdout;kwargs...)
    return gl_report("Table 7 — two-level arithmetic",gl_table7(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table7_report(limit=25)
end
