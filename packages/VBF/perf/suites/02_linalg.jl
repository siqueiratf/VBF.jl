# packages/VBF/perf/suites/02_linalg.jl — the GF(2) linear-algebra tier.
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
# The library packs one matrix row into one unsigned word. Bit `c` of the word
# is column `c`. A sweep of `n` therefore selects the matrix width and the
# storage type at the same time. The suite pairs each `n` with the smallest
# word that holds `n` bits, except where a comment gives a different reason.

function register!(reg)
    G = "linalg"

    # ── bit primitives ──────────────────────────────────────────────────────
    #
    # Both primitives are one machine instruction. The loop makes the cost
    # measurable above the timer noise.
    benchmark!(reg; group = G, name = "parity", n = 64, cost = 1,
           setup = () -> rand(UInt64, 4096),
           call  = xs -> begin
               acc = 0
               for x in xs
                   acc ⊻= parity(x)
               end
               acc
           end,
           note  = "4096 parity calls")

    benchmark!(reg; group = G, name = "f2_dot", n = 64, cost = 1,
           setup = () -> (rand(UInt64, 4096), rand(UInt64, 4096)),
           call  = p -> begin
               a, b = p
               acc = 0
               for i in eachindex(a)
                   acc ⊻= f2_dot(a[i], b[i])
               end
               acc
           end,
           note  = "4096 inner products")

    # ── Gauss-Jordan elimination ────────────────────────────────────────────
    #
    # `gauss_jordan!` writes over its input. The call copies the rows into a
    # scratch buffer first, so every repetition starts from the same matrix.
    # The copy is n words and stays far below the cost of the reduction.
    for (n, T) in ((8, UInt8), (16, UInt16), (32, UInt32), (64, UInt64))
        benchmark!(reg; group = G, name = "gauss_jordan", n = n, cost = 1,
               setup = () -> (rand(T, n), Vector{T}(undef, n)),
               call  = p -> begin
                   rows, work = p
                   copyto!(work, rows)
                   gauss_jordan!(work; nbits = n)
               end,
               note  = "reduce a square matrix")
    end

    for (n, T) in ((32, UInt32), (64, UInt64))
        benchmark!(reg; group = G, name = "rank_f2", n = n, cost = 1,
               setup = () -> rand(T, n),
               call  = rows -> rank_f2(rows; nbits = n),
               note  = "rank without mutation")
    end

    benchmark!(reg; group = G, name = "linear_basis", n = 64, cost = 1,
           setup = () -> rand(UInt64, 64),
           call  = rows -> linear_basis(rows; nbits = 64),
           note  = "echelon basis of a span")

    # The basis holds 32 of the 64 dimensions. Almost no random probe is in the
    # span, so each test walks the full basis.
    benchmark!(reg; group = G, name = "is_in_span", n = 64, cost = 1,
           setup = () -> (linear_basis(rand(UInt64, 32); nbits = 64),
                          rand(UInt64, 1024)),
           call  = p -> begin
               basis, probes = p
               hits = 0
               for v in probes
                   hits += is_in_span(v, basis; nbits = 64)
               end
               hits
           end,
           note  = "1024 span tests")

    # `complete_basis` runs one full reduction per vector that it adds. The
    # half basis makes the routine add n/2 vectors.
    for (n, T) in ((32, UInt32), (64, UInt64))
        benchmark!(reg; group = G, name = "complete_basis", n = n, cost = 1,
               setup = () -> linear_basis(rand(T, n ÷ 2); nbits = n),
               call  = partial -> complete_basis(partial, n),
               note  = "extend a half basis")
    end

    benchmark!(reg; group = G, name = "complete_basis_reversed", n = 64, cost = 1,
           setup = () -> linear_basis(rand(UInt64, 32); nbits = 64),
           call  = partial -> complete_basis_reversed(partial, 64),
           note  = "extend a half basis, reversed")

    # ── linear maps ─────────────────────────────────────────────────────────
    for n in (16, 32)
        benchmark!(reg; group = G, name = "is_invertible", n = n, cost = 1,
               setup = () -> random_invertible_linear_map(Xoshiro(11), Val(n)),
               call  = L -> is_invertible(L),
               note  = "full-rank test")
    end

    for n in (16, 32)
        benchmark!(reg; group = G, name = "compose_linear", n = n, cost = 1,
               setup = () -> (
                   random_invertible_linear_map(Xoshiro(11), Val(n)),
                   random_invertible_linear_map(Xoshiro(23), Val(n))),
               call  = p -> compose(p[1], p[2]),
               note  = "product of two linear maps")
    end

    # This case builds a new lookup table of 2^n words. It shows the cost of
    # the S-box side of the equivalence test.
    for n in (8, 12)
        benchmark!(reg; group = G, name = "compose_sbox_linear", n = n, cost = 1,
               setup = () -> (
                   random_permutation_sbox(Xoshiro(11), Val(n)),
                   random_invertible_linear_map(Xoshiro(23), Val(n))),
               call  = p -> compose(p[1], p[2]),
               note  = "S-box after a linear map")
    end

    # ── systems over F2 ─────────────────────────────────────────────────────
    #
    # `solve_f2` holds the augmented column at bit `nbits`, so the word must be
    # wider than the matrix. The setup makes `b` from a known solution, and the
    # system is therefore always consistent.
    for (n, T) in ((16, UInt32), (32, UInt64))
        msk = T((T(1) << n) - T(1))
        benchmark!(reg; group = G, name = "solve_f2", n = n, cost = 1,
               setup = () -> begin
                   A = rand(T, n) .& msk
                   x0 = rand(T) & msk
                   b = zero(T)
                   for i = 1:n
                       f2_dot(A[i], x0) == 1 && (b |= T(1) << (i - 1))
                   end
                   (A, b)
               end,
               call  = p -> solve_f2(p[1], p[2]; nbits = n),
               note  = "solve a consistent system")
    end

    # The matrix has n/2 rows and n columns, so the nullspace has about n/2
    # dimensions. A square random matrix gives an almost empty nullspace.
    for (n, T) in ((32, UInt32), (64, UInt64))
        benchmark!(reg; group = G, name = "kernel_f2", n = n, cost = 1,
               setup = () -> rand(T, n ÷ 2),
               call  = A -> kernel_f2(A; nbits = n),
               note  = "nullspace of a wide matrix")
    end

    # ── affine map factories ────────────────────────────────────────────────
    benchmark!(reg; group = G, name = "generating_affine_map", n = 32, cost = 1,
           setup = () -> linear_basis(rand(UInt32, 16); nbits = 32),
           call  = basis -> generating_affine_map(basis, 32),
           note  = "map from a partial basis")

    # This factory also inverts a map. The inverse needs 2N columns, so it runs
    # on the wide UInt128 path.
    benchmark!(reg; group = G, name = "affine_map_from_range_and_image", n = 32,
           cost = 1,
           setup = () -> (random_invertible_linear_map(Xoshiro(11),
                                                       Val(32)).cols,
                          random_invertible_linear_map(Xoshiro(23),
                                                       Val(32)).cols),
           call  = p -> affine_map_from_range_and_image(p[1], p[2], 32),
           note  = "map fixed by 32 images")

    # ── subspace enumeration ────────────────────────────────────────────────
    #
    # The set is an (n/2)-dimensional subspace of GF(2^n). The CCZ layer
    # applies this function to the Walsh-zeroes set. A subspace gives a dense
    # input, and the search can prune very little of it.
    for n in (8, 12, 16)
        benchmark!(reg; group = G, name = "extract_linear_subspaces", n = n,
               cost = 1,
               setup = () -> UInt32.(random_linear_subspace(Xoshiro(3), n,
                                                            n ÷ 2)),
               call  = z -> extract_linear_subspaces(z, 2; max_bits = n),
               note  = "2-dim subspaces in a span")
    end

    benchmark!(reg; group = G, name = "span_from_basis", n = 16, cost = 1,
           setup = () -> collect(UInt32,
                                 random_invertible_linear_map(Xoshiro(5),
                                                              Val(16)).cols),
           call  = basis -> span_from_basis(basis),
           note  = "expand a basis to its span")

    # ── subspaces inside a set ──────────────────────────────────────────────
    #
    # The set is an (n-4)-dimensional subspace. This is the worst case. Every
    # coset test succeeds, and the search keeps every candidate.
    for n in (10, 12)
        benchmark!(reg; group = G, name = "find_2d_subspaces", n = n, cost = 1,
               setup = () -> random_linear_subspace(Xoshiro(3), n, n - 4),
               call  = S -> find_2d_subspaces(S, n),
               note  = "2-dim subspaces in a set")
    end

    # The n = 12 case tests every one of the 10795 2-dim subspaces against 256
    # candidates. It needs about 0.5 s, so it belongs to level 2.
    for (n, cost) in ((10, 1), (12, 2))
        benchmark!(reg; group = G, name = "expand_subspaces", n = n, cost = cost,
               setup = () -> begin
                   S = random_linear_subspace(Xoshiro(3), n, n - 4)
                   (S, find_2d_subspaces(S, n))
               end,
               call  = p -> expand_subspaces(p[1], p[2], n),
               note  = "lift 2-dim spaces to 3-dim")
    end

    benchmark!(reg; group = G, name = "smallest_basis", n = 12, cost = 1,
           setup = () -> random_linear_subspace(Xoshiro(3), 12, 8),
           call  = S -> smallest_basis(S),
           note  = "basis of a 256-element space")

    # The signature repeats the expansion until no subspace remains. One call
    # needs about 0.026 s, and a garbage collection can extend a single call
    # to about 0.09 s. The same case at n = 12 needs about 45 s. That case is
    # a level 3 workload, and the suite leaves it out.
    benchmark!(reg; group = G, name = "subspace_count_signature", n = 10, cost = 1,
           setup = () -> random_linear_subspace(Xoshiro(3), 10, 6),
           call  = S -> subspace_count_signature(S, 10),
           note  = "subspace counts per dimension")

    return reg
end
