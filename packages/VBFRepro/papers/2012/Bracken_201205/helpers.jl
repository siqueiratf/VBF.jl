# Implements paper-local helpers for the Bracken–Tan–Tan (2012) reproduction.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: General — field utilities, binomial builder, streaming spectra
#
# Pseudocode:
#   1. n = 3k, α = 2 (primitive element of GF(2^n))
#   2. 2^{-k} ≡ 2^{2k} (mod 2^n−1) since n = 3k
#   3. F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}}
#   4. t = gcd(3k, s); F is diff-2^t-uniform, and a permutation iff k/t is odd
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, inputbits,
#               walsh_hadamard!, lat, differential_spectrum, sorted_pairs,
#               gauss_jordan!
#
# TIMINGS.  Every runtime quoted in this folder was measured with `@elapsed` on
# THIS machine (AMD Ryzen 5 5600G, 12 threads, Julia 1.12.6, single-threaded);
# see `packages/VBF/perf/historical/calibration.toml` for the machine profile.  Figures taken from the
# paper or from another machine are labelled as such at the point of use.

using VBF
using Random

# Report banner uses core `print_banner` (VBF, exported); see report.jl.

# ---------------------------------------------------------------------------
# Field constants
# ---------------------------------------------------------------------------

"""
    PAPER_PRIMITIVE_POLYNOMIALS :: Dict{Int, Int}

Moduli used by this folder.  Core `PRIMITIVE_POLYNOMIALS` stops at `n = 16`, but
Theorem 1.1's smallest genuine (non-degenerate) instance lives at `n = 30`, so
one extra entry is carried here:

    n = 30 → x³⁰ + x⁶ + x⁴ + x + 1 = 1073741907

`α = 2` is primitive under it: `2³⁰ − 1 = 3²·7·11·31·151·331` and `2^{(2³⁰−1)/p}
≠ 1` for every prime `p` of that factorisation — asserted at construction time by
[`alpha_is_primitive`](@ref), not assumed.

TODO(promote-to-core): a `PRIMITIVE_POLYNOMIALS` entry for `n = 30` is generic;
kept local because core is frozen for this reproduction.
"""
const PAPER_PRIMITIVE_POLYNOMIALS = Dict{Int,Int}(30 => 1073741907)

"""
    paper_modulus(n) -> Int

Canonical modulus for `GF(2ⁿ)` in this folder: core `primitive_polynomial(n)`
for `n ≤ 16`, and [`PAPER_PRIMITIVE_POLYNOMIALS`](@ref) beyond it.
"""
paper_modulus(n::Integer) =
    haskey(PAPER_PRIMITIVE_POLYNOMIALS, Int(n)) ?
    PAPER_PRIMITIVE_POLYNOMIALS[Int(n)] : primitive_polynomial(Int(n))

# Prime factors of m by trial division (m < 2^31 here, so this is instant).
function _prime_factors(m::Int)
    fs = Int[]
    d = 2
    while d * d ≤ m
        if m % d == 0
            push!(fs, d)
            while m % d == 0
                m ÷= d
            end
        end
        d += 1
    end
    m > 1 && push!(fs, m)
    fs
end

"""
    alpha_is_primitive(n; modulus = paper_modulus(n)) -> Bool

Whether `α = 2` generates `GF(2ⁿ)*`, i.e. has multiplicative order `2ⁿ − 1`.
Theorem 1.1/1.2 *require* `α` primitive; this reproduction asserts it instead of
assuming it (BTT-11).  Verified here: the order of `2` is `7, 63, 4095, 32767`
for `n = 3, 6, 12, 15` under core `PRIMITIVE_POLYNOMIALS`, and `2³⁰ − 1` for
`n = 30` under [`PAPER_PRIMITIVE_POLYNOMIALS`](@ref).

TODO(promote-to-core): a generic `is_primitive_element` belongs in
`packages/VBF/src/representations/finite_field.jl`; kept local for now.
"""
function alpha_is_primitive(n::Integer; modulus::Integer = paper_modulus(n))
    nn = Int(n)
    m = Int(modulus)
    N = (1 << nn) - 1
    gf_pow(2, N, nn; modulus = m) == 1 || return false
    all(p -> gf_pow(2, N ÷ p, nn; modulus = m) != 1, _prime_factors(N))
end

# ---------------------------------------------------------------------------
# The family F of Theorem 1.2
# ---------------------------------------------------------------------------

"""
    BrackenBinomial

Closed form of the Bracken–Tan–Tan binomial over `GF(2^{3k})`, evaluable one
point at a time so that `n = 30` never needs a `2³⁰`-entry LUT:

    F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}},   α = 2 primitive.

Fields: `k, s, n = 3k, t = gcd(3k,s), modulus`, the two exponents `e1, e2` and
the two coefficients `c1 = α`, `c2 = α^{2^k}`.  Call it like a function:
`F(x)`.
"""
struct BrackenBinomial
    k::Int
    s::Int
    n::Int
    t::Int
    modulus::Int
    e1::Int
    e2::Int
    c1::Int
    c2::Int
end

function (F::BrackenBinomial)(x::Integer)
    n, m = F.n, F.modulus
    gf_mul(F.c1, gf_pow(Int(x), F.e1, n; modulus = m), n; modulus = m) ⊻
    gf_mul(F.c2, gf_pow(Int(x), F.e2, n; modulus = m), n; modulus = m)
end

"""
    is_degenerate(F::BrackenBinomial) -> Bool

Whether the two exponents coincide modulo `2ⁿ − 1`, i.e. whether `F` collapses
to a monomial `(α + α^{2^k})·x^{e}`.  This happens exactly when
`s ≡ 2k (mod 3k)`; the paper never states the caveat (Paper Issue 2).
"""
function is_degenerate(F::BrackenBinomial)
    N = (1 << F.n) - 1
    mod(F.e1, N) == mod(F.e2, N)
end

"""
    bracken_binomial(k, s; modulus, allow_nonpermutation = true) -> BrackenBinomial

Build `F` of Theorem 1.2 over `GF(2^{3k})` and **check its hypotheses** (BTT-6),
mirroring what core `bcp_apn` does for the APN sibling family:

* `k ≥ 1`, `s ≥ 1`;
* `3 ∤ k`                        (Theorem 1.2 / Lemma 2.1);
* `3 ∣ (k + s)`                  (Theorem 1.2 / Lemma 2.1);
* `t = gcd(3k, s)` divides `k`   (implied by the two above, checked anyway);
* `k/t` odd                      — only when `allow_nonpermutation = false`.
* `α = 2` primitive in `GF(2^{3k})`.

`allow_nonpermutation` defaults to `true` because Lemma 2.1's `k/t` even branch
(where `F` is provably *not* a permutation) is deliberately exercised by
`section2.jl`; pass `false` to demand the full Theorem 1.2 hypothesis set.

Throws `ArgumentError` on any violation, so e.g. `bracken_binomial(3, 3)`
(`3 ∣ k`) no longer returns a LUT silently.
"""
function bracken_binomial(
    k::Integer,
    s::Integer;
    modulus::Integer = paper_modulus(3 * Int(k)),
    allow_nonpermutation::Bool = true,
)
    kk, ss = Int(k), Int(s)
    kk ≥ 1 || throw(ArgumentError("bracken_binomial: need k ≥ 1, got k=$kk"))
    ss ≥ 1 || throw(ArgumentError("bracken_binomial: need s ≥ 1, got s=$ss"))
    n = 3 * kk
    mod(kk, 3) == 0 &&
        throw(ArgumentError("bracken_binomial: need 3 ∤ k, got k=$kk"))
    mod(kk + ss, 3) == 0 || throw(
        ArgumentError(
            "bracken_binomial: need 3 ∣ (k+s), got k=$kk, s=$ss (k+s=$(kk+ss))",
        ),
    )
    t = gcd(n, ss)
    mod(kk, t) == 0 || throw(
        ArgumentError(
            "bracken_binomial: need t = gcd(3k,s) to divide k, got t=$t, k=$kk",
        ),
    )
    if !allow_nonpermutation && iseven(kk ÷ t)
        throw(
            ArgumentError(
                "bracken_binomial: k/t = $(kk ÷ t) is even, so Lemma 2.1 makes F a " *
                "non-permutation; pass allow_nonpermutation=true to build it anyway",
            ),
        )
    end
    m = Int(modulus)
    alpha_is_primitive(n; modulus = m) || throw(
        ArgumentError(
            "bracken_binomial: α = 2 is not primitive in GF(2^$n) under modulus $m; " *
            "Theorem 1.2 requires a primitive α",
        ),
    )
    e1 = (1 << ss) + 1                     # 2^s + 1
    e2 = (1 << (2kk)) + (1 << (kk + ss))   # 2^{2k}+2^{k+s} (= 2^{-k}+2^{k+s} mod 2^n−1)
    BrackenBinomial(kk, ss, n, t, m, e1, e2, 2, gf_pow(2, 1 << kk, n; modulus = m))
end

"""
    bracken_binomial_lut(k, s; modulus, allow_nonpermutation) -> Vector{Int}

LUT for the Bracken–Tan–Tan binomial family over GF(2^{3k}):

    F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}}

where α = 2 (primitive element) and 2^{-k} ≡ 2^{2k} (mod 2^{3k}−1) since n = 3k.

Conditions (Theorem 1.2): `3 ∤ k`, `t = gcd(3k, s)`, `t ∣ k`, `k/t` odd,
`3 ∣ k+s`, `α` primitive.  All of them are enforced by
[`bracken_binomial`](@ref); `k/t` odd only when `allow_nonpermutation = false`.
When `k/t` is odd, F is a differentially 2^t uniform permutation; when `k/t` is
even, F is not a permutation (Lemma 2.1 converse).

Degenerate case: when `s ≡ 2k (mod 3k)`, both exponents reduce to `2^{2k}+1` and
F collapses to a monomial.  The smallest non-degenerate **permutation** instance
is `k=5, n=15, s=1 (t=1)`, which is the APN (`t=1`) member; the smallest
non-degenerate instance of any kind is `k=2, n=6, s=1 (t=1, e₁=3, e₂=24)`, which
sits in Lemma 2.1's `k/t` even (non-permutation) branch (BTT-7).  The smallest
non-degenerate instance of the paper's own `t = 2` headline is `k=10, n=30, s=2`
— see `theorem1_1.jl`.
"""
function bracken_binomial_lut(
    k::Integer,
    s::Integer;
    modulus::Integer = paper_modulus(3 * Int(k)),
    allow_nonpermutation::Bool = true,
)::Vector{Int}
    F = bracken_binomial(k, s; modulus = modulus, allow_nonpermutation = allow_nonpermutation)
    [F(x) for x = 0:((1 << F.n) - 1)]
end

"""
    bracken_binomial_sbox(k, s; modulus, allow_nonpermutation) -> SBox
"""
function bracken_binomial_sbox(
    k::Integer,
    s::Integer;
    modulus::Integer = paper_modulus(3 * Int(k)),
    allow_nonpermutation::Bool = true,
)
    SBox(
        bracken_binomial_lut(
            k,
            s;
            modulus = modulus,
            allow_nonpermutation = allow_nonpermutation,
        ),
    )
end

# ---------------------------------------------------------------------------
# Streaming spectra (value sets, not histograms)
# ---------------------------------------------------------------------------

"""
    differential_value_set(F::SBox; streaming = inputbits(F) ≥ 13) -> Vector{Int}

Sorted set of *distinct* DDT entries outside row `a = 0` — the object Theorem 1.2
names when it says "the differential spectrum of F is `{0, 2^t}`" (BTT-2).

`streaming = false` delegates to core `differential_spectrum` and keeps only the
support.  `streaming = true` runs the same one-input-difference-at-a-time scan
but collects distinct values in a tiny `Vector{Int}` instead of a `Dict`:
measured here at n=15, core `differential_spectrum` takes **10.6 s** (2³⁰ `Dict`
updates dominate) against **1.7 s** for the streaming form, with core
`differential_uniformity` — which discards the value set — at **1.0 s**.

TODO(promote-to-core): a `Dict`-free spectrum-support variant of
`differential_spectrum` is generic; kept local because core is frozen here.
"""
function differential_value_set(F::SBox; streaming::Bool = inputbits(F) ≥ 13)
    streaming || return first.(sorted_pairs(differential_spectrum(F)))
    lut = F.lut
    m = length(lut)
    counts = zeros(Int, m)
    seen = Int[]
    @inbounds for a = 1:(m - 1)
        fill!(counts, 0)
        for x = 0:(m - 1)
            counts[(Int(lut[x + 1]) ⊻ Int(lut[(x ⊻ a) + 1])) + 1] += 1
        end
        for b = 1:m
            c = counts[b]
            c in seen || push!(seen, c)
        end
    end
    sort!(seen)
end

"""
    walsh_value_set(F::SBox; streaming = inputbits(F) ≥ 13) -> Vector{Int}

Sorted set of *distinct signed* Walsh coefficients `F^W(a,b)` over
`(a,b) ≠ (0,0)`.  Theorem 1.1 claims membership in
`{0, ±2^{n/2}, ±2^{(n+2)/2}}` — a value-set claim that a bound such as
`linearity ≤ 2^{(n+t)/2}` cannot certify (BTT-3), and precisely the claim
Section 5 uses to separate `F` from the inverse function.

`streaming = false` reads core `lat`; `streaming = true` transforms one LAT
column at a time via core `walsh_hadamard!` (O(2ⁿ) memory), which is mandatory
at n = 15 where the full LAT is ~8 GB.  Measured here at n=15: **4.9 s**.
"""
function walsh_value_set(F::SBox; streaming::Bool = inputbits(F) ≥ 13)
    if !streaming
        L = lat(F)
        m = size(L, 1)
        seen = Int[]
        @inbounds for a = 1:m, b = 1:m
            (a == 1 && b == 1) && continue
            v = L[a, b]
            v in seen || push!(seen, v)
        end
        return sort!(seen)
    end
    lut = F.lut
    m = length(lut)
    v = zeros(Int, m)
    seen = Int[]
    @inbounds for b = 0:(m - 1)
        for x = 0:(m - 1)
            v[x + 1] = 1 - 2 * (count_ones(b & lut[x + 1]) & 1)
        end
        walsh_hadamard!(v)
        for a = 0:(m - 1)
            (a == 0 && b == 0) && continue
            w = v[a + 1]
            w in seen || push!(seen, w)
        end
    end
    sort!(seen)
end

"""
    linearity_rowwise(F::SBox) -> Int

Streaming linearity (max |LAT[a,b]| outside (0,0)), i.e. the peak of
[`walsh_value_set`](@ref)`(F; streaming = true)`.  O(2ⁿ) memory versus
O(2^{2n}) for the full LAT matrix; required for n ≥ 13, where the LAT exceeds
available RAM.
"""
# TODO(promote-to-core): this streaming linearity / Walsh value set is generic
# (no paper-specific logic) and duplicates what a memory-light `linearity` in
# VBF could offer. Candidate to move into packages/VBF; kept local (core frozen).
linearity_rowwise(F::SBox) = maximum(abs, walsh_value_set(F; streaming = true))

# ---------------------------------------------------------------------------
# Large-n machinery (n = 30, Theorem 1.1's genuine instance)
# ---------------------------------------------------------------------------

"""
    streaming_permutation_check(F::BrackenBinomial; limit = 1 << 18,
                                full_search = false) -> NamedTuple

Injectivity scan of `F` over `x = 0, 1, …` using a `2ⁿ`-bit bitmap (128 MB at
n = 30) and no LUT.  Returns `(; injective, scanned, full_domain, conclusive,
collision)`, where `full_domain` says the budget covered all `2ⁿ` inputs and
`conclusive` says the verdict holds for the whole domain (either the budget was
exhausted, or a collision settled it early).

Per the AGENTS.md rule on expensive searches this takes an explicit budget:
`limit` inputs by default, all `2ⁿ` only when `full_search = true`.

Cost measured here for `(k,s) = (10,2)`, n = 30: 0.27 s at `limit = 2^16`,
0.81 s at `2^18`, 3.26 s at `2^20` — i.e. **≈ 55 min extrapolated** for the
exhaustive `2³⁰` scan in Julia on this machine.  (The review README quoted
"4 m 55 s in C"; that figure was produced by a C program on a *different*
machine and is not ours.)
"""
function streaming_permutation_check(
    F::BrackenBinomial;
    limit::Integer = 1 << 18,
    full_search::Bool = false,
)
    total = 1 << F.n
    budget = full_search ? total : min(Int(limit), total)
    seen = falses(total)
    injective = true
    collision = -1
    @inbounds for x = 0:(budget - 1)
        y = F(x)
        if seen[y + 1]
            injective = false
            collision = x
            break
        end
        seen[y + 1] = true
    end
    (
        injective = injective,
        scanned = budget,
        full_domain = budget == total,
        conclusive = !injective || budget == total,
        collision = collision,
    )
end

"""
    derivative_kernel_dims(F::BrackenBinomial; samples = 2000, seed = 20120512,
                           full_search = false) -> NamedTuple

Rank-based differential check.  `F` is quadratic, so for every `a ≠ 0`

    B_a(x) = F(x ⊕ a) ⊕ F(x) ⊕ F(a) ⊕ F(0)

is F₂-linear and every DDT entry of row `a` is `0` or `2^{dim ker B_a}`.  Hence
`dim ker B_a = t` for all `a ≠ 0` is *equivalent* to Lemma 3.1's
"`Δ_F = 2^t` and the differential spectrum is `{0, 2^t}`", and it never
materialises a DDT row — which is what makes n = 30 reachable.

Same criterion as core `is_quadratic_apn_rank`, which however hard-codes the APN
rank `n − 1`; the kernel dimension is read out here so that `t > 1` is covered.
Rank comes from core `gauss_jordan!`.

Returns `(; dims, samples, exhaustive)` with `dims` the sorted set of observed
kernel dimensions.  `samples` random non-zero `a` by default (`full_search`
scans every `a ≠ 0`, only sane for small n).  Measured here at n = 30,
`(k,s) = (10,2)`: 2000 samples in **0.46 s**, all with `dim ker = 2`.
"""
function derivative_kernel_dims(
    F::BrackenBinomial;
    samples::Integer = 2000,
    seed::Integer = 20120512,
    full_search::Bool = false,
)
    n = F.n
    N = (1 << n) - 1
    f0 = F(0)
    rows = Vector{UInt64}(undef, n)
    dims = Int[]
    function push_dim!(a)
        fa = F(a) ⊻ f0
        @inbounds for j = 0:(n - 1)
            e = 1 << j
            rows[j + 1] = UInt64(F(e ⊻ a) ⊻ F(e) ⊻ fa)
        end
        d = n - gauss_jordan!(rows; nbits = n)
        d in dims || push!(dims, d)
    end
    if full_search
        for a = 1:N
            push_dim!(a)
        end
        return (dims = sort!(dims), samples = N, exhaustive = true)
    end
    rng = MersenneTwister(Int(seed))
    cnt = min(Int(samples), N)
    for _ = 1:cnt
        push_dim!(rand(rng, 1:N))
    end
    (dims = sort!(dims), samples = cnt, exhaustive = false)
end

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

"""
    walsh_set_string(vals) -> String

Compact `{0, ±64, ±256}` rendering of a signed Walsh value set.  Falls back to
listing the raw values when the set is not symmetric under negation (the n=6
inverse function is such a case: `+16` occurs but `−16` does not).
"""
function walsh_set_string(vals::AbstractVector{<:Integer})
    s = Set(vals)
    if all(v -> -v in s, vals)
        pos = sort!(collect(filter(>(0), vals)))
        return "{" * join(vcat(0 in s ? ["0"] : String[], ["±$p" for p in pos]), ", ") * "}"
    end
    "{" * join(sort(collect(vals)), ", ") * "}"
end
