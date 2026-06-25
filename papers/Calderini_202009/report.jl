# Implements paper_report() for Calderini (2020) reproduction.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Cryptography and Communications 12:821-840
#
# VBF API used: see individual section files

include(joinpath(@__DIR__, "section3.jl"))
include(joinpath(@__DIR__, "section4.jl"))
include(joinpath(@__DIR__, "section5.jl"))
include(joinpath(@__DIR__, "section6.jl"))

using Dates

function print_header(io::IO = stdout)
    println(io, "=" ^ 70)
    println(
        io,
        "Calderini (2020) — On the EA-classes of known APN functions in small dimensions",
    )
    println(io, "Cryptography and Communications 12:821-840")
    println(io, "Julia $(VERSION)  |  $(Dates.today())")
    println(io, "=" ^ 70)
    println(io, "Reproduction scope:")
    println(
        io,
        "  EXACT:     Observation 1, Corollary 1 (n=4,5), C₁..C₄ dimensions,",
    )
    println(
        io,
        "             Section 5.1 properties, Theorem 7 (n=5,6), Theorem 8 (n=5)",
    )
    println(io, "  LOADED:    Table 1 catalog mapping (EA counts require MAGMA)")
    println(io, "  OUT-SCOPE: Tables 2/3/4 (Walsh-zero enumeration n≥7 too slow)")
    println(io, "=" ^ 70)
end

"""
    paper_report(io; limit)

Aggregate report for Calderini (2020). Runs in a few minutes.
`limit` controls the permutation EA/affine-class deduplication budget in Section 5.1.
"""
function paper_report(io::IO = stdout; limit::Int = 32)
    print_header(io)
    section3_report(io)
    section4_report(io)
    section5_report(io; limit)
    section6_report(io)
    println(io, "\n" * "=" ^ 70)
    println(io, "Report complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
