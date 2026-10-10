# packages/VBF/perf/suites/06_constructions.jl — the constructions and the search tier.
#
# CONTRACT (the same one that packages/VBF/perf/suites/01_representations.jl states):
#   * The file defines exactly one function, `register!(reg)`.
#   * The function calls `benchmark!` once per case and measures nothing itself.
#   * `setup` is a zero-argument function that returns the payload. BenchmarkTools
#     does not time it. Put every allocation that the case does not measure here.
#   * `call` takes that payload and does the work that the case measures.
#   * `cost` is 1 (under about 0.1 s), 2 (under about 5 s) or 3 (minutes).
#   * `note` is one short phrase for the reader of the thesis table.
#
# BOUNDS. This tier holds the exhaustive searches. Their spaces are very large,
# so every search case gives an explicit bound, and the `note` field states it:
#   * `search_qam` and `search_qam_full` take `limit` and `max_evaluations`.
#   * `search_quadratic_apn`, `search_quadratic_apn_le` and
#     `extend_quadratic_apn` take `limit`.
# A search case without a bound is a defect, not a measurement.
#
# Two exported enumerations have no bound parameter at all:
# `enumerate_ea_classes_apn_quadratic` and `ccz_equivalent_quadratic_function`.
# Both walk a full CCZ-class. This suite does not register them, because the
# suite cannot bound them.

function register!(reg)
    G = "constructions"

    # ── APN power families ──────────────────────────────────────────────────
    # Each constructor builds a full 2^n lookup table, so the cost doubles for
    # each increase of n by one. Gold and Kasami accept an even n. Welch, Niho
    # and the field inverse need an odd n. Dobbertin needs a multiple of 5.

    for n in (6, 8, 10)
        benchmark!(reg; group = G, name = "gold_apn", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n)),
               call  = p -> gold_apn(p[1], 1; modulus = p[2]),
               note  = "Gold x^3 power table")
    end

    # k must be coprime to n, so the value of k changes with n.
    for (n, k) in ((6, 5), (8, 3), (10, 3))
        benchmark!(reg; group = G, name = "kasami_apn", n = n, cost = 1,
               setup = () -> (n, k, primitive_polynomial(n)),
               call  = p -> kasami_apn(p[1], p[2]; modulus = p[3]),
               note  = "Kasami power table")
    end

    for n in (7, 9, 11)
        benchmark!(reg; group = G, name = "welch_apn", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n)),
               call  = p -> welch_apn(p[1]; modulus = p[2]),
               note  = "Welch power table")
    end

    for n in (7, 9, 11)
        benchmark!(reg; group = G, name = "niho_apn", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n)),
               call  = p -> niho_apn(p[1]; modulus = p[2]),
               note  = "Niho power table")
    end

    for n in (7, 9, 11)
        benchmark!(reg; group = G, name = "inverse_apn", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n)),
               call  = p -> inverse_apn(p[1]; modulus = p[2]),
               note  = "field inverse table")
    end

    for n in (5, 10)
        benchmark!(reg; group = G, name = "dobbertin_apn", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n)),
               call  = p -> dobbertin_apn(p[1]; modulus = p[2]),
               note  = "Dobbertin power table")
    end

    benchmark!(reg; group = G, name = "known_apn_monomials", n = 11, cost = 1,
           setup = () -> (11, primitive_polynomial(11)),
           call  = p -> known_apn_monomials(p[1]; modulus = p[2]),
           note  = "five families at once")

    # ── quadratic APN binomials and named instances ─────────────────────────

    benchmark!(reg; group = G, name = "bcp_apn", n = 12, cost = 1,
           setup = () -> (4, 1, primitive_polynomial(12)),
           call  = p -> bcp_apn(p[1], p[2]; modulus = p[3]),
           note  = "BCP binomial, k=4 s=1")

    benchmark!(reg; group = G, name = "bcl_apn", n = 12, cost = 1,
           setup = () -> (3, 1, primitive_polynomial(12)),
           call  = p -> bcl_apn(p[1], p[2]; modulus = p[3]),
           note  = "BCL binomial, k=3 s=1")

    benchmark!(reg; group = G, name = "kim_apn", n = 6, cost = 1,
           setup = () -> nothing,
           call  = _ -> kim_apn(),
           note  = "Kim quadratic APN")

    benchmark!(reg; group = G, name = "taniguchi_apn", n = 10, cost = 1,
           setup = () -> (5, 1, 1, 1, primitive_polynomial(5)),
           call  = p -> taniguchi_apn(p[1], p[2], p[3], p[4]; modulus = p[5]),
           note  = "one Taniguchi member")

    # The half=4 sweep tests every admissible (m, a, b) and keeps one member per
    # EA fingerprint. It returns the three known classes on F2^8.
    benchmark!(reg; group = G, name = "taniguchi_apn_representatives",
           n = 8, cost = 2,
           setup = () -> (4, primitive_polynomial(4)),
           call  = p -> taniguchi_apn_representatives(p[1]; modulus = p[2]),
           note  = "three classes on F2^8")

    # ── quadratic APN matrices ──────────────────────────────────────────────

    benchmark!(reg; group = G, name = "quadratic_apn_matrix", n = 12, cost = 1,
           setup = () -> gold_apn(12, 1),
           call  = F -> quadratic_apn_matrix(F),
           note  = "derivative matrix of F")

    benchmark!(reg; group = G, name = "is_qam", n = 14, cost = 1,
           setup = () -> quadratic_apn_matrix(gold_apn(14, 1)),
           call  = M -> is_qam(M),
           note  = "rank test, 2^14 subsets")

    benchmark!(reg; group = G, name = "is_cyclic_qam", n = 12, cost = 1,
           setup = () -> quadratic_apn_matrix(gold_apn(12, 1)),
           call  = M -> is_cyclic_qam(M, 2),
           note  = "shift orbits only, m=2")

    benchmark!(reg; group = G, name = "qam_to_sbox", n = 12, cost = 1,
           setup = () -> quadratic_apn_matrix(gold_apn(12, 1)),
           call  = M -> qam_to_sbox(M),
           note  = "matrix back to S-box")

    benchmark!(reg; group = G, name = "independent_conjugate_elements",
           n = 12, cost = 1,
           setup = () -> (12, 3),
           call  = p -> independent_conjugate_elements(p[1], p[2]),
           note  = "Theorem 1 element set")

    benchmark!(reg; group = G, name = "cyclic_qam_subset_representatives",
           n = 20, cost = 1,
           setup = () -> (20, 2),
           call  = p -> cyclic_qam_subset_representatives(p[1], p[2]),
           note  = "Theorem 3 subset orbits")

    # ── compact quadratic univariate form ───────────────────────────────────

    benchmark!(reg; group = G, name = "encode_quadratic", n = 10, cost = 1,
           setup = () -> begin
               m = conway_polynomial(10)
               (gold_apn(10, 1; modulus = m), m)
           end,
           call  = p -> encode_quadratic(p[1]; modulus = p[2]),
           note  = "pack the coefficients")

    benchmark!(reg; group = G, name = "decode_quadratic_lut", n = 10, cost = 1,
           setup = () -> begin
               m = conway_polynomial(10)
               (encode_quadratic(gold_apn(10, 1; modulus = m); modulus = m), m)
           end,
           call  = p -> decode_quadratic_lut(p[1], 10, p[2]),
           note  = "rebuild the table")

    # ── trims and switching neighbours ──────────────────────────────────────

    benchmark!(reg; group = G, name = "trims", n = 8, cost = 2,
           setup = () -> gold_apn(8, 1),
           call  = F -> trims(F),
           note  = "all 2(2^8-1)^2 trims")

    benchmark!(reg; group = G, name = "apn_trims", n = 7, cost = 2,
           setup = () -> gold_apn(7, 1),
           call  = F -> apn_trims(F),
           note  = "keep the APN trims")

    benchmark!(reg; group = G, name = "trim_spectrum", n = 7, cost = 2,
           setup = () -> gold_apn(7, 1),
           call  = F -> trim_spectrum(F),
           note  = "EA fingerprints of trims")

    # The complete constraint system is O(2^(3n)). Thus n=7 is the maximum that
    # stays practical.
    benchmark!(reg; group = G, name = "switching_neighbors", n = 7, cost = 2,
           setup = () -> gold_apn(7, 1),
           call  = F -> switching_neighbors(F),
           note  = "Edel-Pott switching space")

    # ── bounded searches ────────────────────────────────────────────────────
    # Every case below states its bound. Read the `note` column for the value.

    # Bound: limit = 256 solutions. Without this limit the tree search runs to
    # the end of the space.
    benchmark!(reg; group = G, name = "search_quadratic_apn", n = 6, cost = 1,
           setup = () -> 256,
           call  = lim -> search_quadratic_apn(Val(6); limit = lim),
           note  = "limit 256 solutions")

    # Bound: limit = 1 solution. The tuples are the Beierle-Leander 2022 n=7
    # canonical classes. Class 1 admits a quadratic APN function.
    benchmark!(reg; group = G, name = "search_quadratic_apn_le", n = 7, cost = 1,
           setup = () -> begin
               path = joinpath(@__DIR__, "..", "fixtures", "le_automorphism_n7.toml")
               t = TOML.parsefile(path)["class1"]
               (Int.(t["A"]), Int.(t["B"]), Int.(t["pos"]), Int.(t["fix"]))
           end,
           call  = p -> search_quadratic_apn_le(p[1], p[2];
                                                pos = p[3], fix = p[4],
                                                limit = 1),
           note  = "BL22 class 1, limit 1")

    # Bound: limit = 8 classes and max_evaluations = 2^12 candidates.
    benchmark!(reg; group = G, name = "search_qam", n = 8, cost = 1,
           setup = () -> (8, 2),
           call  = p -> search_qam(p[1], p[2];
                                   limit = 8, max_evaluations = 1 << 12),
           note  = "limit 8, budget 2^12")

    # Bound: limit = 1 class and max_evaluations = 2^10 complete matrices.
    # The walk to the first complete matrix dominates the time.
    benchmark!(reg; group = G, name = "search_qam_full", n = 5, cost = 3,
           setup = () -> 5,
           call  = n -> search_qam_full(n;
                                        limit = 1, max_evaluations = 1 << 10),
           note  = "limit 1, budget 2^10")

    # Bound: limit = 1 extension. The n=6 to n=7 step examines the full linear
    # part. It is the second heaviest case in this suite.
    benchmark!(reg; group = G, name = "extend_quadratic_apn", n = 6, cost = 3,
           setup = () -> gold_apn(6, 1),
           call  = F -> extend_quadratic_apn(F; limit = 1),
           note  = "limit 1 extension")

    for (key,m) in collect(reg.metadata)
        key[1] == G || continue
        name=key[2]
        parameters = name == "search_qam" ? (;limit=8,max_evaluations=1<<12,confirm=false) :
            name == "search_qam_full" ? (;limit=1,max_evaluations=1<<10) :
            name == "search_quadratic_apn" ? (;limit=256) :
            name in ("search_quadratic_apn_le","extend_quadratic_apn") ? (;limit=1) : (;)
        reg.metadata[key]=merge(m,(;parameters))
    end
    return reg
end
