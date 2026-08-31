# bench/suites/03_spectra.jl — the spectra and statistics tier.
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
# WHAT THIS SUITE SHOWS
#   The cryptanalytic tables cost `O(2^2n)` in time and in memory. The DDT and
#   the LAT sweep n = 6, 8, 10 and 12, so the table shows that quadratic growth.
#   The BCT and the FBCT cost `O(2^3n)`, because every cell starts its own scan
#   over the input space. Their sweep is n = 8, 10 and 12. The streamed scans
#   keep one counter row only, so they reach n = 14 and n = 16.
#
#   Every boomerang case uses a permutation, because `bct` inverts its input.
#   Two operations come as an APN/random pair. No table scan in this tier stops
#   early on a large entry, so the `differential_uniformity` pair reports equal
#   times. The `table_anomaly` pair behaves in the opposite way. An APN function
#   ties the largest DDT entry in about 2^15 cells, and that tie count sets the
#   length of a binomial sum. The APN case is then four orders of magnitude
#   slower than the random one.

function register!(reg)
    G = "spectra"

    # ── differential distribution table ─────────────────────────────────────
    # The full table holds 2^2n words. At n = 12 it needs 134 MB.
    for n in (6, 8, 10, 12)
        bench!(reg; group = G, name = "ddt", n = n, cost = n ≥ 12 ? 2 : 1,
               setup = () -> gold_apn(n, 1),
               call  = F -> ddt(F),
               note  = "full 2^n x 2^n table")
    end

    # The streamed histogram holds one counter row, so memory stays at O(2^n).
    for (n, c) in ((12, 2), (16, 3))
        bench!(reg; group = G, name = "differential_spectrum", n = n, cost = c,
               setup = () -> gold_apn(n, 1),
               call  = F -> differential_spectrum(F),
               reps  = c == 3 ? 1 : 0,
               note  = "streamed DDT histogram")
    end

    # The APN case and the random case cost the same. The scan reads every cell
    # and a large entry does not stop it.
    bench!(reg; group = G, name = "differential_uniformity_apn", n = 14,
           cost = 2,
           setup = () -> gold_apn(14, 1),
           call  = F -> differential_uniformity(F),
           note  = "streamed DDT peak, APN")

    bench!(reg; group = G, name = "differential_uniformity_random", n = 14,
           cost = 2,
           setup = () -> random_function_sbox(Xoshiro(11), Val(14)),
           call  = F -> differential_uniformity(F),
           note  = "streamed DDT peak, random")

    # ── linear approximation table ──────────────────────────────────────────
    # `lat` runs one fast Walsh-Hadamard transform for each output mask.
    for n in (6, 8, 10, 12)
        bench!(reg; group = G, name = "lat", n = n, cost = n ≥ 12 ? 2 : 1,
               setup = () -> gold_apn(n, 1),
               call  = F -> lat(F),
               note  = "one FWHT per output mask")
    end

    bench!(reg; group = G, name = "absolute_walsh_spectrum", n = 12, cost = 2,
           setup = () -> gold_apn(12, 1),
           call  = F -> absolute_walsh_spectrum(F),
           note  = "LAT magnitude histogram")

    bench!(reg; group = G, name = "linearity", n = 12, cost = 2,
           setup = () -> gold_apn(12, 1),
           call  = F -> linearity(F),
           note  = "LAT peak")

    bench!(reg; group = G, name = "nonlinearity", n = 10, cost = 1,
           setup = () -> gold_apn(10, 1),
           call  = F -> nonlinearity(F),
           note  = "distance to the affine maps")

    bench!(reg; group = G, name = "walsh_power_moment", n = 12, cost = 2,
           setup = () -> gold_apn(12, 1),
           call  = F -> walsh_power_moment(F, 4),
           note  = "fourth Walsh power moment")

    # ── fast Walsh-Hadamard transform ───────────────────────────────────────
    # The three entry points share one width, so the table compares them
    # directly. The in-place kernel keeps its buffer between calls, so the
    # values grow and then wrap. Machine integers wrap at a constant cost, so
    # the measurement stays correct.
    #
    # The export layer removes the punctuation from a case name. The allocating
    # entry point therefore needs the suffix `_alloc`, or its LaTeX command
    # would clash with the command of the in-place kernel.
    bench!(reg; group = G, name = "walsh_hadamard!", n = 20, cost = 1,
           setup = () -> rand(Xoshiro(3), Int[-1, 1], 1 << 20),
           call  = v -> walsh_hadamard!(v),
           note  = "in-place FWHT kernel")

    bench!(reg; group = G, name = "walsh_hadamard_alloc", n = 20, cost = 1,
           setup = () -> rand(Xoshiro(3), Int[-1, 1], 1 << 20),
           call  = v -> walsh_hadamard(v),
           note  = "FWHT with a new buffer")

    bench!(reg; group = G, name = "walsh_transform", n = 20, cost = 1,
           setup = () -> rand(Xoshiro(3), Int[0, 1], 1 << 20),
           call  = f -> walsh_transform(f),
           note  = "encode the signs, then FWHT")

    # ── boomerang connectivity table ────────────────────────────────────────
    # `bct` needs a permutation, because it inverts its input. The cost is
    # O(2^3n): every cell of the table starts a new scan over the inputs.
    for (n, c) in ((8, 1), (10, 2), (12, 3))
        bench!(reg; group = G, name = "bct", n = n, cost = c,
               setup = () -> random_permutation_sbox(Xoshiro(11), Val(n)),
               call  = F -> bct(F),
               reps  = c == 3 ? 1 : 0,
               note  = "cubic-cost boomerang table")
    end

    bench!(reg; group = G, name = "fbct", n = 10, cost = 2,
           setup = () -> random_permutation_sbox(Xoshiro(11), Val(10)),
           call  = F -> fbct(F),
           note  = "Feistel boomerang table")

    bench!(reg; group = G, name = "boomerang_spectrum", n = 8, cost = 1,
           setup = () -> random_permutation_sbox(Xoshiro(11), Val(8)),
           call  = F -> boomerang_spectrum(F),
           note  = "BCT histogram")

    # The Gold function x^3 on 9 bits is an APN permutation.
    bench!(reg; group = G, name = "boomerang_uniformity", n = 9, cost = 1,
           setup = () -> gold_apn(9, 1),
           call  = F -> boomerang_uniformity(F),
           note  = "BCT peak, APN permutation")

    bench!(reg; group = G, name = "fbct_uniformity", n = 9, cost = 1,
           setup = () -> random_permutation_sbox(Xoshiro(11), Val(9)),
           call  = F -> fbct_uniformity(F),
           note  = "FBCT peak")

    # ── algebraic degree ────────────────────────────────────────────────────
    # Both cases cost O(n · 2^n) through the Mobius transform. At n = 16 they
    # are still fast.
    bench!(reg; group = G, name = "algebraic_degree", n = 16, cost = 1,
           setup = () -> random_function_sbox(Xoshiro(11), Val(16)),
           call  = F -> algebraic_degree(F),
           note  = "heaviest monomial in the ANF")

    bench!(reg; group = G, name = "degree_spectrum", n = 16, cost = 1,
           setup = () -> random_function_sbox(Xoshiro(11), Val(16)),
           call  = F -> degree_spectrum(F),
           note  = "per-coordinate degrees")

    # ── linear structures ───────────────────────────────────────────────────
    # Both cases build the full DDT first, so they inherit the O(2^2n) cost.
    bench!(reg; group = G, name = "linear_structures", n = 12, cost = 2,
           setup = () -> gold_apn(12, 1),
           call  = F -> linear_structures(F),
           note  = "DDT cells that hold 2^n")

    # The identity map has 2^n - 1 linear structures. It is the worst case for
    # the output vector.
    bench!(reg; group = G, name = "has_linear_structure", n = 10, cost = 1,
           setup = () -> SBox(collect(UInt16, 0:((1 << 10) - 1))),
           call  = F -> has_linear_structure(F),
           note  = "identity, all structures present")

    # ── anomaly framework ───────────────────────────────────────────────────
    # These cases use arbitrary-precision arithmetic. Their cost depends on the
    # precision and on the value range, not on the width of the S-box.
    bench!(reg; group = G, name = "ddt_coeff_probability", n = 8, cost = 1,
           setup = () -> (8, 8, collect(0:2:64)),
           call  = p -> begin
               n, m, cs = p
               acc = BigFloat(0)
               for c in cs
                   acc += ddt_coeff_probability(n, m, c)
               end
               acc
           end,
           note  = "33 DDT coefficient masses")

    bench!(reg; group = G, name = "expected_max_distribution", n = 8, cost = 1,
           setup = () -> (8, 8, ddt_coeff_probability, 255 * 255),
           call  = p -> expected_max_distribution(p[1], p[2], p[3], p[4];
                                                  vmax = 32),
           note  = "maximum of i.i.d. DDT cells")

    bench!(reg; group = G,
           name = "expected_differential_uniformity_distribution",
           n = 8, cost = 1,
           setup = () -> 8,
           call  = n -> expected_differential_uniformity_distribution(n),
           note  = "random-function DDT peak")

    bench!(reg; group = G, name = "expected_linearity_distribution", n = 8,
           cost = 1,
           setup = () -> 8,
           call  = n -> expected_linearity_distribution(n),
           note  = "random-permutation LAT peak")

    # The BCT mass function needs large binomial products, so this case is 20
    # times slower than the two above.
    bench!(reg; group = G,
           name = "expected_boomerang_uniformity_distribution",
           n = 8, cost = 2,
           setup = () -> 8,
           call  = n -> expected_boomerang_uniformity_distribution(n),
           note  = "random-permutation BCT peak")

    # A random permutation ties its largest DDT entry in a few cells only, so
    # the binomial sum is short.
    bench!(reg; group = G, name = "table_anomaly_random", n = 8, cost = 1,
           setup = () -> random_permutation_sbox(Xoshiro(11), Val(8)),
           call  = F -> table_anomaly(F, :DDT),
           note  = "DDT anomaly, few ties")

    bench!(reg; group = G, name = "table_negative_anomaly", n = 8, cost = 1,
           setup = () -> random_permutation_sbox(Xoshiro(11), Val(8)),
           call  = F -> table_negative_anomaly(F, :DDT),
           note  = "negative DDT anomaly")

    # An APN function holds the value 2 in about 2^15 DDT cells. The tie count
    # sets the length of the binomial sum, so this case is much slower than the
    # random one above.
    bench!(reg; group = G, name = "table_anomaly_apn", n = 8, cost = 3,
           setup = () -> gold_apn(8, 1),
           call  = F -> table_anomaly(F, :DDT),
           reps  = 1,
           note  = "DDT anomaly, 2^15 ties")

    # ── spectrum container ──────────────────────────────────────────────────
    # The histogram uses a hash map, so one insertion costs about 11 ns.
    bench!(reg; group = G, name = "spectrum_build", n = 20, cost = 1,
           setup = () -> rand(Xoshiro(3), 0:64, 1 << 20),
           call  = vs -> begin
               s = Spectrum()
               for v in vs
                   add!(s, v)
               end
               s
           end,
           note  = "2^20 add! calls")

    bench!(reg; group = G, name = "spectrum_read", n = 20, cost = 1,
           setup = () -> Spectrum(rand(Xoshiro(3), 0:64, 1 << 20)),
           call  = s -> (sorted_pairs(s), total_mass(s)),
           note  = "sorted_pairs and total_mass")

    return reg
end
