# Aggregate report for Calderini, Budaghyan, Carlet (2021).
# Paper: "On Known Constructions of APN and AB Functions and Their Relation to Each Other"
#        RAD HAZU, Matematičke Znanosti, Vol. 25 = 546 (2021): 79–105
# Section: General — aggregate paper_report driver

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem3_1.jl"))
include(joinpath(@__DIR__, "theorem4_4.jl"))
include(joinpath(@__DIR__, "theorem5_1.jl"))
include(joinpath(@__DIR__, "theorem5_4.jl"))
include(joinpath(@__DIR__, "theorem5_6.jl"))
include(joinpath(@__DIR__, "theorem6_2.jl"))
include(joinpath(@__DIR__, "section6_1.jl"))
include(joinpath(@__DIR__, "theorem7_1.jl"))
include(joinpath(@__DIR__, "theorem7_2.jl"))
include(joinpath(@__DIR__, "section7_example.jl"))

"""
    paper_report(io::IO = stdout; full_search::Bool = false) -> NamedTuple

Run all bounded/default reproducible checks and print a structured report.
`full_search=true` adds the Section 6.1.2 aggregate n=10 sweep (est. 15-30 min).
"""
function paper_report(io::IO = stdout; full_search::Bool = false)
    print_header(io)

    r31  = theorem3_1_report(io;  ms = [2, 3, 4])
    r44a = theorem4_4_report(io;  m  = 3)
    r44b = theorem4_4_report(io;  m  = 4)
    r51  = theorem5_1_report(io;  m  = 4)
    r54  = theorem5_4_report(io)
    r56a = theorem5_6_report(io;  m  = 4)
    r56b = theorem5_6_report(io;  m  = 5)
    r56c = theorem5_6_report(io;  m  = 6)
    r62  = theorem6_2_report(io;  m  = 4, i = 1)
    r61  = section6_1_report(io;  full_search)
    r612 = section6_1_n12_report(io)
    r71  = theorem7_1_report(io)
    r72  = theorem7_2_report(io)
    r7ex = section7_example_report(io)

    print_section("summary", io)
    print_check("theorem3_1 — hexanomial APN condition (n=4,6,8)",     r31.all_ok,  io)
    print_check("theorem4_3/4_4/prop4_5 — m=3 (n=6)",                  r44a.all_ok, io)
    print_check("theorem4_3/4_4/prop4_5 — m=4 (n=8)",                  r44b.all_ok, io)
    print_check("theorem5_1 — Zhou-Pott APN condition",                r51.all_ok,  io)
    print_check("theorem5_4 — general bivariate condition (sampled)",  r54.all_ok,  io)
    print_check("theorem5_6 — F1/F2/F3 canonical forms (m=4)",         r56a.all_ok, io)
    print_check("theorem5_6 — F1/F2/F3 canonical forms (m=5)",         r56b.all_ok, io)
    print_check("theorem5_6 — F1/F2/F3 canonical forms (m=6)",         r56c.all_ok, io)
    print_check("theorem6_2 — new APN family condition + Lemma 6.1",   r62.all_ok,  io)
    print_check("section6_1 — n=8 classification + CCZ-distinctness",  r61.all_ok,  io)
    print_check("section6_1 — n=12 targeted case checks",              r612.all_ok, io)
    print_check("theorem7_1 — biprojective reduction f1-f4 (n=6)",     r71.all_ok,  io)
    print_check("theorem7_2 — Gologlu F1/F2 APN (n=8,10)",             r72.all_ok,  io)
    print_check("section7 — dimension-6 example and switch",           r7ex.all_ok, io)

    all_ok = r31.all_ok && r44a.all_ok && r44b.all_ok && r51.all_ok &&
             r54.all_ok && r56a.all_ok && r56b.all_ok && r56c.all_ok &&
             r62.all_ok && r61.all_ok && r612.all_ok && r71.all_ok &&
             r72.all_ok && r7ex.all_ok

    print_kv("overall", all_ok ? "PASS" : "FAIL", io)
    (; all_ok, r31, r44a, r44b, r51, r54, r56a, r56b, r56c, r62,
       r61, r612, r71, r72, r7ex)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report(; full_search = ("--full" in ARGS))
end
