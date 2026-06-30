# Aggregate report for Calderini, Budaghyan, Carlet (2021).
# Paper: "On Known Constructions of APN and AB Functions and Their Relation to Each Other"
#        RAD HAZU, Matematičke Znanosti, Vol. 25 = 546 (2021): 79–105
# Section: General — aggregate paper_report driver

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem3_1.jl"))
include(joinpath(@__DIR__, "theorem4_4.jl"))
include(joinpath(@__DIR__, "theorem5_1.jl"))
include(joinpath(@__DIR__, "theorem5_6.jl"))
include(joinpath(@__DIR__, "theorem6_2.jl"))
include(joinpath(@__DIR__, "section6_1.jl"))

"""
    paper_report(io::IO = stdout) -> NamedTuple

Run all bounded/default reproducible checks and print a structured report.
"""
function paper_report(io::IO = stdout)
    print_header(io)

    r31  = theorem3_1_report(io;  ms = [2, 3])
    r44  = theorem4_4_report(io;  m  = 3)
    r51  = theorem5_1_report(io;  m  = 4)
    r56  = theorem5_6_report(io;  m  = 4)
    r62  = theorem6_2_report(io;  m  = 4, i = 1)
    r61  = section6_1_report(io)

    print_section("summary", io)
    print_check("theorem3_1 — hexanomial APN condition",          r31.all_ok,  io)
    print_check("theorem4_4 — bivariate Carlet EA-equiv hex",     r44.all_ok,  io)
    print_check("theorem5_1 — Zhou-Pott APN condition",           r51.all_ok,  io)
    print_check("theorem5_6 — F1/F2/F3 canonical forms",          r56.all_ok,  io)
    print_check("theorem6_2 — new APN family condition",          r62.all_ok,  io)
    print_check("section6_1 — n=8 new CCZ-class found",           r61.all_ok,  io)

    all_ok = r31.all_ok && r44.all_ok && r51.all_ok &&
             r56.all_ok && r62.all_ok && r61.all_ok

    print_kv("overall", all_ok ? "PASS" : "FAIL", io)
    (; all_ok, r31, r44, r51, r56, r62, r61)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
