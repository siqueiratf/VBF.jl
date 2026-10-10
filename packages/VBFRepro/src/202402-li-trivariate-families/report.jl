# Top-level paper report for Li & Kaleyski (2024).
# Paper: Li, Kaleyski (2024), "Two New Infinite Families of APN Functions in Trivariate Form"
# Section: All — paper_report() collects results from all claim files
#
# VBF API used: print_banner, print_section, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "proposition4.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))
include(joinpath(@__DIR__, "proposition8.jl"))
include(joinpath(@__DIR__, "section5a.jl"))

"""
    paper_report(; io, full) -> Nothing

Top-level report for Li & Kaleyski (2024). Covers:
- Theorem 1/3 (Family 1 APN + permutation)
- Proposition 4 (explicit i=1, gcd(m,7)=1 case)
- Theorem 6/7 (Family 2 APN + permutation)
- Proposition 8 (explicit i=1, gcd(m,7)=1 case)
- Section 5A Table IV (orthoderivative spectra, n=9)

Set full=true to also run m=5 (n=15), which is slower (~2 min).
"""
function paper_report(; io::IO = stdout, full::Bool = false)
    print_header(io)
    println(io, "Reproduction scope:")
    println(io, "  exact: Theorems 1, 3, 6, 7; Propositions 4, 8; Table IV (Section 5A)")
    println(io, "  bounded: Table V (m≤4 default, m=5 with full=true)")
    println(io, "  out-of-scope: Section 5C exhaustive search (m≤5, 2^45 candidates)")
    println(io, "  Julia version: ", VERSION)
    println(io)

    # --- Theorem 1 & 3 — Family 1 ---
    theorem1_report(m = 3, i = 1, io = io)   # Proposition 4 case (n=9, permutation)
    theorem1_report(m = 3, i = 2, io = io)   # second i value (n=9, permutation)
    theorem1_report(m = 4, i = 1, io = io)   # n=12, not perm (m/k=4 even)
    theorem1_report(m = 4, i = 3, io = io)   # n=12, k=gcd(3,4)=1, perm
    if full
        for ii in 1:4
            theorem1_report(m = 5, i = ii, io = io)
        end
    end

    # --- Proposition 4 ---
    proposition4_report(ms = [3, 5, 6], io = io)

    # --- Theorem 6 & 7 — Family 2 ---
    theorem6_report(m = 3, i = 1, io = io)
    theorem6_report(m = 3, i = 2, io = io)
    theorem6_report(m = 4, i = 1, io = io)
    theorem6_report(m = 4, i = 3, io = io)
    if full
        for ii in 1:4
            theorem6_report(m = 5, i = ii, io = io)
        end
    end

    # --- Proposition 8 ---
    proposition8_report(ms = [3, 5, 6], io = io)

    # --- Section 5A — Table IV ---
    section5a_report(io = io)

    println(io)
    print_banner(io, "Report complete.")
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
