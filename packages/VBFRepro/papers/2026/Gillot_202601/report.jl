# Implements 2–9 — Practical finite checks and bounded experimental evaluation.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 2–9 — Practical finite checks and bounded experimental evaluation
#
# Pseudocode:
#   1. Run small exact moment, kernel and counting checks.
#   2. Label separate expensive targets and keep the global conjectures unproved.
# VBF API used: print_banner, print_check, print_section, print_kv

include("lemma1.jl")
include("lemma2.jl")
include("lemma3.jl")
include("lemma4.jl")
include("section3.jl")
include("table1.jl")

"""Run inexpensive exact GL checks and label expensive tables without launching them."""
function paper_report(io::IO=stdout)
    paper_header(io)
    results=(;lemma1=gl_lemma1(),lemma2=gl_lemma2(),lemma3=gl_lemma3(),lemma4=gl_lemma4(),
        counting=gl_section3())
    print_check(io,"Lemma 1 finite moment identity",results.lemma1.verified)
    print_check(io,"Lemma 2 trivial kernel dimension",results.lemma2.trivial_dimension_checked)
    print_check(io,"Counting-function Walsh identity",results.counting.identity_checked)
    path=joinpath(@__DIR__,"input","author_data","class-2-6.txt")
    if isfile(path)
        r=gl_table1(path=path,limit=25,timeout_seconds=5)
        gl_report("Table 1 — loaded author artifact prefix",r,io)
    else
        print_kv(io,"Table 1","author dataset unavailable; use fetch_inputs")
    end
    print_kv(io,"Tables 2–9","separate bounded targets; full_search enables all supplied inputs")
    print_kv(io,"Global conjectures","not proved by finite closure computations")
    return results
end
if abspath(PROGRAM_FILE)==@__FILE__
    paper_report()
end
