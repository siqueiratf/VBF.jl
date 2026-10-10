# packages/VBF/perf/suites/04_invariants.jl — the APN invariant tier.
#
# CONTRACT (every suite file in this directory follows it):
#   * The file defines exactly one function, `register!(reg)`.
#   * The function calls `benchmark!` once per case and measures nothing itself.
#   * `setup` is a zero-argument function that returns the payload. BenchmarkTools
#     does not time it. Put every allocation that the case does not measure here.
#   * `call` takes that payload and does the work that the case measures.
#   * `cost` is 1 (under about 0.1 s), 2 (under about 5 s) or 3 (minutes).
#   * `note` is one short phrase for the reader of the thesis table.
#
# SCOPE. This suite measures packages/VBF/src/invariants/. Every invariant here
# separates APN functions, so every payload must be APN. The `gold` helper
# builds the Gold function x^3 and asserts the differential uniformity is 2.
#
# TWO LIMITS CONTROL THE CHOICE OF n:
#   1. `gamma_rank` and `delta_rank` build a 2^{2n} x 2^{2n} matrix. The source
#      refuses n > 7. The suite keeps to that guard and stops at n = 7. The
#      calibration file records n = 7 at 3.66 s and n = 8 at about 167 s, so
#      n = 7 is the largest case and it is cost 2.
#   2. `image_subspaces` and `nonbent_signature` count the F2 subspaces inside a
#      set. The cost grows with the size of the set. The suite uses even n, where
#      Gold x^3 is 3-to-1 and both sets hold only (2^n - 1)/3 + 1 elements. For
#      odd n the image is the whole space and the count is intractable.

function register!(reg)
    G = "invariants"

    # The Gold APN function x^3 over GF(2^n). The assert proves the payload is
    # APN before the harness measures an invariant of it.
    gold = function (n)
        F = gold_apn(n, 1)
        @assert differential_uniformity(F) == 2
        F
    end

    # ── ortho-derivative: the workhorse EA-invariant ─────────────────────────
    # The measured cost grows by about 4x per bit. n = 13 is the first case that
    # goes above the fast level.
    for n in (8, 10, 12)
        benchmark!(reg; group = G, name = "ortho_derivative", n = n, cost = 1,
               setup = () -> gold(n),
               call  = F -> ortho_derivative(F),
               note  = "pi_F of Gold x^3")
    end

    benchmark!(reg; group = G, name = "ortho_derivative", n = 13, cost = 2,
           setup = () -> gold(13),
           call  = F -> ortho_derivative(F),
           note  = "pi_F at the practical limit")

    # ── the two APN predicates ──────────────────────────────────────────────
    benchmark!(reg; group = G, name = "is_quadratic_apn", n = 12, cost = 1,
           setup = () -> gold(12),
           call  = F -> is_quadratic_apn(F),
           note  = "accept through pi_F")

    for n in (12, 14)
        benchmark!(reg; group = G, name = "is_quadratic_apn_rank", n = n, cost = 1,
               setup = () -> gold(n),
               call  = F -> is_quadratic_apn_rank(F),
               note  = "accept through the rank test")
    end

    # The rank test stops at the first bad direction. It therefore rejects a
    # random map much faster than it accepts an APN one. This case measures the
    # screen that a large family search uses.
    benchmark!(reg; group = G, name = "is_quadratic_apn_rank_sweep", n = 12,
           cost = 1,
           setup = () -> begin
               rng = Xoshiro(11)
               [random_function_sbox(rng, Val(12)) for _ = 1:1024]
           end,
           call  = pool -> count(is_quadratic_apn_rank, pool),
           note  = "reject 1024 random maps")

    # ── ortho-integral: rebuild a quadratic APN from its ortho-derivative ────
    # The linear system holds n*2^n unknowns and 2^n(2^n - 1) equations, so the
    # cost grows by about 13x per bit: 0.04 s at n = 7, 0.39 s at n = 8, 5.5 s at
    # n = 9 and 67 s at n = 10. The source says the method is practical to n = 8,
    # and these two heavy cases show the limit.
    for (n, cost) in ((7, 1), (8, 2), (9, 3), (10, 3))
        benchmark!(reg; group = G, name = "ortho_integral", n = n, cost = cost,
               setup = () -> ortho_derivative(gold(n)),
               call  = pi_F -> ortho_integral(pi_F),
               note  = "rebuild Q from pi_F")
    end

    # ── sigma multiplicities: a Walsh power moment CCZ-invariant ─────────────
    for (n, cost) in ((8, 1), (10, 1), (12, 2))
        benchmark!(reg; group = G, name = "sigma_multiplicities", n = n,
               cost = cost,
               setup = () -> gold(n),
               call  = F -> sigma_multiplicities(F),
               note  = "sigma multiset at k = 4")
    end

    # ── the APN-EA mugshot ──────────────────────────────────────────────────
    # The quadratic path hashes the Walsh and DDT spectra of pi_F. Gold x^3 has
    # degree 2, so it takes that path.
    for (n, cost) in ((8, 1), (10, 1), (12, 2))
        benchmark!(reg; group = G, name = "apn_ea_mugshot", n = n, cost = cost,
               setup = () -> gold(n),
               call  = F -> apn_ea_mugshot(F),
               note  = "quadratic path through pi_F")
    end

    # The fallback path runs when the degree is not 2. For a permutation it also
    # computes the thickness spectrum, and that step controls the cost. Kasami
    # x^13 has degree 3. The Dillon permutation has degree 4.
    benchmark!(reg; group = G, name = "apn_ea_mugshot", n = 5, cost = 1,
           setup = () -> begin
               F = kasami_apn(5, 2)
               @assert differential_uniformity(F) == 2
               F
           end,
           call  = F -> apn_ea_mugshot(F),
           note  = "fallback path, Kasami x^13")

    benchmark!(reg; group = G, name = "apn_ea_mugshot", n = 6, cost = 2,
           setup = () -> begin
               F = dillon_apn_permutation()
               @assert differential_uniformity(F) == 2
               F
           end,
           call  = F -> apn_ea_mugshot(F),
           note  = "fallback path, Dillon permutation")

    benchmark!(reg; group = G, name = "component_degree_spectrum", n = 12,
           cost = 1,
           setup = () -> gold(12),
           call  = F -> component_degree_spectrum(F),
           note  = "degrees of the components")

    # ── design 2-ranks (Edel and Pott) ──────────────────────────────────────
    # The source guard refuses n > 7. Do not raise these widths.
    for (n, cost) in ((5, 1), (6, 1), (7, 2))
        benchmark!(reg; group = G, name = "gamma_rank", n = n, cost = cost,
               setup = () -> gold(n),
               call  = F -> gamma_rank(F),
               note  = "F2 rank of dev(G_F)")
    end

    # The Delta-rank is bounded by 2^{n+1}, so its elimination stops much
    # earlier than the Gamma-rank one and the case is cheaper.
    for (n, cost) in ((6, 1), (7, 2))
        benchmark!(reg; group = G, name = "delta_rank", n = n, cost = cost,
               setup = () -> gold(n),
               call  = F -> delta_rank(F),
               note  = "F2 rank of dev(D_F)")
    end

    # ── bent components and the Gologlu signature ───────────────────────────
    # Bent components exist only for even n, so these cases use even widths.
    benchmark!(reg; group = G, name = "bent_components", n = 10, cost = 1,
           setup = () -> gold(10),
           call  = F -> bent_components(F),
           note  = "scan the LAT for flat rows")

    benchmark!(reg; group = G, name = "nonbent_components", n = 10, cost = 1,
           setup = () -> gold(10),
           call  = F -> nonbent_components(F),
           note  = "complement of the bent set")

    for (n, cost) in ((8, 1), (10, 2))
        benchmark!(reg; group = G, name = "nonbent_signature", n = n, cost = cost,
               setup = () -> gold(n),
               call  = F -> nonbent_signature(F),
               note  = "Gologlu subspace counts")
    end

    # ── image-set structure ─────────────────────────────────────────────────
    benchmark!(reg; group = G, name = "image_set", n = 10, cost = 1,
           setup = () -> gold(10),
           call  = F -> image_set(F),
           note  = "distinct output values")

    for (n, cost) in ((8, 1), (10, 2))
        benchmark!(reg; group = G, name = "image_subspaces", n = n, cost = cost,
               setup = () -> gold(n),
               call  = F -> image_subspaces(F),
               note  = "subspaces inside the image")
    end

    # ── the Pi_F multiset ───────────────────────────────────────────────────
    for n in (10, 12)
        benchmark!(reg; group = G, name = "pi_multiset", n = n, cost = 1,
               setup = () -> gold(n),
               call  = F -> pi_multiset(F, 0),
               note  = "shifted derivative histogram")
    end

    return reg
end
