# Aggregate paper report for Tang, Carlet, Tang (2015)
# Paper: Deng Tang, Claude Carlet, Xiaohu Tang (2015),
#        "Differentially 4-Uniform Bijections by Permuting the Inverse Function"
#        Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "construction1.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "table3.jl"))
include(joinpath(@__DIR__, "example1.jl"))

"""
    paper_report([io]; full) -> NamedTuple

Full reproduction report for Tang, Carlet, Tang (2015).
full=true adds n=10 to construction1/theorem2 runs (~2 min extra).
"""
function paper_report(io::IO = stdout; full::Bool = false)
    print_header(io)

    ns = full ? [6, 8, 10] : [6, 8]

    r1 = construction1_report(io; ns)
    r2 = theorem2_report(io; ns)
    r3 = theorem3_report(io; ns = [6])   # Table 4 row n=6; n=8 Thm3 slow, in example1
    r4 = table3_report(io; n = 6)
    r5 = example1_report(io)

    print_section("summary", io)
    print_check("construction1 bijection + diff-4-uniform (n in $ns)", r1.all_ok, io)
    print_check("theorem2 algebraic-degree = n-1 (n in $ns)", r2.all_ok, io)
    print_check("theorems 3-6 NL lower bounds (n=6)", r3.all_ok, io)
    print_check("table3 22 distinct CCZ fingerprints (n=6)", r4.all_ok, io)
    print_check("table4 n=8 NL=100/102/102 (U_max/U_m0/U_m1)", r5.all_ok, io)
    println(io, "\n  [NOTE] Theorems 7-9 (CCZ-inequivalence proofs) are mathematical;")
    println(io, "         verified structurally via distinct (nl,D0,D2,D4) fingerprints.")
    println(io, "  [NOTE] Table 3 α-indices differ from paper (VBF poly vs Magma Conway poly);")
    println(io, "         CCZ-class count (22) is polynomial-independent.")
    println(io, "  [NOTE] Example 1 (p.23) α-indices use Magma 2.12-16 primitive element,")
    println(io, "         which differs from VBF's polynomial basis; Table 4 values used instead.")

    return (; construction1 = r1, theorem2 = r2, theorem3 = r3, table3 = r4, example1 = r5)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
