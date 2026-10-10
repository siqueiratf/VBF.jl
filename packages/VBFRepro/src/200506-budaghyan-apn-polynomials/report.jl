# Top-level report for Budaghyan, Carlet, Pott (2006).
# Paper: "New Classes of Almost Bent and Almost Perfect Nonlinear Polynomials"
#        IEEE Transactions on Information Theory, 52(3):762–777.
# Section: All — Sections 3–4 (Example 1, Props 3/5/6), Section 5 Theorems 1–4,
#          Remark 4

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "remark4.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "propositions.jl"))

"""
    paper_report(io) -> Nothing

Full reproduction report for Budaghyan–Carlet–Pott (2006).

Scope:
- exact:   Theorems 1–4, Remark 4, Example 1, Propositions 3/4/5/6
- bounded: Remark 4 default uses random sample (full_search=true for exhaustive);
           Props 5/6 are exhaustive at m=4 and sampled at m ∈ {5,6,8}
- skipped: CCZ-class enumeration, timing tables; Props 1–2 and Remarks 1–3 are
           derivation apparatus exercised implicitly by Theorems 1–4
"""
function paper_report(io::IO = stdout)
    paper_banner(io)
    println(io, "Julia version : ", VERSION)
    println(io, "Date          : ", Dates.today())
    println(io)
    println(io, "Scope: Theorems 1–4, Remark 4, Example 1, Propositions 3/4/5/6")
    println(io, "       CCZ-class enumeration and timing tables: not executed")
    println(io, "Checks: Theorem 3 F1⁻¹ formula tested exhaustively on GF(2^6);")
    println(io, "        Theorem 3 CCZ-equivalence to Gold verified at n=6 (fixed oracle);")
    println(io, "        Theorem 3 EA-inequivalence to every known n=6 APN (degree witness);")
    println(io, "        Theorem 4 explicit F' formula tested against F2∘F1⁻¹ at n=3 AND n=5;")
    println(io, "        Theorem 4 divisor corollary exercised at m=15, n ∈ {1,3,5};")
    println(io, "        Prop 4 scanned over every c ∈ F*_{2^m}, not just c=1;")
    println(io, "        Theorems 1/2 gcd(i,m)=s>1 remark exercised (three-valued spectrum)")

    theorem1_report(io)
    remark4_report(io)
    theorem2_report(io)
    theorem3_report(io)
    theorem4_report(io)
    propositions_report(io)

    println(io, "\n", "=" ^ 72)
    println(io, "Done.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
