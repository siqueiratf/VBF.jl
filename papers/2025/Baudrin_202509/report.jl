# Implements the bounded report for Sections 3.1–3.2 and Conjecture 1.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3 — Towards a Practical Classification of all Known APN Functions
#
# Pseudocode:
#   1. Print source, environment and bounded execution scope.
#   2. Run small Section 3.1, Section 3.2 and Conjecture 1 demonstrations.
#   3. State that the seven-bit census and exhaustive classification are not run.
# VBF API used: print_banner, print_section, print_kv
include(joinpath(@__DIR__, "section31.jl"))
include(joinpath(@__DIR__, "section32.jl"))
include(joinpath(@__DIR__, "conjecture1.jl"))

"""Print bounded reproduction results for Baudrin–Galissant–Perrin (2025)."""
function paper_report(io::IO=stdout; seed=940, kwargs...)
    paper_header(io)
    section31_report(io; seed)
    section32_report(io; dimension=4, seed)
    conjecture1_report(io; seed)
    print_kv(io, "full seven-bit census", "not run")
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
