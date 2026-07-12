# Top-level report for Budaghyan–Helleseth–Kaleyski (2020).
# Calls all per-claim report functions and prints a summary.

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "observation1.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "table3.jl"))

using Dates

function paper_report(io::IO = stdout)
    print_header(io)
    println(io, "  Date:          ", Dates.today())
    println(io, "  Julia:         ", VERSION)
    println(io, "  Field:         GF(2^10), primitive polynomial 0x", string(primitive_polynomial(10), base=16))
    println(io)
    println(io, "  Reproduction scope:")
    println(io, "    [exact]   Observation 1 — C_3, C_7 APN verification")
    println(io, "    [exact]   Proposition 1 — E_i criterion, all i ∈ 1..9")
    println(io, "    [exact]   Theorem 4 — four i-values give trivial E_i solutions")
    println(io, "    [loaded]  Table III Γ-ranks — n=10 requires Magma (2^20×2^20 matrix)")
    println(io, "    [exact]   EA-mugshot comparison for C_3, C_7 vs. known functions")

    observation1_report(io)
    proposition1_report(io)
    theorem4_report(io)
    table3_report(io)

    println(io)
    println(io, "=" ^ 72)
    println(io, "Report complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
