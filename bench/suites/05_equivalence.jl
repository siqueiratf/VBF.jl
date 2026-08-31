# bench/suites/05_equivalence.jl — the equivalence tier: linear, affine, EA, CCZ.
#
# CONTRACT (every suite file in this directory follows it):
#   * The file defines exactly one function, `register!(reg)`.
#   * The function calls `bench!` once per case and measures nothing itself.
#   * `setup` is a zero-argument function that returns the payload. The harness
#     does not time it. Put every allocation that the case does not measure here.
#   * `call` takes that payload and does the work that the case measures.
#   * `cost` is 1 (under about 0.1 s), 2 (under about 5 s) or 3 (minutes).
#   * `note` is one short phrase for the reader of the thesis table.
#
# This tier is the most expensive one in the library. Two extra rules apply:
#
#   * Every search that accepts a bound gets an explicit bound. The library has
#     combinatorial searches that run for hours without one.
#   * Every decision procedure gets two cases, one for the positive answer and
#     one for the negative answer. The two answers take different code paths and
#     the costs differ by orders of magnitude. The `note` says which answer the
#     case measures.
#
# The dimensions come from bench/calibration.toml. That file records 3.0 s for
# the exact n = 7 EA decision and 395 s for the n = 8 decision, so n = 7 is the
# largest dimension for the ortho-derivative search here. Three searches were
# measured and then dropped because one call needs more than 300 s:
# `enumerate_ccz_class` at n = 7, `automorphisms_from_ortho_derivative` at
# n = 8, and `ea_mappings_from_ortho_derivative` at n = 8.

function register!(reg)
    G = "equivalence"

    # A linear-equivalent copy of F: L1 ∘ F ∘ L2 with random invertible maps.
    # The copy has a different LUT, so a decision procedure cannot answer from
    # LUT equality alone. The seed makes the copy the same on every run.
    lin_copy = function (F, seed::Int)
        n = inputbits(F)
        T = storage_type(F)
        rng = Xoshiro(seed)
        L1 = random_invertible_linear_map(rng, Val(n), T)
        L2 = random_invertible_linear_map(rng, Val(n), T)
        return SBox{n,T}(T[L1(F.lut[L2(T(x))+1]) for x = 0:((1 << n) - 1)])
    end

    # An affine-equivalent copy of F: A1 ∘ F ∘ A2 with random invertible affine
    # maps. The copy is affine-equivalent to F but not linearly equivalent, so
    # the affine test must scan the shift anchors before it answers.
    aff_copy = function (F, seed::Int)
        n = inputbits(F)
        T = storage_type(F)
        rng = Xoshiro(seed)
        A1 = random_affine_permutation(rng, Val(n), T)
        A2 = random_affine_permutation(rng, Val(n), T)
        return SBox{n,T}(T[A1(F.lut[A2(T(x))+1]) for x = 0:((1 << n) - 1)])
    end

    # ── linear equivalence ──────────────────────────────────────────────────

    bench!(reg; group = G, name = "are_linear_equivalent_pos", n = 5, cost = 1,
           setup = () -> (F = gold_apn(5, 1); (F, lin_copy(F, 11))),
           call  = p -> are_linear_equivalent(p[1], p[2]),
           note  = "positive answer at n=5")

    bench!(reg; group = G, name = "are_linear_equivalent_neg", n = 5, cost = 1,
           setup = () -> (gold_apn(5, 1), kasami_apn(5, 2)),
           call  = p -> are_linear_equivalent(p[1], p[2]),
           note  = "negative answer, Gold against Kasami")

    bench!(reg; group = G, name = "are_linear_equivalent_neg", n = 7, cost = 2,
           setup = () -> (gold_apn(7, 1), kasami_apn(7, 2)),
           call  = p -> are_linear_equivalent(p[1], p[2]),
           note  = "negative answer at n=7")

    bench!(reg; group = G, name = "linear_representative", n = 7, cost = 2,
           setup = () -> gold_apn(7, 1),
           call  = F -> linear_representative(F),
           note  = "Stennes canonical form")

    bench!(reg; group = G, name = "self_linear_equivalences", n = 5, cost = 1,
           setup = () -> gold_apn(5, 1),
           call  = F -> self_linear_equivalences(F),
           note  = "the linear self-equivalence group")

    bench!(reg; group = G, name = "linear_equivalences", n = 7, cost = 3,
           setup = () -> (F = gold_apn(7, 1); (F, F)),
           call  = p -> linear_equivalences(p[1], p[2]),
           note  = "every pair, positive answer")

    bench!(reg; group = G, name = "are_linearly_equivalent_general", n = 6,
           cost = 2,
           setup = () -> (gold_apn(6, 1), kim_apn()),
           call  = p -> are_linearly_equivalent_general(p[1], p[2]),
           note  = "negative answer, two non-permutations")

    bench!(reg; group = G, name = "linear_equivalences_general", n = 6, cost = 2,
           setup = () -> (F = gold_apn(6, 1); (F, F)),
           call  = p -> linear_equivalences_general(p[1], p[2]),
           note  = "every pair, non-permutation input")

    bench!(reg; group = G, name = "are_sets_linear_equivalent", n = 6, cost = 1,
           setup = () -> begin
               F = gold_apn(6, 1)
               A = sort!(collect(Set(Int.(F.lut))))
               L = random_invertible_linear_map(Xoshiro(11), Val(6))
               B = sort!([Int(L(UInt8(a))) for a in A])
               (A, B)
           end,
           call  = p -> are_sets_linear_equivalent(p[1], p[2], 6),
           note  = "positive answer on image sets")

    # ── 3-to-1 and triplicate functions ─────────────────────────────────────

    bench!(reg; group = G, name = "triplicate_adjoints", n = 6, cost = 1,
           setup = () -> gold_apn(6, 1),
           call  = F -> triplicate_adjoints(F),
           note  = "every triplicate adjoint")

    bench!(reg; group = G, name = "self_3to1_linear_equivalences", n = 6,
           cost = 1,
           setup = () -> gold_apn(6, 1),
           call  = C -> self_3to1_linear_equivalences(C),
           note  = "the 3-to-1 self-equivalence group")

    bench!(reg; group = G, name = "canonical_3to1_representative", n = 6,
           cost = 1,
           setup = () -> gold_apn(6, 1),
           call  = F -> canonical_3to1_representative(F),
           note  = "the canonical triplicate")

    # ── affine equivalence ──────────────────────────────────────────────────

    bench!(reg; group = G, name = "are_affine_equivalent_pos", n = 5, cost = 1,
           setup = () -> (F = gold_apn(5, 1); (F, aff_copy(F, 23))),
           call  = p -> are_affine_equivalent(p[1], p[2]),
           note  = "positive answer at n=5")

    bench!(reg; group = G, name = "are_affine_equivalent_neg", n = 5, cost = 2,
           setup = () -> (gold_apn(5, 1), kasami_apn(5, 2)),
           call  = p -> are_affine_equivalent(p[1], p[2]),
           note  = "negative answer, all anchors")

    bench!(reg; group = G, name = "affine_class_signature", n = 6, cost = 2,
           setup = () -> dillon_apn_permutation(),
           call  = F -> affine_class_signature(F),
           note  = "one representative per anchor")

    bench!(reg; group = G, name = "are_affine_equivalent_neg", n = 7, cost = 3,
           setup = () -> (gold_apn(7, 1), kasami_apn(7, 2)),
           call  = p -> are_affine_equivalent(p[1], p[2]),
           note  = "negative answer at n=7")

    bench!(reg; group = G, name = "affine_representative", n = 7, cost = 3,
           setup = () -> gold_apn(7, 1),
           call  = F -> affine_representative(F),
           note  = "canonical affine form at n=7")

    # ── EA equivalence: the partition machinery ─────────────────────────────

    bench!(reg; group = G, name = "ea_partition", n = 8, cost = 1,
           setup = () -> gold_apn(8, 1),
           call  = F -> ea_partition(F, 4),
           note  = "the k=4 multiplicity partition")

    bench!(reg; group = G, name = "enumerate_bucket_maps", n = 6, cost = 1,
           setup = () -> (p = ea_partition(dillon_apn_permutation(), 4); (p, p)),
           call  = p -> enumerate_bucket_maps(p[1], p[2]; max_maps = 10^4),
           note  = "bounded bucket maps")

    bench!(reg; group = G, name = "outer_permutations", n = 4, cost = 1,
           setup = () -> begin
               p = ea_partition(SBox{4}(gf_monomial_lut(4, 7)), 4)
               (p, collect(1:nbuckets(p)))
           end,
           call  = p -> outer_permutations(p[1], p[1], p[2], UInt8),
           note  = "partition-preserving outer maps")

    bench!(reg; group = G, name = "inner_permutation", n = 6, cost = 1,
           setup = () -> (F = dillon_apn_permutation(); (F, F)),
           call  = p -> inner_permutation(p[1], p[2]),
           note  = "inner map, positive answer")

    # The outer search becomes very large at n = 6. This case builds 14.4 million
    # maps and holds about 1.7 GB. It shows the limit of the outer enumeration.
    bench!(reg; group = G, name = "partition_automorphisms", n = 6, cost = 3,
           setup = () -> dillon_apn_permutation(),
           call  = F -> partition_automorphisms(F, 4),
           note  = "the partition automorphism group")

    # ── EA equivalence: the decision procedures ─────────────────────────────

    bench!(reg; group = G, name = "are_ea_equivalent_pos", n = 5, cost = 1,
           setup = () -> (F = gold_apn(5, 1); (F, lin_copy(F, 11))),
           call  = p -> are_ea_equivalent(p[1], p[2];
                                          max_outer_per_sigma = 10^6,
                                          max_inner_affine = 10^7),
           note  = "positive, ortho-derivative test")

    bench!(reg; group = G, name = "are_ea_equivalent_neg_heggebakk", n = 5,
           cost = 2,
           setup = () -> (gold_apn(5, 1), kasami_apn(5, 2)),
           call  = p -> are_ea_equivalent(p[1], p[2]; strategy = :heggebakk,
                                          max_outer_per_sigma = 10^6,
                                          max_inner_affine = 10^7,
                                          on_inconclusive = :best_effort),
           note  = "negative, capped Heggebakk search")

    bench!(reg; group = G, name = "are_ea_equivalent_pos", n = 8, cost = 2,
           setup = () -> (F = gold_apn(8, 1); (F, lin_copy(F, 11))),
           call  = p -> are_ea_equivalent(p[1], p[2];
                                          max_outer_per_sigma = 10^6,
                                          max_inner_affine = 10^7),
           note  = "positive answer at n=8")

    bench!(reg; group = G, name = "are_ea_equivalent_neg", n = 8, cost = 1,
           setup = () -> (gold_apn(8, 1), gold_apn(8, 3)),
           call  = p -> are_ea_equivalent(p[1], p[2];
                                          max_outer_per_sigma = 10^6,
                                          max_inner_affine = 10^7),
           note  = "negative answer at n=8")

    bench!(reg; group = G, name = "ea_equivalences", n = 4, cost = 2,
           setup = () -> (F = SBox{4}(gf_monomial_lut(4, 7)); (F, F)),
           call  = p -> ea_equivalences(p[1], p[2];
                                        max_outer_per_sigma = 10^5),
           note  = "every EA map at n=4")

    # ── CCZ equivalence ─────────────────────────────────────────────────────

    bench!(reg; group = G, name = "code_weight_enumerator", n = 8, cost = 1,
           setup = () -> ccz_matrix(gold_apn(8, 1)),
           call  = M -> code_weight_enumerator(M),
           note  = "weight enumerator of the CCZ code")

    bench!(reg; group = G, name = "are_ccz_equivalent_neg", n = 6, cost = 1,
           setup = () -> (dillon_apn_permutation(),
                          random_permutation_sbox(Xoshiro(3), Val(6))),
           call  = p -> are_ccz_equivalent(p[1], p[2]; max_class_reps = 10^4,
                                           ea_max_outer_per_sigma = 10^6,
                                           on_inconclusive = :best_effort),
           note  = "negative, invariant rejects the pair")

    bench!(reg; group = G, name = "enumerate_ccz_class", n = 6, cost = 2,
           setup = () -> kim_apn(),
           call  = F -> enumerate_ccz_class(F),
           note  = "EA representatives of the class")

    bench!(reg; group = G, name = "is_ccz_equivalent_to_permutation", n = 6,
           cost = 2,
           setup = () -> kim_apn(),
           call  = F -> is_ccz_equivalent_to_permutation(F),
           note  = "positive answer for the Kim function")

    bench!(reg; group = G, name = "get_tu_decompositions", n = 6, cost = 2,
           setup = () -> dillon_apn_permutation(),
           call  = F -> get_tu_decompositions(F),
           note  = "every TU decomposition")

    bench!(reg; group = G, name = "are_ccz_equivalent_pos", n = 6, cost = 2,
           setup = () -> (kim_apn(), dillon_apn_permutation()),
           call  = p -> are_ccz_equivalent(p[1], p[2]; max_class_reps = 10^4,
                                           ea_max_outer_per_sigma = 10^6,
                                           on_inconclusive = :best_effort),
           note  = "positive, Kim against Dillon")

    bench!(reg; group = G, name = "ea_mappings_from_ortho_derivative_pos",
           n = 7, cost = 2,
           setup = () -> (F = gold_apn(7, 1); (F, F)),
           call  = p -> ea_mappings_from_ortho_derivative(p[1], p[2]),
           note  = "exact EA decision, positive")

    bench!(reg; group = G, name = "ea_mappings_from_ortho_derivative_neg",
           n = 7, cost = 2,
           setup = () -> (gold_apn(7, 1), gold_apn(7, 3)),
           call  = p -> ea_mappings_from_ortho_derivative(p[1], p[2]),
           note  = "exact EA decision, negative")

    return reg
end
