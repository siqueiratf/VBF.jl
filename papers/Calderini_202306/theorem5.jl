# Implements Theorem 5 and the Walsh-spectrum claims (Section 5) from
# Calderini, Li, Villa (2023).
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: 5 — Concluding remarks (Theorem 5 [27] and the F1/F2 spectra)
#
# Paper claims verified here:
#   - all APN functions from Theorem 3 (family F1) are 3-to-1 and hence have
#     Gold-like Walsh spectrum {|W_F(a,b)|} = {0, 2^{n/2}, 2^{n/2+1}}  [via 26,27]
#   - APN functions from Theorem 4 (family F2) have Gold-like Walsh spectrum
#     as well (computational, Problem 2), but are NOT 3-to-1
#   - Theorem 5 consistency: F quadratic APN, F(0)=0, 3-to-1 => Gold-like
#
# Pseudocode (theorem5_build):
#   For each case (m, k):
#     1. Build F1 (and F2 for k=1) with the reproduction's alpha
#     2. Check F(0) = 0, is_3_to_1, and the absolute Walsh value set
#        (over (a,b) != (0,0), so the trivial b=0 rows contribute only 0)
# VBF API used: is_3_to_1, absolute_walsh_spectrum, sorted_pairs,
#               differential_uniformity, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# The absolute Walsh value set over (a,b) != (0,0); Gold-like means
# {0, 2^{n/2}, 2^{n/2+1}} (n even).
function walsh_value_set(F::SBox{N}) where {N}
    sort!(Int[v for (v, _) in sorted_pairs(absolute_walsh_spectrum(F))])
end

gold_like_values(n::Int) = [0, 1 << (n ÷ 2), 1 << (n ÷ 2 + 1)]

const THEOREM5_CASES = [
    (m = 3, k = 1),                      # novel 3|m case, n = 6
    (m = 4, k = 1),                      # n = 8
    (m = 4, k = 3),                      # F1-only different-k case, n = 8
]

function theorem5_build(; full_search::Bool = false)
    cases = NamedTuple[]
    ms = full_search ? vcat(THEOREM5_CASES, [(m = 6, k = 1)]) : THEOREM5_CASES
    for (; m, k) in ms
        modulus = primitive_polynomial(m)
        alpha = find_alpha(m, k; modulus = modulus)
        @assert alpha !== nothing "No valid alpha for m=$m, k=$k"
        n = 2 * m

        F1 = family_f1_lut(m, k, alpha; modulus = modulus)
        r1 = (; fam = "F1", m, k, alpha, n,
                apn = differential_uniformity(F1) == 2,
                zero_fixed = F1.lut[1] == 0,
                three_to_one = is_3_to_1(F1),
                gold_like = walsh_value_set(F1) == gold_like_values(n))
        push!(cases, r1)

        if k == 1                        # family F2 is a k = 1 construction
            F2 = family_f2_lut(m, alpha; modulus = modulus)
            r2 = (; fam = "F2", m, k, alpha, n,
                    apn = differential_uniformity(F2) == 2,
                    zero_fixed = F2.lut[1] == 0,
                    three_to_one = is_3_to_1(F2),
                    gold_like = walsh_value_set(F2) == gold_like_values(n))
            push!(cases, r2)
        end
    end
    cases
end

function theorem5_report(io::IO = stdout; full_search::Bool = false)
    print_section("Theorem 5 — 3-to-1 and Gold-like Walsh spectra (Section 5)", io)
    println(io, "  Theorem 5 [27]: quadratic APN, F(0)=0, 3-to-1 => Gold-like spectrum")
    println(io, "  Paper: F1 members are 3-to-1 (=> Gold-like); F2 members are Gold-like")
    println(io, "  but NOT 3-to-1 (Problem 2)")

    cases = theorem5_build(; full_search = full_search)
    ok = true
    for r in cases
        print_kv("$(r.fam) m=$(r.m) k=$(r.k) alpha=$(r.alpha) (n=$(r.n))", "", io)
        print_check("  APN and F(0)=0", r.apn && r.zero_fixed, io)
        if r.fam == "F1"
            print_check("  3-to-1", r.three_to_one, io)
            ok = ok && r.three_to_one
        else
            print_check("  NOT 3-to-1", !r.three_to_one, io)
            ok = ok && !r.three_to_one
        end
        print_check("  Gold-like spectrum {0, 2^$(r.n ÷ 2), 2^$(r.n ÷ 2 + 1)}", r.gold_like, io)
        ok = ok && r.apn && r.zero_fixed && r.gold_like
    end
    print_check("all Theorem 5 / Walsh-spectrum claims hold", ok, io)
    println(io, "  completeness: exhaustive for the reproduced (m,k) cases; n=12 included")
    println(io, full_search ? "  with full_search=true" :
                "  only with full_search=true (run 'make theorem5')")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_banner()
    theorem5_report(; full_search = true)
end
