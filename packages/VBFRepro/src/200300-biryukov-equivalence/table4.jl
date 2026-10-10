# Implements Appendix B.2 — Table 4 (Rijndael, Camellia, Misty, Kasumi).
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: Appendix B.2 (Table 4); the reason is stated in Sect. 5.1 and
#          repeated for Misty: "both are designed to be affine equivalent with a
#          power function over GF(2^7) and GF(2^9) respectively".
#
# Pseudocode:
#   Every Table 4 entry is s = n * (2^n - 1) for an S-box affine equivalent to a
#   power permutation over GF(2^n).  s is an affine-equivalence invariant, so it
#   can be read off the power permutation itself:
#     1. For F(x) = x^d over GF(2^n) with gcd(d, 2^n-1) = 1, and for every
#        0 <= i < n and a in GF(2^n)\{0}, set
#            A1(x) = a * x^(2^i)          A2(y) = (a^{-d} * y)^(2^{-i})
#        Then A2(F(A1(x))) = (a^{-d} * a^d * x^(d*2^i))^(2^{-i}) = x^d = F(x).
#     2. Check that pointwise on all 2^n inputs, and that the n*(2^n-1) pairs
#        are pairwise distinct  =>  s >= n*(2^n - 1).
#     3. n = 8 gives 8*255 = 2040 (Rijndael/Camellia, the inverse map d = 254),
#        n = 7 gives 7*127 = 889 (Misty S7), n = 9 gives 9*511 = 4599 (Misty S9).
#     4. (full_search=true) the exhaustive s for the GF(2^7) power map pins 889
#        from above.
# VBF API used: SBox, F2LinearMap, gf_mul, gf_pow, gf_inv, gf_monomial_lut,
#               primitive_polynomial, is_permutation, self_affine_equivalences

include(joinpath(@__DIR__, "helpers.jl"))

# Table 4, verbatim: (cipher, members, n, s, exponent d of the power permutation
# the S-box is affine equivalent to).
const TABLE4 = [
    ("Rijndael/Camellia", "S, S^{-1}", 8, 2040, 254),
    ("Misty/Kasumi", "S7", 7, 889, 81),
    ("Misty/Kasumi", "S9", 9, 4599, 5),
]

"""
    power_permutation(n, d) -> SBox{n}

`x ↦ xᵈ` over `GF(2ⁿ)` under the canonical primitive modulus. Throws unless the
map is a permutation.
"""
function power_permutation(n::Int, d::Int)
    S = SBox{n}(gf_monomial_lut(n, d; modulus = primitive_polynomial(n)))
    is_permutation(S) ||
        throw(ArgumentError("power_permutation: x^$d is not a permutation of GF(2^$n)"))
    S
end

"""
    power_map_self_equivalences(n, d) -> Vector{@NamedTuple{A1, A2}}

The `n · (2ⁿ − 1)` linear self-equivalences of `x ↦ xᵈ` over `GF(2ⁿ)`:

    A1(x) = a · x^(2ⁱ)          A2(y) = (a^{−d} · y)^(2^{−i})

for `0 ≤ i < n` and `a ∈ GF(2ⁿ)\\{0}`. Both are `F₂`-linear because `x ↦ x^(2ⁱ)`
(Frobenius) and `x ↦ a·x` are. Ordered input-first/output-last, as the paper
writes `A2 ∘ S ∘ A1 = S`.
"""
function power_map_self_equivalences(n::Int, d::Int)
    modulus = primitive_polynomial(n)
    T = typeof(SBox{n}(zeros(Int, 1 << n)).lut[1])
    out = NamedTuple{(:A1, :A2),Tuple{F2LinearMap{n,T},F2LinearMap{n,T}}}[]
    for i = 0:(n-1)
        fwd = 1 << i                 # x ↦ x^(2^i)
        bwd = 1 << mod(-i, n)        # its inverse, since x^(2^n) = x
        for a = 1:((1<<n)-1)
            ainv_d = gf_inv(gf_pow(a, d, n; modulus = modulus), n; modulus = modulus)
            A1 = F2LinearMap{n,T}(
                T[gf_mul(a, gf_pow(1 << j, fwd, n; modulus = modulus), n; modulus = modulus)
                  for j = 0:(n-1)],
            )
            A2 = F2LinearMap{n,T}(
                T[gf_pow(gf_mul(ainv_d, 1 << j, n; modulus = modulus), bwd, n;
                         modulus = modulus) for j = 0:(n-1)],
            )
            push!(out, (A1 = A1, A2 = A2))
        end
    end
    out
end

# A2 ∘ F ∘ A1 == F on every input.
function is_power_self_equivalence(F::SBox, A1, A2)
    all(A2(F.lut[A1(x)+1]) == F.lut[x+1] for x = 0:((1<<inputbits(F))-1))
end

function table4_report(io::IO = stdout; full_search::Bool = false)
    print_section(io, "Appendix B.2 — Table 4 (Rijndael, Camellia, Misty, Kasumi)")
    print_kv(
        io,
        "reason (Sects. 5.1, B.2)",
        "each S-box is affine equivalent to a power permutation over GF(2ⁿ), " *
        "whose self-equivalence group contains n·(2ⁿ−1) elements; s is an " *
        "affine invariant, so it can be read off the power map",
    )

    all_ok = true
    for (cipher, members, n, s_paper, d) in TABLE4
        F = power_permutation(n, d)
        pairs = power_map_self_equivalences(n, d)
        ok_count = length(pairs) == s_paper
        ok_valid = all(is_power_self_equivalence(F, p.A1, p.A2) for p in pairs)
        ndistinct = length(Set((copy(p.A1.cols), copy(p.A2.cols)) for p in pairs))
        ok_distinct = ndistinct == s_paper
        ok = ok_count && ok_valid && ok_distinct
        print_check(
            io,
            "$cipher {$members}: s ≥ $(length(pairs)) = $n × $((1 << n) - 1) " *
            "(paper $s_paper), all valid and distinct",
            ok,
        )
        all_ok &= ok
    end

    print_kv(
        io,
        "Rijndael row",
        "the same 2040 is derived from the S-box itself in section4.jl via the " *
        "paper's eqs. (10)/(11); the class membership {S, S^{-1}} is checked there",
    )
    print_kv(
        io,
        "Camellia",
        "recorded, not evaluated: its S-box is an affine image of x^{-1} over " *
        "GF(2^8) and so shares Rijndael's s, but the table is not in " *
        "VBFCatalog (0 of 256 entries loaded)",
    )
    print_kv(
        io,
        "Misty S7/S9",
        "recorded, not evaluated: the S7/S9 tables are not in VBFCatalog, so " *
        "what is checked is the paper's stated reason instantiated on the power " *
        "permutations x^81 over GF(2^7) and x^5 over GF(2^9); the count " *
        "n·(2ⁿ−1) is the same for every power permutation",
    )

    if full_search
        n, d, s_paper = 7, 81, 889
        F = power_permutation(n, d)
        t0 = time()
        count = length(self_affine_equivalences(F))
        elapsed = time() - t0
        ok = count == s_paper
        print_check(io, "exhaustive s(x^$d over GF(2^$n)) == $s_paper (got $count)", ok)
        print_kv(io, "elapsed", "$(round(elapsed; digits=1))s")
        all_ok &= ok
    else
        print_kv(
            io,
            "upper bound",
            "[SKIP] exhaustive s for GF(2^7) (2^14 LE searches, ~370s); " *
            "run full_search=true or the 'misty_889' target",
        )
    end
    print_kv(
        io,
        "not run",
        "exhaustive s over GF(2^9): 2^18 LE searches on 9-bit permutations, " *
        "roughly 2^4 times the GF(2^7) run (0 of 262144 shifts evaluated)",
    )
    print_kv(io, "completeness", "lower bounds exact (2040 + 889 + 4599 pairs evaluated)")

    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    full = lowercase(get(ENV, "FULL_SEARCH", "false")) == "true"
    ok = table4_report(; full_search = full)
    exit(ok ? 0 : 1)
end
