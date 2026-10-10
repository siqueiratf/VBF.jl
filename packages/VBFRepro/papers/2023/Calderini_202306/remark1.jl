# Implements Remark 1 from Calderini, Li, Villa (2023).
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: 4.1 — Remark 1 (and Kolsch [26], p. 17)
#
# Paper claims verified here:
#   - Remark 1: in dimensions n = 8 and n = 10, the functions from Theorems 3
#     and 4 are CCZ-equivalent to the families they generalize: Theorem 1's
#     F_1 is exactly F1 with alpha = 1 (Section 3, p. 9) and Theorem 2's
#     function is exactly F2 with alpha = 1
#   - Kolsch [26]: for family F1 every admissible alpha yields one class, so
#     comparing an alpha != 1 member against the alpha = 1 member decides both
#
# Pseudocode (remark1_build):
#   For m in ms  [gcd(3, m) = 1 so alpha = 1 is valid]:
#     1. Pick the smallest admissible alpha != 1
#     2. are_ccz_equivalent(F1(alpha), F1(1)) — expect true
#     3. are_ccz_equivalent(F2(alpha), F2(1)) — expect true
#
# Cost note: the CCZ decision routes through the ortho-derivative EA test,
# whose are_linear_equivalent search is the bottleneck. Measured here:
#   n = 8:  F1 ~26 s, F2 ~165 s  (defaults cover this)
#   n = 10: the F1 check did not finish within 25 CPU-minutes and was
#           aborted; n = 10 is therefore opt-in via remark1_build(ms=[4,5])
#           and the n = 10 half of Remark 1 stays paper-trusted by default.
# VBF API used: are_ccz_equivalent, differential_uniformity,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

function remark1_build(; ms = [4])
    results = NamedTuple[]
    for m in ms
        modulus = primitive_polynomial(m)
        alphas = [a for a in 1:(1 << m)-1
                  if has_no_root_projective(m, 1, a; modulus = modulus)]
        @assert 1 in alphas "alpha=1 must be admissible when gcd(3, m) = 1 (m=$m)"
        alpha = first(a for a in alphas if a != 1)

        F1a = family_f1_lut(m, 1, alpha; modulus = modulus)
        F1b = family_f1_lut(m, 1, 1;     modulus = modulus)   # Theorem 1 F_1
        t1 = @elapsed eq1 = are_ccz_equivalent(F1a, F1b)

        F2a = family_f2_lut(m, alpha; modulus = modulus)
        F2b = family_f2_lut(m, 1;     modulus = modulus)      # Theorem 2
        t2 = @elapsed eq2 = are_ccz_equivalent(F2a, F2b)

        push!(results, (; m, n = 2m, alpha, eq1, eq2, t1, t2))
    end
    results
end

function remark1_report(io::IO = stdout; ms = [4])
    print_section("Remark 1 — CCZ-equivalence to the generalized families (n=8, 10)", io)
    println(io, "  Theorem 1 F_1 = F1(alpha=1); Theorem 2 = F2(alpha=1) — exact instances")
    println(io, "  Remark 1: for n = 8, 10 the new members collapse into those classes")
    if !(5 in ms)
        println(io, "  n=10 SKIPPED: its F1 CCZ check exceeded 25 CPU-min (aborted);")
        println(io, "  opt in with remark1_report(ms=[4,5])")
    end

    ok = true
    for r in remark1_build(; ms = ms)
        print_kv("m=$(r.m) (n=$(r.n)) alpha=$(r.alpha)", "", io)
        print_check("  F1(alpha=$(r.alpha)) CCZ~ Theorem 1 F_1 ($(round(r.t1; digits=1))s)",
                    r.eq1, io)
        print_check("  F2(alpha=$(r.alpha)) CCZ~ Theorem 2   ($(round(r.t2; digits=1))s)",
                    r.eq2, io)
        ok = ok && r.eq1 && r.eq2
    end
    print_check("Remark 1 verified for all listed dimensions", ok, io)
    println(io, "  completeness: one alpha != 1 representative per checked dimension; by")
    println(io, "  Kolsch [26] all admissible alpha of F1 give a single class; n=10 is")
    println(io, "  opt-in (see cost note at the top of this file)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_banner()
    remark1_report()
end
