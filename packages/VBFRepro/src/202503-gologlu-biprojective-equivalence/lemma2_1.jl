# Implements Lemma 2.1 — the biprojective APN criterion.
# Paper: Göloğlu, Kölsch (2025), "Equivalences of biprojective almost perfect
#        nonlinear functions", Electron. J. Combin.
# Section: 2.1 — Projective and biprojective polynomials
#
#   Lemma 2.1. Let F(x,y) = (f(x,y), g(x,y)) be a (q,r)-biprojective polynomial
#   pair. Then F is APN on M × M iff D_f^u(x,y) = 0 = D_g^u(x,y) has exactly
#   two solutions for each u ∈ P¹(M).
#
# Pseudocode:
#   1. For each u ∈ P¹(M) = M ∪ {∞}:
#        a. D_f^u and D_g^u are F₂-linear in (x,y), so assemble the 2m × 2m
#           F₂-matrix of (x,y) ↦ (D_f^u(x,y), D_g^u(x,y)).
#        b. #solutions = 2^dim ker.
#   2. F is APN iff every u gives exactly 2 solutions.
#   3. Cross-validate against the ground truth `differential_uniformity == 2`
#      on the full 2ⁿ LUT, over BOTH APN and deliberately non-APN pairs.
#
# The criterion costs O(2^m · m³) while the DDT costs O(2^{2n}) = O(2^{4m}).
# That gap is what lets theorem3_3.jl certify F₄ at n = 20 and n = 28.
#
# VBF API used: kernel_f2 (in helpers), SBox, differential_uniformity,
#               algebraic_degree, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""
    lemma2_1_instances(m) -> Vector{Tuple{BiPair,Bool}}

Test corpus on `M = F_{2^m}`: each Table 2.1 family instance that is admissible
(paired with `true`), **plus deliberately inadmissible instances** (paired with
`false`) obtained by breaking exactly one condition of the family's Notes column.

The inadmissible half is what makes the cross-validation discriminating: a
criterion that simply answered "APN" always would fail on them.
"""
function lemma2_1_instances(m::Integer)
    fld = BiField(m)
    N = order(fld)
    out = Tuple{BiPair,Bool}[]

    # ── admissible instances ────────────────────────────────────────────────
    for k = 1:(m-1)
        gcd(k, m) == 1 || continue
        if isodd(m)
            push!(out, (gold_odd(fld, k), true))
        else
            a = findfirst(x -> gf_trace(x, m; modulus = fld.modulus) == 1, 0:(N-1))
            a === nothing || push!(out, (gold_even(fld, k, a - 1), true))
        end
        d = findfirst(x -> taniguchi_valid(fld, k, x), 0:(N-1))
        d === nothing || push!(out, (taniguchi(fld, k, d - 1), true))
        dc = findfirst(x -> carlet_valid(fld, k, 0, 1, x), 0:(N-1))
        dc === nothing || push!(out, (carlet(fld, k, 0, 1, dc - 1), true))
        if iseven(m)
            for j = 1:(m-1)
                ex = zhou_pott_excluded_d(fld, k, j)
                dz = findfirst(x -> x != 0 && !(x in ex), 0:(N-1))
                dz === nothing || push!(out, (zhou_pott(fld, k, j, dz - 1), true))
            end
        end
        f1_valid(fld, k) && push!(out, (family_f1(fld, k), true))
        f2_valid(fld, k) && push!(out, (family_f2(fld, k), true))
    end
    for (k, B, a) in f4_parameters(fld)
        push!(out, (family_f4(fld, k, B, a), true))
    end

    # ── inadmissible instances (negative controls) ──────────────────────────
    for k = 1:(m-1)
        gcd(k, m) == 1 || continue
        # Taniguchi with a d for which x^{q+1}+x+d HAS a root
        dbad = findfirst(x -> !taniguchi_valid(fld, k, x), 0:(N-1))
        dbad === nothing || push!(out, (taniguchi(fld, k, dbad - 1), false))
        # Carlet with a rooted projective polynomial
        cbad = findfirst(x -> !carlet_valid(fld, k, 0, 1, x), 0:(N-1))
        cbad === nothing || push!(out, (carlet(fld, k, 0, 1, cbad - 1), false))
        if iseven(m)
            # Zhou-Pott with an excluded d
            ex = zhou_pott_excluded_d(fld, k, 1)
            dz = findfirst(x -> x != 0 && (x in ex), 0:(N-1))
            dz === nothing || push!(out, (zhou_pott(fld, k, 1, dz - 1), false))
        end
    end
    # F₁ with gcd(3k, m) ≠ 1
    for k = 1:(m-1)
        f1_valid(fld, k) || push!(out, (family_f1(fld, k), false))
    end
    out
end

"""
    lemma2_1_report(io = stdout; m_values = (3, 4, 5), limit = 2^31 - 1) -> NamedTuple

Cross-validate the Lemma 2.1 criterion against `differential_uniformity` on the
full LUT, for admissible and inadmissible biprojective pairs alike.
"""
function lemma2_1_report(
    io::IO = stdout;
    m_values = (3, 4, 5),
    limit::Int = typemax(Int),
)
    print_section("Lemma 2.1 — biprojective APN criterion", io)
    agree = 0
    disagree = String[]
    n_pos = 0      # criterion said APN
    n_neg = 0      # criterion said not-APN
    checked = 0
    for m in m_values
        insts = lemma2_1_instances(m)
        for (F, admissible) in insts
            checked ≥ limit && break
            checked += 1
            crit = biprojective_is_apn(F)
            du = differential_uniformity(bipair_sbox(F))
            crit ? (n_pos += 1) : (n_neg += 1)
            if crit == (du == 2)
                agree += 1
            else
                push!(disagree, "$(F.name): criterion=$crit DU=$du")
            end
            # The Notes column of Table 2.1 should be exactly the APN condition.
            admissible == (du == 2) ||
                push!(disagree, "$(F.name): admissible=$admissible but DU=$du")
        end
    end
    print_kv("m values", join(m_values, ", "), io)
    print_kv("pairs checked", checked, io)
    print_kv("criterion said APN", n_pos, io)
    print_kv("criterion said NOT APN (negative controls)", n_neg, io)
    print_check("criterion agrees with differential_uniformity on every pair", isempty(disagree), io)
    print_check("at least one APN and one non-APN case exercised", n_pos > 0 && n_neg > 0, io)
    for d in disagree
        println(io, "    [MISMATCH] ", d)
    end
    print_kv("completeness", "exhaustive over the listed families for m ∈ $(m_values)", io)
    (;
        checked = checked,
        agree = agree,
        positives = n_pos,
        negatives = n_neg,
        disagreements = disagree,
        all_ok = isempty(disagree) && n_pos > 0 && n_neg > 0,
    )
end
