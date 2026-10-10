# Implements the aggregate paper report for Li et al. (2022).
# Paper: Kangquan Li, Yue Zhou, Chunlei Li, Longjiang Qu (2022),
#        "Two New Families of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(7):4761–4769
# Section: General — full paper report driver
#
# VBF API used: (delegated to included files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))

"""
    paper_report([io]; full) -> NamedTuple

Run all reproducible checks for Li et al. (2022) and print a structured report.
full=true extends Theorem 2 to m=5 and Theorem 3 to m=4 (minutes instead of seconds).
"""
function paper_report(io::IO = stdout; full::Bool = false)
    print_header(io)

    ms2 = full ? [2, 4, 5] : [2, 4]
    ms3 = full ? [2, 3, 4]    : [2, 3]

    r2 = theorem2_report(io; ms = ms2)
    r3 = theorem3_report(io; ms = ms3, s = 1, v = 1)

    print_section("summary", io)
    print_check("theorem2-apn (bivariate, m ∈ $ms2, n=2m)",  r2.all_ok, io)
    print_check("theorem3-apn (univariate, m ∈ $ms3)", r3.all_ok, io)
    println(io, "\n  [NOTE] Γ-rank computation (Table IV n=8, Table V n=9) is out of scope;")
    println(io, "         n=8 gamma_rank requires explicit resource budgets; n=9 remains unsupported.")
    println(io, "  [NOTE] v=1 used for Theorem 3 (v must be nonzero in the embedded F_{2^m}).")
    println(io, "  [NOTE] μ reported is the smallest valid element found by exhaustive search.")

    return (; theorem2 = r2, theorem3 = r3)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
