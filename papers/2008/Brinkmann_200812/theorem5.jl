# Implements Sections 4-5, Theorem 5: EA-equivalence classes for n=4 and n=5.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 4 (EA equiv) + 5 (CCZ equiv)
#
# Pseudocode:
#   1. n=4: F1 (Gold x³ class, deg 2) and F2 (non-power [5] class, deg 3) are APN + EA-inequiv
#   2. n=4: F1 ~ x³ EA; F2 ~ the closed-form BCP eq. (5) construction EA
#   3. n=5: 7 functions {x³,x⁵,x⁷,x¹¹,x¹⁵,f6_1,f6_2} all APN + pairwise EA-inequivalent,
#      every pair decided either by the EA oracle or by CCZ separation
#   4. n=5: f6_1, f6_2 are not EA-equiv to any of the 5 power functions
# VBF API used: differential_uniformity, algebraic_degree, are_ea_equivalent,
#               are_ccz_equivalent, gamma_rank, gf_pow, primitive_polynomial, SBox

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem5_n4_report(io)

Theorem 5 (n=4 part): 2 APN functions in F(F₂⁴, F₂⁴) up to EA equivalence.
"""
function theorem5_n4_report(io::IO = stdout)
    print_section(io, "Theorem 5 (n=4) — 2 EA-equivalence classes")
    F1, F2 = table2_luts()
    mod4 = primitive_polynomial(4)
    G3 = SBox{4}([gf_pow(x, 3, 4; modulus = mod4) for x = 0:15])

    for (lbl, F) in [("F1", F1), ("F2", F2)]
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        perm = is_permutation(F)
        print_check(io, "$lbl: APN (du=$du, deg=$deg, perm=$perm)", du == 2)
    end

    for (lbl, F, G, want) in [
        ("F1 ~ F2 EA-inequivalent", F1, F2, false),
        ("F1 ~ x³ (Gold) EA-equivalent", F1, G3, true),
        ("F2 ≁ x³ (Gold) — non-power class", F2, G3, false),
    ]
        v, why = ea_verdict(F, G)
        print_check(io, "$lbl  [$why]", v === want)
    end
    println(io, "  F2 algebraic degree = $(algebraic_degree(F2)) (≠ 2 confirms non-Gold)")
    println(io, "  F2 is from the Budaghyan-Carlet-Pott family [ref 5], eq. (5).")

    # The EA oracle now decides this pair outright: a pair with a non-permutation
    # input is routed to the complete inner-affine enumeration, which is
    # exhaustive (hence exact) for n=4 well within the default cap. The earlier
    # CCZ workaround here rested on a stale claim that the auto strategy fell
    # back to a permutation-only Heggebakk search and "bailed to false".
    F5 = formula5_n4()
    v, why = ea_verdict(F2, F5)
    print_check(io, "F2 ~ formula5_n4() EA-equivalent (same EA class)  [$why]", v === true)
    v1, why1 = ea_verdict(F1, F5)
    print_check(io, "F1 ≁ formula5_n4() EA-inequivalent  [$why1]", v1 === false)
end

"""
    theorem5_n5_report(io)

Theorem 5 (n=5 part): 7 APN functions in F(F₂⁵, F₂⁵) up to EA equivalence.
5 power-function classes + 2 non-power classes from formula (6).
"""
function theorem5_n5_report(io::IO = stdout)
    print_section(io, "Theorem 5 (n=5) — ≥7 pairwise EA-inequivalent APN functions")
    labels5 = ["x³", "x⁵", "x⁷", "x¹¹", "x¹⁵", "f6(i=1)", "f6(i=2)"]
    fns = n5_all_seven()

    println(io, "  Properties of 7 representatives:")
    for (lbl, F) in zip(labels5, fns)
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        perm = is_permutation(F)
        print_kv(io, lbl, "du=$du  deg=$deg  perm=$perm  Γ-rank=$(gamma_rank(F))")
    end

    # `are_ea_equivalent` defaults to on_inconclusive = :best_effort, which warns
    # and returns `false` when its bounded search is capped. Reading that `false`
    # as "inequivalent" turns an undecided pair into a claimed EA class — the
    # core docstring calls this out as how a novelty check manufactures a
    # discovery. Two of the 21 pairs are exactly that case: (x⁷, x¹¹) are
    # monomial APN with the degenerate [2ⁿ−1,1] Heggebakk partition, and
    # (f6(1), f6(2)) are non-permutations whose inner-affine enumeration would
    # need |AGL(5,2)| = 3.2·10⁸ steps, far past the 10⁷ default cap.
    #
    # Both are settled soundly by CCZ separation: EA-equivalence implies
    # CCZ-equivalence, so a pair in two different CCZ classes is EA-inequivalent.
    # The class map itself uses only sound outcomes — positive CCZ witnesses
    # against x³/x⁵ (one side quadratic APN ⇒ exact ortho-derivative test) and
    # the Γ-rank CCZ-invariant for x¹⁵.
    print_section(io, "Theorem 5 (n=5) — CCZ class map (used to separate the capped EA pairs)")
    _, rep_lbl = n5_ccz_reps()
    classes = [n5_ccz_class(F) for F in fns]
    for (lbl, c) in zip(labels5, classes)
        print_kv(io, lbl, c === nothing ? "no CCZ class witness" : "CCZ class of $(rep_lbl[c])")
    end
    print_check(io, "every one of the 7 has a witnessed CCZ class",
                all(c !== nothing for c in classes))

    print_section(io, "Theorem 5 (n=5) — pairwise EA-inequivalence")
    all_distinct = true
    undecided = Tuple{String,String}[]
    by_ea = 0
    by_ccz = 0
    for i = 1:length(fns), j = (i+1):length(fns)
        v, why = ea_verdict(fns[i], fns[j]; class_F = classes[i], class_G = classes[j])
        if v === missing
            push!(undecided, (labels5[i], labels5[j]))
            print_check(io, "$(labels5[i]) vs $(labels5[j]): UNDECIDED — $why", false)
        elseif v === true
            print_check(io, "$(labels5[i]) ~ $(labels5[j]): UNEXPECTED  [$why]", false)
            all_distinct = false
        elseif startswith(why, "CCZ")
            by_ccz += 1
            print_kv(io, "$(labels5[i]) vs $(labels5[j])", why)
        else
            by_ea += 1
        end
    end
    n_pairs = length(fns) * (length(fns) - 1) ÷ 2
    print_kv(io, "pairs decided by the EA oracle", "$by_ea/$n_pairs")
    print_kv(io, "pairs decided by CCZ separation", "$by_ccz/$n_pairs")
    if !isempty(undecided)
        print_kv(io, "pairs left UNDECIDED", join(["$a/$b" for (a, b) in undecided], ", "))
    end
    # The claim only stands if every pair was actually decided.
    print_check(io, "All 7 functions pairwise EA-inequivalent (≥7 EA-classes confirmed)",
                all_distinct && isempty(undecided))

    print_section(io, "Theorem 5 (n=5) — non-power classes f6(i=1) and f6(i=2)")
    for (k, lbl) in [(6, "f6(i=1)"), (7, "f6(i=2)")]
        verdicts = [ea_verdict(fns[k], fns[p]; class_F = classes[k], class_G = classes[p])[1]
                    for p = 1:5]
        any_eq = any(v === true for v in verdicts)
        n_undec = count(v -> v === missing, verdicts)
        print_check(io, "$lbl ≁ any power function (EA)" *
                        (n_undec > 0 ? " [$n_undec/5 comparisons UNDECIDED]" : ""),
                    !any_eq && n_undec == 0)
    end
    println(io, "  Note: completeness (exactly 7 classes) requires backtrack search — out of scope.")
end

"""
    theorem5_report(io)

Full Theorem 5: EA-equivalence classes for n=4 (2 classes) and n=5 (≥7 classes).
"""
function theorem5_report(io::IO = stdout)
    theorem5_n4_report(io)
    theorem5_n5_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem5_report()
end
