# Report for Beierle, Brinkmann, Leander (2021).
# Paper: "Linearly Self-Equivalent APN Permutations in Small Dimension"
# Section: All -- Corollary 1, Propositions 4/5, Algorithm 1, Table 1, Theorem 1
#
# VBF API used: print_banner, print_section, print_check, print_kv,
#               SBox, differential_uniformity, is_permutation,
#               are_ccz_equivalent, dillon_apn_permutation, gf_monomial_lut,
#               algebraic_degree, delta_rank

using VBF
using Dates

include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "corollary1_n6n7n8.jl"))
include(joinpath(@__DIR__, "proposition4.jl"))
include(joinpath(@__DIR__, "proposition5.jl"))

function print_header(io::IO = stdout)
    print_banner(io,
        "Beierle, Brinkmann, Leander (2021)",
        "Linearly Self-Equivalent APN Permutations in Small Dimension",
        "Julia $(VERSION)  |  $(today())")
    println(io)
    println(io, "Scope:")
    println(io, "  [exact]   Corollary 1: fresh n=6/7/8 classes (17/27/32) match stored sets")
    println(io, "  [exact]   Propositions 4, 5: admissibility filters")
    println(io, "  [exact]   Table 1: Proposition4/5 rejection sets; search negatives incomplete")
    println(io, "  [bounded] Algorithm1: optional Lemma5 pruning and verified Lemma6 seeding; explicit outcomes")
    println(io, "  [witness] n=6 stored solution CCZ-equivalent to Dillon; uniqueness unverified")
    println(io, "  [mixed]   n=7 stored solutions: exact quadratic checks; other matches inconclusive")
    println(io)
end

# -------------------------------------------------------------------------
# Table 1: admissibility
# -------------------------------------------------------------------------
function table1_report(io::IO = stdout)
    print_section("Table 1 — Admissibility Filters", io)

    expected_prop4_reject = Dict(
        6 => [6, 9, 13, 16, 17],
        7 => [12, 13, 14, 15, 20, 21, 25, 27],
        8 => [13, 18, 19, 20, 21, 25, 26, 28, 32],
    )
    expected_prop5_reject = Dict(
        6 => [4, 8, 12],
        7 => [2, 3, 6, 11, 19],
        8 => [3, 7, 11, 12, 17, 24],
    )
    n_blocks = Dict(6 => 17, 7 => 27, 8 => 32)

    all_ok = true
    for n in [6, 7, 8]
        p4_reject = Int[]
        p5_reject = Int[]
        for i in 1:n_blocks[n]
            A, B = precomputed_tuple_matrices(n, i)
            proposition4_filter(A, B, n) || push!(p4_reject, i)
            proposition5_filter(A, B, n) || push!(p5_reject, i)
        end

        # Prop 5 rejected classes should exclude those already rejected by Prop 4
        # (Table 1 lists Prop 5 rejections that are not already Prop 4 rejections)
        p5_only = setdiff(p5_reject, p4_reject)

        p4_ok = sort(p4_reject) == sort(expected_prop4_reject[n])
        p5_ok = sort(p5_only) == sort(expected_prop5_reject[n])
        all_ok = all_ok && p4_ok && p5_ok

        print_kv(io, "n=$n Prop 4 rejects", string(sort(p4_reject)))
        print_check(io, "n=$n Prop 4 matches Table 1", p4_ok)
        print_kv(io, "n=$n Prop 5 rejects (excl. Prop 4)", string(sort(p5_only)))
        print_check(io, "n=$n Prop 5 matches Table 1", p5_ok)
    end

    all_ok
end

# -------------------------------------------------------------------------
# Theorem 1 / n=6 search
# -------------------------------------------------------------------------
function theorem1_report(io::IO = stdout)
    print_section("Theorem 1 — Stored n=6 Witness; Exhaustive Uniqueness Unverified", io)

    # Load stored n=6 class 5 result
    blocks = _load_tuple_matrix_blocks(
        joinpath(@__DIR__, "tuples", "AllTuplesMatrices6.toml"))
    result = blocks[5].search

    # A missing `search` field means "no solution was persisted". Because the
    # searches that populate this file run under `timeout_seconds` (Makefile
    # default 300), absence is NOT evidence that the class holds no APN
    # permutation — it is equally consistent with the budget having expired.
    # Only a run whose outcome was `Exhausted` licenses that reading.
    has_result = result !== nothing
    print_check(io, "n=6 class 5 search result stored", has_result)

    if !has_result
        print_kv(io, "note", "absent stored result = not persisted; NOT a proof the class is empty")
        print_check(io, "n=6 result is APN permutation", false)
        print_check(io, "n=6 result CCZ-equiv to Dillon's permutation", false)
        return false
    end

    F = SBox{6}(result)
    is_apn = differential_uniformity(F) == 2
    is_perm = is_permutation(F)
    ccz_dillon = are_ccz_equivalent(F, dillon_apn_permutation())

    print_check(io, "n=6 result is APN", is_apn)
    print_check(io, "n=6 result is permutation", is_perm)
    print_check(io, "n=6 result CCZ-equiv to Dillon's permutation", ccz_dillon)
    print_kv(io, "uniqueness", "not established; all remaining tuple searches must exhaust")

    is_apn && is_perm && ccz_dillon
end

# -------------------------------------------------------------------------
# n=7 monomial verification
# -------------------------------------------------------------------------
function n7_monomials_report(io::IO = stdout)
    print_section("n=7 Stored Results — Exact Equivalence Checks and Invariant Filters", io)

    blocks = _load_tuple_matrix_blocks(
        joinpath(@__DIR__, "tuples", "AllTuplesMatrices7.toml"))

    # Degree comparison and delta-rank provide only filters,
    # plus direct are_ccz_equivalent for quadratic Gold cases.
    class_to_exponent = Dict(
        4 => 63, 5 => 9, 7 => 5, 8 => 78, 9 => 85, 10 => 88)
    exponent_names = Dict(
        5 => "Gold k=2", 9 => "Gold k=3", 63 => "Inverse",
        78 => "Niho (inverse Kasami class)", 85 => "Gold x^3 (inverse)", 88 => "Welch")

    all_ok = true
    for (cls, exp) in sort(collect(class_to_exponent))
        result = blocks[cls].search
        if result === nothing
            # As above: not persisted ≠ proved empty. These searches ran under a
            # wall-clock budget.
            print_check(io, "class $cls: stored result present (absence is not a proof of emptiness)", false)
            all_ok = false
            continue
        end

        result_sbox = SBox{7}(result)
        mono_sbox   = SBox{7}(gf_monomial_lut(7, exp))

        is_apn = differential_uniformity(result_sbox) == 2
        is_perm = is_permutation(result_sbox)

        if algebraic_degree(mono_sbox) == 2
            ccz = are_ccz_equivalent(result_sbox, mono_sbox)
            method = "exact CCZ solver"
            evidence = "CCZ-equivalent=$ccz"
        else
            deg_match = algebraic_degree(result_sbox) == algebraic_degree(mono_sbox)
            dr_match  = delta_rank(result_sbox) == delta_rank(mono_sbox)
            ccz = deg_match && dr_match
            method = "degree+delta_rank; equivalence inconclusive"
            evidence = "filters_match=$ccz"
        end

        ok = is_apn && is_perm && ccz
        all_ok = all_ok && ok
        name = exponent_names[exp]
        print_check(io, "class $cls -> x^$exp ($name): APN=$is_apn, perm=$is_perm, $evidence ($method)", ok)
    end

    print_kv(io, "stored controls checked", "$(length(class_to_exponent))")
    all_ok
end

# -------------------------------------------------------------------------
# Aggregate report
# -------------------------------------------------------------------------
function paper_report(io::IO = stdout)
    print_header(io)

    t1_ok  = table1_report(io)
    println(io)
    thm_ok = theorem1_report(io)
    println(io)
    n7_ok  = n7_monomials_report(io)

    print_section("Summary", io)
    print_check(io, "Table 1 admissibility (all n)", t1_ok)
    print_check(io, "n=6 stored witness CCZ-equivalent to Dillon (uniqueness unverified)", thm_ok)
    print_check(io, "n=7 equivalence evidence/filters (nonquadratic comparisons unresolved)", n7_ok)

    t1_ok && thm_ok && n7_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
