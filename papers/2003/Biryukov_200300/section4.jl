# Implements Section 4 — Extensions.
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 4.1 — Self-Equivalent S-Boxes (and 5.1 Rijndael, eqs. 10/11)
#          4.2 — Equivalence of Non-invertible S-Boxes (DES S4, eq. 9)
#          4.3 — Almost Affine Equivalent S-Boxes (not run; reason recorded)
#
# Pseudocode:
#   Section 4.1 / 5.1 — Rijndael's 2040 self-equivalences, CONSTRUCTIVELY:
#     1. Recover A, the Rijndael affine map, from the catalog S-box via
#        A(y) = S(y^{-1}) (0^{-1} := 0); check A is F2-affine.
#     2. Build [a] (multiplication by a in GF(2^8), modulus 0x11B) and Q (the
#        squaring matrix) as F2 linear maps.
#     3. For i in 0..7 and a in GF(2^8)\{0} form the paper's eqs (10)/(11)
#          A1(x) = [a].Q^i.x            A2(x) = A(Q^{-i}.[a].A^{-1}(x))
#        and check A2(S(A1(x))) == S(x) on all 256 inputs.
#     4. Check the 8 x 255 = 2040 pairs are pairwise distinct => s >= 2040.
#     5. (full_search=true) self_affine_equivalences(S) == 2040 pins the upper
#        bound exhaustively.
#   Section 4.2 — the single DES self-equivalence:
#     6. B^{-1}.S4(A.x + a) + b == S4(x) with A = I, B the bit permutation
#        [4,3,2,1], a = 101111_2, b = 0110_2; checked on all 64 inputs.
#     7. Search all (bit permutation B, a, b) triples with A = I: the paper's
#        triple is the only non-trivial one.
#     8. Evaluate eq. (9) at DES's (n, m) = (6, 4).
# VBF API used: SBox, F2LinearMap, F2AffineMap, compose, inv, gf_mul, gf_pow,
#               gf_inv_zero_safe, self_affine_equivalences, load_literature_sbox

include(joinpath(@__DIR__, "helpers.jl"))

const RIJNDAEL_EXPECTED_SELF_EQUIV = 2040

# Rijndael's field polynomial x^8+x^4+x^3+x+1.  Not primitive_polynomial(8):
# the paper's [a] and Q matrices only reproduce the AES S-box under 0x11B.
const RIJNDAEL_MODULUS = 0x11B

# ----------------------------------------------------------------------------
# Section 5.1 — the algebraic structure behind Rijndael's 2040 self-equivalences.
# ----------------------------------------------------------------------------

# [a]: the 8x8-bit matrix of multiplication by a in GF(2^8).
gf_mult_matrix(a::Integer) = F2LinearMap{8,UInt8}(
    UInt8[gf_mul(a, 1 << j, 8; modulus = RIJNDAEL_MODULUS) for j = 0:7],
)

# Q: the 8x8-bit matrix of squaring in GF(2^8) (F2-linear, footnote 3).
squaring_matrix() = F2LinearMap{8,UInt8}(
    UInt8[gf_pow(1 << j, 2, 8; modulus = RIJNDAEL_MODULUS) for j = 0:7],
)

# Q^i for i >= 0, with Q^8 = I so Q^{-i} == Q^{8-i}.
function squaring_power(i::Integer)
    Q = squaring_matrix()
    L = identity_linear_map(8, UInt8)
    for _ = 1:mod(i, 8)
        L = compose(Q, L)
    end
    L
end

"""
    rijndael_affine_map(S) -> F2AffineMap{8,UInt8}

The fixed affine map `A` of `S(x) = A(x^{-1})`, recovered from the S-box itself:
`A(y) = S(y^{-1})` with the cryptographic convention `0^{-1} = 0`.
"""
function rijndael_affine_map(S::SBox{8,UInt8})
    inv0(y) = gf_inv_zero_safe(y, 8; modulus = RIJNDAEL_MODULUS)
    c = UInt8(S.lut[inv0(0)+1])
    cols = UInt8[UInt8(S.lut[inv0(1 << j)+1]) ⊻ c for j = 0:7]
    F2AffineMap{8,UInt8}(F2LinearMap{8,UInt8}(cols), c)
end

# A is affine iff S(y^{-1}) agrees with it everywhere.
function is_rijndael_affine_decomposition(S::SBox{8,UInt8}, A::F2AffineMap{8,UInt8})
    all(A(gf_inv_zero_safe(y, 8; modulus = RIJNDAEL_MODULUS)) == S.lut[y+1] for y = 0:255)
end

"""
    rijndael_self_equivalences(S) -> Vector{@NamedTuple{A1, A2}}

The 8 x 255 pairs of eqs. (10)/(11):

    A1(x) = [a] . Q^i . x           A2(x) = A( Q^{-i} . [a] . A^{-1}(x) )

for `0 <= i < 8` and `a` in `GF(2^8)\\{0}`, each satisfying `A2 . S . A1 = S`.

Note the paper's `(A1, A2)` are ordered input-first/output-last; VBF's
[`self_affine_equivalences`](@ref) names the same pair the other way round
(`F = A1 . F . A2`). Only the count is compared across the two conventions.
"""
function rijndael_self_equivalences(S::SBox{8,UInt8})
    A = rijndael_affine_map(S)
    Ainv = inv(A)
    out = NamedTuple{(:A1, :A2),Tuple{F2AffineMap{8,UInt8},F2AffineMap{8,UInt8}}}[]
    for i = 0:7
        Qi = squaring_power(i)
        Qmi = squaring_power(-i)
        for a = 1:255
            ma = gf_mult_matrix(a)
            A1 = F2AffineMap{8,UInt8}(compose(ma, Qi), UInt8(0))
            mid = F2AffineMap{8,UInt8}(compose(Qmi, ma), UInt8(0))
            A2 = compose(A, compose(mid, Ainv))
            push!(out, (A1 = A1, A2 = A2))
        end
    end
    out
end

# A2 . S . A1 == S on every input.
function is_self_equivalence(
    S::SBox{8,UInt8},
    A1::F2AffineMap{8,UInt8},
    A2::F2AffineMap{8,UInt8},
)
    all(A2(S.lut[A1(UInt8(x))+1]) == S.lut[x+1] for x = 0:255)
end

_affine_key(A::F2AffineMap{8,UInt8}) = (copy(A.linear.cols), A.constant)

# ----------------------------------------------------------------------------
# Section 4.2 — the one self-equivalence among the 6x4-bit DES S-boxes.
# ----------------------------------------------------------------------------

const DES_S4_INPUT_CONST = 0b101111   # a
const DES_S4_OUTPUT_CONST = 0b0110    # b
const DES_S4_BIT_PERM = [4, 3, 2, 1]  # B, as printed in the paper

# Apply the output bit permutation p (1-based positions, paper order [4,3,2,1])
# to a 4-bit value: bit j of y moves to position p[j+1]-1.
function apply_bit_perm(p::Vector{Int}, y::Integer)
    out = 0
    for j = 0:3
        ((Int(y) >> j) & 1) == 1 && (out |= 1 << (p[j+1] - 1))
    end
    out
end

"""
    des_s4_relation_holds(lut, p, a, b) -> Bool

Does `B^{-1}(S4(x + a)) + b == S4(x)` hold on all 64 inputs, with `A = I` and
`B` the output bit permutation `p`? `[4,3,2,1]` is the bit reversal, which is
its own inverse, so `B^{-1}` and `B` coincide for the paper's `p`.
"""
function des_s4_relation_holds(lut::Vector{Int}, p::Vector{Int}, a::Integer, b::Integer)
    all(apply_bit_perm(p, lut[(x⊻Int(a))+1]) ⊻ Int(b) == lut[x+1] for x = 0:63)
end

# All 4! output bit permutations, generated without an extra dependency.
function _bit_perms()
    perms = Vector{Int}[]
    for a = 1:4, b = 1:4, c = 1:4, d = 1:4
        p = [a, b, c, d]
        length(unique(p)) == 4 && push!(perms, p)
    end
    perms
end

"""
    des_s4_bitperm_self_equivalences(lut) -> Vector{Tuple{Vector{Int},Int,Int}}

Every `(B, a, b)` with `A = I` and `B` a bit permutation satisfying the paper's
relation. Exhaustive over `4! * 64 * 16 = 24576` candidates.
"""
function des_s4_bitperm_self_equivalences(lut::Vector{Int})
    out = Tuple{Vector{Int},Int,Int}[]
    for p in _bit_perms(), a = 0:63, b = 0:15
        des_s4_relation_holds(lut, p, a, b) && push!(out, (p, a, b))
    end
    out
end

# Eq. (9): n^3 . 2^n . (2^{n-m}!)^{n / 2^{n-m}}.
function eq9_complexity(n::Int, m::Int)
    d = n - m
    BigInt(n)^3 * BigInt(2)^n * BigInt(round(factorial(big(2)^d)^(n / 2^d)))
end

# ----------------------------------------------------------------------------
# Report.
# ----------------------------------------------------------------------------

function section4_report(io::IO = stdout; full_search::Bool = false)
    all_ok = true

    # --- Section 4.1 / 5.1: Rijndael ----------------------------------------
    print_section(io, "Section 4.1 / 5.1 — Rijndael self-equivalences (eqs. 10/11)")
    print_kv(
        io,
        "paper claim",
        "Rijndael S-box has $RIJNDAEL_EXPECTED_SELF_EQUIV = 8 x 255 affine self-equivalences",
    )

    S = load_aes_sbox()
    A = rijndael_affine_map(S)
    ok_decomp = is_rijndael_affine_decomposition(S, A)
    print_check(io, "S(x) = A(x^{-1}) with A affine over GF(2)^8 (modulus 0x11B)", ok_decomp)
    all_ok &= ok_decomp

    pairs = rijndael_self_equivalences(S)
    ok_count = length(pairs) == RIJNDAEL_EXPECTED_SELF_EQUIV
    print_check(
        io,
        "eqs. (10)/(11) enumerate 8 x 255 = $(length(pairs)) pairs",
        ok_count,
    )
    ok_valid = all(is_self_equivalence(S, p.A1, p.A2) for p in pairs)
    print_check(io, "every pair satisfies A2 ∘ S ∘ A1 = S on all 256 inputs", ok_valid)
    ndistinct = length(Set((_affine_key(p.A1), _affine_key(p.A2)) for p in pairs))
    ok_distinct = ndistinct == RIJNDAEL_EXPECTED_SELF_EQUIV
    print_check(io, "the pairs are pairwise distinct ($ndistinct distinct)", ok_distinct)
    all_ok &= ok_count && ok_valid && ok_distinct
    print_kv(io, "bound", "constructive ⇒ s ≥ $RIJNDAEL_EXPECTED_SELF_EQUIV (no search needed)")

    # Table 4 lists S and S^{-1} as members of one class.  Explicit witness:
    # S^{-1} = inv ∘ A^{-1}, so A ∘ S^{-1} ∘ A = A ∘ inv = S.
    Sinv = compositional_inverse(S)
    ok_inv_class = all(A(Sinv.lut[A(UInt8(x))+1]) == S.lut[x+1] for x = 0:255)
    print_check(io, "Table 4 members {S, S^{-1}}: A ∘ S^{-1} ∘ A = S", ok_inv_class)
    all_ok &= ok_inv_class

    if full_search
        t0 = time()
        equivs = self_affine_equivalences(S)
        elapsed = time() - t0
        count = length(equivs)
        ok_exhaustive = count == RIJNDAEL_EXPECTED_SELF_EQUIV
        print_check(
            io,
            "self_affine_equivalences(AES) == $RIJNDAEL_EXPECTED_SELF_EQUIV (got $count)",
            ok_exhaustive,
        )
        print_kv(io, "elapsed", "$(round(elapsed; digits=1))s")
        print_kv(io, "completeness", "exhaustive (2^16 LE searches over GF(2^8) x GF(2^8))")
        all_ok &= ok_exhaustive
    else
        print_kv(
            io,
            "upper bound",
            "[SKIP] exhaustive s (2^16 LE searches, tens of minutes); " *
            "run full_search=true or the 'rijndael_2040' target",
        )
        print_kv(io, "completeness", "lower bound exact (2040/2040 pairs evaluated)")
    end

    # --- Section 4.2: non-invertible S-boxes, DES S4 -------------------------
    print_section(io, "Section 4.2 — Equivalence of non-invertible S-boxes (DES S4)")
    lut = des_s4_lut()
    ok_s4 = des_s4_relation_holds(
        lut,
        DES_S4_BIT_PERM,
        DES_S4_INPUT_CONST,
        DES_S4_OUTPUT_CONST,
    )
    print_check(
        io,
        "B^{-1}·S4(x ⊕ $(string(DES_S4_INPUT_CONST; base=2, pad=6))₂) ⊕ " *
        "$(string(DES_S4_OUTPUT_CONST; base=2, pad=4))₂ = S4(x), A = I, B = [4,3,2,1]",
        ok_s4,
    )
    all_ok &= ok_s4

    found = des_s4_bitperm_self_equivalences(lut)
    nontrivial = filter(t -> !(t[1] == [1, 2, 3, 4] && t[2] == 0 && t[3] == 0), found)
    ok_unique =
        length(found) == 2 &&
        length(nontrivial) == 1 &&
        nontrivial[1] == (DES_S4_BIT_PERM, DES_S4_INPUT_CONST, DES_S4_OUTPUT_CONST)
    print_check(
        io,
        "it is the only non-trivial (B, a, b) with A = I (4!·64·16 = 24576 searched)",
        ok_unique,
    )
    all_ok &= ok_unique
    print_kv(
        io,
        "eq. (9) at DES (n,m)=(6,4)",
        "n³·2ⁿ·(2^{n-m}!)^{n/2^{n-m}} ≈ 2^$(round(Float64(log2(eq9_complexity(6, 4))); digits=1))",
    )
    print_kv(
        io,
        "not run",
        "\"no equivalences between any pair of the eight 6x4-bit DES S-boxes\": " *
        "needs the n→m (m<n) AE extension of Sect. 4.2; VBF's equivalence API is " *
        "n→n bijective only (28 unordered pairs unevaluated)",
    )

    # --- Section 4.3: almost affine equivalence ------------------------------
    print_section(io, "Section 4.3 — Almost affine equivalent S-boxes")
    print_kv(
        io,
        "not run",
        "needs an inconsistency-tolerant LE variant (accept up to a fraction f of " *
        "mismatches, randomise the guess order, ~(1-f)^{-const·n} restarts); " *
        "no such entry point in VBF core, and the paper states no reproducible " *
        "numeric result beyond the worked estimate below (0 pairs evaluated)",
    )
    print_kv(
        io,
        "paper's worked estimate",
        "n=8, f=0.20 ⇒ about 10 iterations of the basic algorithm",
    )

    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    full = lowercase(get(ENV, "FULL_SEARCH", "false")) == "true"
    ok = section4_report(; full_search = full)
    exit(ok ? 0 : 1)
end
