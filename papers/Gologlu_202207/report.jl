# Top-level paper report for Gologlu_202207.
# Paper: Gologlu, F. (2022), "Biprojective Almost Perfect Nonlinear Functions",
#        IEEE Transactions on Information Theory
#
# Pseudocode:
#   1. Print header (paper, field params, scope)
#   2. Theorem III.2 — APN verification (m=3,5)
#   3. Proposition III.4 — η_m(NBF) bounds (m=3,5)
#   4. Table I + III — NF sequences on n=10
#   5. Table II — NF sequences on n=14 (opt-in: full_search=true)
# VBF API used: see theorem3_2.jl, proposition3_4.jl, table1.jl, table2.jl

using Dates
include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem3_2.jl"))
include(joinpath(@__DIR__, "proposition3_4.jl"))
include(joinpath(@__DIR__, "table1.jl"))
include(joinpath(@__DIR__, "table2.jl"))

"""
    paper_report(; io, full_search) -> NamedTuple

Full reproduction report for Gologlu (2022).
Set `full_search=true` to include Table II (n=14, ~minutes per function).
"""
function paper_report(; io::IO = stdout, full_search::Bool = false)
    print_header(io)
    println(io, "Scope:")
    println(io, "  EXACT: Theorem III.2 APN (m=3,5), Proposition III.4 (m=3,5), Table I (n=10)")
    println(io, "  OPT-IN: Table II (n=14) — pass full_search=true")
    println(io, "  OUT-OF-SCOPE: Lemma A.1/A.2 algebraic proofs, Proposition VI.2 BHK-F1 details")
    println(io)

    r_thm = theorem3_2_report(; io, m_values = [3, 5])
    r_prop = proposition3_4_report(; io)
    r_t1 = table1_report(; io, include_table3 = true)

    r_t2 = nothing
    if full_search
        r_t2 = table2_report(; io, i_values = [1, 2, 3])
    else
        println(io, "\n  [Table II skipped — rerun with full_search=true for n=14 NF values]")
    end

    println(io, "\n" * "=" ^ 72)
    all_ok = r_thm.all_ok && r_prop.all_ok && r_t1.all_ok &&
             (r_t2 === nothing || r_t2.all_ok)
    print_check("Overall reproduction", all_ok, io)
    println(io, "=" ^ 72)

    (; all_ok, theorem3_2 = r_thm, proposition3_4 = r_prop, table1 = r_t1, table2 = r_t2)
end

if abspath(PROGRAM_FILE) == @__FILE__
    full = "--full" in ARGS
    paper_report(; full_search = full)
end
