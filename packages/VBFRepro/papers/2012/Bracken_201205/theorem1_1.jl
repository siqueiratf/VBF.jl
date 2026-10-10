# Implements Theorem 1.1 at its smallest GENUINE (non-degenerate) instance.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 1 / 3 — the t = 2 headline: a differentially 4 uniform permutation
#                   that is a true binomial
#
# Pseudocode:
#   1. Theorem 1.1 needs n = 3k, k even, 3∤k, k/2 odd, gcd(3k,s) = 2, 3 | k+s.
#      The smallest solution is k = 10, s = 2 → n = 30.  (k = 2 forces
#      s ≡ 4 mod 6, and then both exponents collapse to 17 mod 63: the paper's
#      own smallest case is a monomial in disguise — Paper Issue 2.)
#   2. GF(2^30) with x^30+x^6+x^4+x+1 = 1073741907; assert α = 2 primitive.
#   3. Differential half: F is quadratic, so B_a(x) = F(x⊕a)⊕F(x)⊕F(a)⊕F(0) is
#      linear and every DDT entry of row a is 0 or 2^{dim ker B_a}.  Sampling
#      `dim ker B_a = t = 2` therefore certifies Δ_F = 4 and spectrum {0,4} on
#      the sampled rows — with no DDT and no 2^30-entry LUT.
#   4. Permutation half: a streaming injectivity scan over a 2^30-bit (128 MB)
#      bitmap, budgeted by `limit` and exhaustive only under `full_search`.
# VBF API used: gauss_jordan!, gf_mul, gf_pow
#
# EVIDENCE LEVEL AND COST, measured on this machine with @elapsed
# (Julia 1.12.6, AMD Ryzen 5 5600G, single-threaded):
#   α = 2 primitive in GF(2^30)                      : verified, instant
#   dim ker B_a = 2 for 2000 random a ≠ 0            : 0.46 s   → SAMPLED COMPUTATIONAL EVIDENCE
#   dim ker B_a = 2 for a = 1..500                   : 0.08 s
#   injectivity prefix, limit = 2^16 / 2^18 / 2^20   : 0.27 / 0.81 / 3.26 s
#   exhaustive 2^30 injectivity scan                 : ~55 min EXTRAPOLATED
#                                                      (never run here)
# The review README quoted "4 m 55 s in C" for the exhaustive permutation scan.
# That figure came from a C program on a DIFFERENT machine and is not ours; the
# ~55 min above is this machine's own linear extrapolation from the 2^20 prefix.

include(joinpath(@__DIR__, "helpers.jl"))

# Smallest (k, s) satisfying Theorem 1.1 with a genuinely binomial F.
const THEOREM11_K = 10
const THEOREM11_S = 2

"""
    theorem1_1_instance() -> BrackenBinomial

`F` of Theorem 1.1 at `(k, s) = (10, 2)`, n = 30, t = 2, k/2 = 5 odd.
Exponents `e₁ = 5` and `e₂ = 2^20 + 2^12 = 1052672` are distinct mod `2^30 − 1`,
so this really is a binomial — unlike the n = 6 instance.
"""
theorem1_1_instance() =
    bracken_binomial(THEOREM11_K, THEOREM11_S; allow_nonpermutation = false)

function theorem1_1_report(
    io::IO = stdout;
    samples::Integer = 2000,
    limit::Integer = 1 << 18,
    full_search::Bool = false,
)
    print_section("Theorem 1.1 — the genuine t=2 instance at n = 30 (k=10, s=2)", io)
    println(io, "  F(x) = α·x^5 + α^{2^10}·x^{2^20+2^12} over GF(2^30),")
    println(io, "  modulus x^30+x^6+x^4+x+1 = $(paper_modulus(30)), α = 2.")
    println(io, "  Theorem 1.1: F is a differentially 4 uniform permutation with")
    println(io, "  Walsh spectrum ⊆ {0, ±2^15, ±2^16}.")
    println(io)

    prim = alpha_is_primitive(30)
    print_check("α = 2 is primitive in GF(2^30) (order 2^30−1 = $((1 << 30) - 1) " *
                "= 3²·7·11·31·151·331)", prim, io)

    F = theorem1_1_instance()
    genuine = !is_degenerate(F)
    print_check("F is a genuine binomial: e₁ = $(F.e1) ≠ e₂ = $(F.e2) (mod 2^30−1)",
                genuine, io)

    t_rank = @elapsed r = derivative_kernel_dims(F; samples = samples)
    dims_ok = r.dims == [F.t]
    print_check("dim ker B_a = t = $(F.t) on $(r.samples) random a ≠ 0 " *
                "⇒ DDT rows ⊆ {0, 2^$(F.t)} = {0, $(1 << F.t)} " *
                "[dims $(r.dims), $(round(t_rank; digits = 2)) s here]", dims_ok, io)

    t_perm = @elapsed p = streaming_permutation_check(F; limit = limit, full_search = full_search)
    print_check("injective on the first $(p.scanned) inputs " *
                (p.full_domain ? "(EXHAUSTIVE over all 2^30)" : "(partial scan)") *
                " [$(round(t_perm; digits = 2)) s here]", p.injective, io)

    println(io)
    all_pass = prim && genuine && dims_ok && p.injective
    print_check("Theorem 1.1 evidence at n = 30 collected", all_pass, io)
    print_kv("evidence level",
             "differential half: SAMPLED COMPUTATIONAL EVIDENCE — the rank criterion is exact per a, " *
             "so every sampled row is certified, but not all 2^30−1 rows were sampled. " *
             "permutation half: " *
             (p.full_domain ? "EXHAUSTIVE" :
              "PARTIAL ($(p.scanned) of 2^30 inputs); pass full_search=true for the " *
              "exhaustive scan (~55 min extrapolated on this machine, never run here)"),
             io)
    print_kv("not reproduced",
             "the Walsh spectrum at n = 30: the streaming LAT scan is 2^60 " *
             "operations, far beyond this folder's budget. Theorem 1.1's " *
             "\"⊆ {0, ±2^15, ±2^16}\" stays TRANSCRIBED", io)
    (; all_pass, kernel_dims = r.dims, samples = r.samples, perm = p)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem1_1_report()
end
