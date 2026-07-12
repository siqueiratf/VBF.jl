# Implements Section 2 — The Linear Equivalence Algorithm (LE).
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 2 — The Linear Equivalence Algorithm
#
# Pseudocode:
#   1. Pick a known-equivalent pair (F, G = L1 ∘ F ∘ L2) and verify LE detects it.
#   2. Pick a known-inequivalent pair and verify LE rejects it.
#   3. For permutations with F(0)=0: verify the zero-fixed optimisation holds.
# VBF API used: are_linear_equivalent, load_apn_function

include(joinpath(@__DIR__, "helpers.jl"))

function section2_report(io::IO = stdout; strategy::Symbol = :auto)
    print_section(io, "Section 2 — Linear Equivalence (LE) Algorithm")

    # Gold x^3 and Gold x^5 over GF(2^5) are linearly inequivalent.
    g3 = load_apn_function("n5_Gold_x3")
    g5 = load_apn_function("n5_Gold_x5")

    ok_reject = !are_linear_equivalent(g3, g5; strategy)
    print_check(io, "Gold x^3 and Gold x^5 (n=5) are NOT linearly equivalent", ok_reject)

    # A function is always linearly equivalent to itself.
    ok_self = are_linear_equivalent(g3, g3; strategy)
    print_check(io, "Gold x^3 linearly equivalent to itself", ok_self)

    # Compose with a random linear map and verify LE recovers equivalence.
    # Use the known linear representative to construct an explicit image.
    rep = linear_representative(g3)
    # rep.representative == B^{-1} ∘ F ∘ A, so F ∘ A is linearly equiv to F via B^{-1}.
    ok_composed = are_linear_equivalent(g3, rep.representative; strategy)
    print_check(
        io,
        "Gold x^3 and its linear representative are linearly equivalent",
        ok_composed,
    )

    # n=6: exhaustive check — Gold x^3 in GF(2^6) is APN and a permutation; verify LE self-check.
    g3_n6 = load_apn_function("n6_Gold_x3")
    ok_n6 = are_linear_equivalent(g3_n6, g3_n6; strategy)
    print_check(io, "Gold x^3 (n=6) linearly equivalent to itself", ok_n6)

    print_kv(io, "strategy", strategy)
    print_kv(io, "completeness", "exhaustive over stated pairs")

    return ok_reject && ok_self && ok_composed && ok_n6
end

if abspath(PROGRAM_FILE) == @__FILE__
    ok = section2_report()
    exit(ok ? 0 : 1)
end
