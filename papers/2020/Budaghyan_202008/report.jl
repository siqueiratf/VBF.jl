# Top-level paper report for Budaghyan et al. (2020).
# Paper: "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section4.jl"))
include(joinpath(@__DIR__, "section5.jl"))
include(joinpath(@__DIR__, "section6.jl"))
include(joinpath(@__DIR__, "section7.jl"))
include(joinpath(@__DIR__, "table1.jl"))
using Dates

"""
    paper_report(io = stdout)

Print a full reproduction report for Budaghyan et al. (2020).
Scope:
  - Exact:   Theorem IV.1, Corollary IV.2, Proposition V.3, Lemma VI.6
  - Exact:   Theorem VI.3 new n=9 APN (explicit parameters from Section VII-B)
  - Bounded: Section VII-D n=6 monomial-shift coverage (1-term L only)
  - Loaded:  x⁹ + Tr(x³) over GF(2^8) verified APN (reference function)
  - Not run: Full n=6..12 search (exhaustive, computationally heavy)
  - Not run: Γ-rank computation (requires n=9 size matrices, out-of-scope)
"""
function paper_report(io::IO = stdout)
    n9_mod = primitive_polynomial(9)
    print_header(io, "Budaghyan et al. (2020) — Isotopic Shifts", 9, n9_mod)
    println(io)
    println(io, "Scope:")
    println(io, "  Exact:   Theorem IV.1, Corollary IV.2, Proposition V.3, Lemma VI.6")
    println(io, "  Exact:   Theorem VI.3 new n=9 APN (Section VII-B explicit params)")
    println(io, "  Bounded: Section VII-D n=6 monomial-shift coverage (1-term L)")
    println(io, "  Loaded:  x⁹ + Tr(x³) over GF(2^8) verified APN")
    println(io, "  Not run: full n=6..12 exhaustive search")
    println(io, "  Not run: Γ-rank (n=9 matrix too large for this VBF build)")

    section4_report(io)
    section5_report(io)
    section6_report(io)
    section7_report(io)
    table1_report(io)

    println(io)
    println(io, "=" ^ 64)
    println(io, "Done.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
