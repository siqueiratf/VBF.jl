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
  - Exact:   Theorem IV.1, Corollary IV.2
  - Exact:   Theorem V.1 (i)+(ii), scanned over all 1-/2-term linear L at n=6
  - Exact:   Theorem VI.3 — iff checked on stated finite coefficient scans and controls
  - Exact:   Theorem VI.3 published n=9 APN (explicit parameters from Section VII-B),
             LUT-identical to Table I row 8
  - Exact:   Table I — all 8 rows, pairwise CCZ-inequivalent by ortho-derivative
             mugshot (EA = CCZ for quadratic APN, Yoshiara)
  - Partial: Proposition V.3 (q = 2 only; the paper states it for any prime power q)
  - Partial: Lemma VI.6 (cases (i), (ii), (iv) of 5; (iii) and (v) not implemented)
  - Loaded:  x⁹ + Tr(x³) over GF(2^8) verified APN (the 2006 function itself; the
             paper's isotopic-shift derivation of it is NOT reproduced — README R8)
  - Not run: Section VII-D (every quadratic APN over GF(2⁶) is a shift of x³) —
             needs general linear L (~2³⁶) plus the Proposition VI.1 normalisation
  - Not run: Γ-rank column of Table I (n=8 requires explicit storage/time budgets;
             not needed — the mugshot separates all 8 rows)
"""
function paper_report(io::IO = stdout)
    n9_mod = primitive_polynomial(9)
    print_banner(
        io,
        "Paper: Budaghyan, Calderini, Carlet, Coulter, Villa (2020) —",
        "       Constructing APN Functions Through Isotopic Shifts.",
        "       IEEE Trans. Inf. Theory 66(8):5299-5309",
        "Field: GF(2^9), modulus = $n9_mod = 0x$(string(n9_mod, base = 16)) (x⁹+x⁴+1)",
        "Julia: $(VERSION),  date: $(Dates.today())",
    )
    println(io)
    println(io, "Scope:")
    println(io, "  Exact:   Theorem IV.1, Corollary IV.2")
    println(io, "  Exact:   Theorem V.1 (i)+(ii) over all 1-/2-term linear L at n=6")
    println(io, "  Exact:   Theorem VI.3 iff on stated finite scans; n=9 sampled with published controls")
    println(io, "  Exact:   Theorem VI.3 published n=9 APN (Section VII-B explicit params)")
    println(io, "  Exact:   Table I — all 8 rows, pairwise CCZ-inequivalent (mugshot)")
    println(io, "  Partial: Proposition V.3 (q=2 only)")
    println(io, "  Partial: Lemma VI.6 (cases (i),(ii),(iv) of 5)")
    println(io, "  Loaded:  x⁹ + Tr(x³) over GF(2^8) verified APN (not its shift derivation)")
    println(io, "  Not run: Section VII-D full coverage claim (~2³⁶ general linear L)")
    println(io, "  Not run: Γ-rank (n=8 is opt-in with storage/time budgets; distinct signatures suffice)")

    section4_report(io)
    section5_report(io)
    section6_report(io)
    section7_report(io)
    table1_report(io)

    println(io)
    println(io, "=" ^ 72)
    println(io, "Done.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
