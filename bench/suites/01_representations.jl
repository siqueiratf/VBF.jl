# bench/suites/01_representations.jl — the representation layer and GF(2^n).
#
# CONTRACT (every suite file in this directory follows it):
#   * The file defines exactly one function, `register!(reg)`.
#   * The function calls `bench!` once per case and measures nothing itself.
#   * `setup` is a zero-argument function that returns the payload. The harness
#     does not time it. Put every allocation that the case does not measure here.
#   * `call` takes that payload and does the work that the case measures.
#   * `cost` is 1 (under about 0.1 s), 2 (under about 5 s) or 3 (minutes).
#   * `note` is one short phrase for the reader of the thesis table.

function register!(reg)
    G = "representations"

    # ── SBox construction and inversion ─────────────────────────────────────
    for n in (8, 10, 12)
        bench!(reg; group = G, name = "sbox_construct", n = n, cost = 1,
               setup = () -> collect(UInt32, 0:(1 << n - 1)),
               call  = lut -> SBox(lut),
               note  = "wrap a lookup table")
    end

    for n in (8, 10, 12)
        bench!(reg; group = G, name = "is_permutation", n = n, cost = 1,
               setup = () -> random_permutation_sbox(Xoshiro(11), Val(n)),
               call  = F -> is_permutation(F),
               note  = "test the bijection")
    end

    for n in (8, 10, 12)
        bench!(reg; group = G, name = "compositional_inverse", n = n, cost = 1,
               setup = () -> random_permutation_sbox(Xoshiro(11), Val(n)),
               call  = F -> compositional_inverse(F),
               note  = "invert a permutation")
    end

    # ── algebraic normal form ───────────────────────────────────────────────
    for n in (8, 10, 12)
        bench!(reg; group = G, name = "anf", n = n, cost = 1,
               setup = () -> random_function_sbox(Xoshiro(11), Val(n)),
               call  = F -> anf(F),
               note  = "Mobius transform")
    end

    for n in (10, 12, 14)
        bench!(reg; group = G, name = "mobius", n = n, cost = 1,
               setup = () -> rand(UInt16, 1 << n),
               call  = v -> mobius(v),
               note  = "Mobius transform of a raw vector")
    end

    # ── finite field arithmetic ─────────────────────────────────────────────
    for n in (8, 12, 16)
        bench!(reg; group = G, name = "gf_mul_sweep", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n),
                              [rand(0:(1 << n - 1)) for _ in 1:4096]),
               call  = p -> begin
                   n, m, xs = p
                   acc = 0
                   for x in xs
                       acc ⊻= gf_mul(x, 0b1011, n; modulus = m)
                   end
                   acc
               end,
               note  = "4096 products")
    end

    for n in (8, 12, 16)
        bench!(reg; group = G, name = "gf_inv_sweep", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n),
                              [rand(1:(1 << n - 1)) for _ in 1:1024]),
               call  = p -> begin
                   n, m, xs = p
                   acc = 0
                   for x in xs
                       acc ⊻= gf_inv(x, n; modulus = m)
                   end
                   acc
               end,
               note  = "1024 inverses")
    end

    for n in (8, 10, 12)
        bench!(reg; group = G, name = "gf_monomial_lut", n = n, cost = 1,
               setup = () -> (n, primitive_polynomial(n)),
               call  = p -> gf_monomial_lut(p[1], 3; modulus = p[2]),
               note  = "build the table of x^3")
    end

    # ── univariate form ─────────────────────────────────────────────────────
    for n in (8, 10)
        bench!(reg; group = G, name = "polynomial_to_lut", n = n, cost = 1,
               setup = () -> ("x^1 + x^3 + x^5", n, primitive_polynomial(n)),
               call  = p -> polynomial_to_lut(p[1], p[2], p[3]),
               note  = "evaluate x + x^3 + x^5")
    end

    return reg
end
