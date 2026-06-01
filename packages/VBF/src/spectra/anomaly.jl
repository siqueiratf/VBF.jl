"""
Anomaly framework — [Bonnetain, Perrin and Tian (2019)](@cite BonnetainPerrinTian2019Anomaly).

Given an S-box `F`, the *anomaly* quantifies how unlikely the observed
maximum entry of its DDT / LAT / BCT is under the null hypothesis "F is
a uniformly random permutation of F₂ⁿ". The original derivations of the
per-coefficient probability mass functions for DDT and LAT are from
[Daemen and Rijmen (2007)](@cite DaemenRijmen2007Probability); the BCT formula is
from [Bonnetain, Perrin and Tian (2019)](@cite BonnetainPerrinTian2019Anomaly).

All routines work in arbitrary-precision arithmetic via stdlib
`BigFloat`. The `precision` kwarg (in bits) controls `setprecision`
locally; the default `120` is enough for `n ≤ 8` corpora.

# Public surface
- [`ddt_coeff_probability`](@ref) — PMF of a DDT coefficient under the
  uniformly-random-function model (Daemen-Rijmen 2007).
- [`expected_max_distribution`](@ref) — generic helper: given a PMF
  generator and a coefficient count `n_coeffs`, returns the PMF of the
  maximum.
- [`expected_differential_uniformity_distribution`](@ref) — PMF of the
  differential uniformity of a random function.
"""

# DDT coefficient PMF (Daemen-Rijmen 2007)

"""
    ddt_coeff_probability(n, m, c; precision::Int = 120) -> BigFloat

Probability that any fixed non-trivial DDT entry of a random function
`F : F₂ⁿ → F₂ᵐ` equals `c`. Odd `c` yield `0`.

For `n ≥ 5` and `m - n ≤ n / 4` the Poisson approximation
``P(2k) ≈ e^{-λ} λ^k / k!`` with `λ = 2^{n - m - 1}` is used (Daemen-Rijmen
Theorem 1, asymptotic regime). Otherwise the exact binomial
``P(2k) = C(2^{n-1}, k) · 2^{-mk} · (1 - 2^{-m})^{2^{n-1} - k}`` is used.

The two cases agree to floating-point precision in their overlap.
"""
function ddt_coeff_probability(
    n::Integer,
    m::Integer,
    c::Integer;
    precision::Int = 120,
)
    isodd(c) && return BigFloat(0)
    c < 0 && return BigFloat(0)
    d = Int(c >> 1)
    setprecision(BigFloat, precision) do
        if n ≥ 5 && (m - n) ≤ n / 4
            λ = BigFloat(2)^(n - m - 1)
            return exp(-λ) * λ^d / BigFloat(factorial(big(d)))
        else
            half = 1 << (n - 1)
            half_big = BigInt(half)
            return BigFloat(binomial(half_big, BigInt(d))) *
                   BigFloat(2)^(-m * d) *
                   (BigFloat(1) - BigFloat(2)^(-m))^(half - d)
        end
    end
end

# Maximum-of-iid PMF (generic; works for DDT / LAT / BCT alike)

"""
    expected_max_distribution(n, m, pmf, n_coeffs;
                              vmin = 2, vmax = 128, precision = 120)
        -> Dict{Int, BigFloat}

PMF of the maximum of `n_coeffs` i.i.d. samples whose marginal PMF is
`pmf(n, m, c; precision = …)`. Returns a dictionary `d` with
`d[k] = P(max == k)` for `k` in `vmin:vmax` whose mass is non-negligible.

This is the workhorse behind every `expected_*_distribution_*` function.
"""
function expected_max_distribution(
    n::Integer,
    m::Integer,
    pmf,
    n_coeffs::Integer;
    vmin::Integer = 2,
    vmax::Integer = 128,
    precision::Int = 120,
)
    setprecision(BigFloat, precision) do
        power = BigFloat(n_coeffs)
        cumul = Dict{Int,BigFloat}()
        prev_cdf = BigFloat(0)
        for k = vmin:(vmax+1)
            cdf_below_k = sum(
                pmf(n, m, z; precision = precision) for z = 0:k;
                init = BigFloat(0),
            )
            cdf_pow = cdf_below_k^power
            if cdf_pow > 0
                cumul[k] = cdf_pow
            elseif haskey(cumul, k - 1)
                cumul[k] = cumul[k-1]
            end
        end
        # PMF = consecutive differences of CDF
        result = Dict{Int,BigFloat}()
        ks = sort(collect(keys(cumul)))
        for i = 2:length(ks)
            result[ks[i]] = cumul[ks[i]] - cumul[ks[i-1]]
        end
        result
    end
end

"""
    expected_differential_uniformity_distribution(n;
                                                  m = n, vmin = 2, vmax = 128,
                                                  precision = 120)
        -> Dict{Int, BigFloat}

PMF of the differential uniformity of a uniformly random function
`F : F₂ⁿ → F₂ᵐ`. Uses the
``(2^n - 1)(2^m - 1)`` non-trivial cells of the DDT as the trial count.
"""
function expected_differential_uniformity_distribution(
    n::Integer;
    m::Integer = n,
    vmin::Integer = 2,
    vmax::Integer = 128,
    precision::Int = 120,
)
    n_coeffs = (1 << n - 1) * (1 << m - 1)
    expected_max_distribution(
        n,
        m,
        ddt_coeff_probability,
        n_coeffs;
        vmin = vmin,
        vmax = vmax,
        precision = precision,
    )
end

# LAT coefficient PMF (Daemen-Rijmen 2007)

"""
    lat_coeff_probability(n, m, c; permutation = true, precision = 120) -> BigFloat

Probability that any fixed non-trivial LAT entry of a uniformly random
function `F : F₂ⁿ → F₂ⁿ` has absolute value `c` (`m` must equal `n`).
The two regimes — permutation and arbitrary function — have different
closed forms.

Permutation case (Daemen-Rijmen):
- `c % 4 ≠ 0` → 0
- `c = 0`     → `C(2^(n-1), 2^(n-2))² / C(2^n, 2^(n-1))`
- `c > 0`     → `2 · C(2^(n-1), 2^(n-2) + c/4)² / C(2^n, 2^(n-1))`

Function case (`permutation = false`):
- `c % 2 ≠ 0` → 0
- `c = 0`     → `2^(-2^n) · C(2^n, 2^(n-1))`
- `c > 0`     → `2 · 2^(-2^n) · C(2^n, 2^(n-1) + c/2)`
"""
function lat_coeff_probability(
    n::Integer,
    m::Integer,
    c::Integer;
    permutation::Bool = true,
    precision::Int = 120,
)
    n == m ||
        throw(ArgumentError("lat_coeff_probability: m=$m must equal n=$n"))
    c < 0 && return BigFloat(0)
    setprecision(BigFloat, precision) do
        if permutation
            c % 4 == 0 || return BigFloat(0)
            half = BigInt(1) << (n - 1)        # 2^(n-1)
            quarter = BigInt(1) << (n - 2)        # 2^(n-2)
            denom = BigFloat(binomial(BigInt(1) << n, half))
            if c == 0
                return BigFloat(binomial(half, quarter))^2 / denom
            else
                k = quarter + (BigInt(c) >> 2)     # 2^(n-2) + c/4
                k > half && return BigFloat(0)
                return 2 * BigFloat(binomial(half, k))^2 / denom
            end
        else
            iseven(c) || return BigFloat(0)
            two_n = BigInt(1) << n              # 2^n
            half = two_n >> 1                  # 2^(n-1)
            scale = BigFloat(2)^(-two_n)
            if c == 0
                return scale * BigFloat(binomial(two_n, half))
            else
                k = half + (BigInt(c) >> 1)        # 2^(n-1) + c/2
                k > two_n && return BigFloat(0)
                return 2 * scale * BigFloat(binomial(two_n, k))
            end
        end
    end
end

"""
    expected_linearity_distribution(n; permutation = true,
                                    vmin = 8, vmax = 128, precision = 120)
        -> Dict{Int, BigFloat}

PMF of the linearity of a uniformly random function `F : F₂ⁿ → F₂ⁿ`.
Wires `(2^n - 1)²` (permutation) or `(2^n - 1) · 2^n` (function) trials
to [`expected_max_distribution`](@ref).
"""
function expected_linearity_distribution(
    n::Integer;
    permutation::Bool = true,
    vmin::Integer = 8,
    vmax::Integer = 128,
    precision::Int = 120,
)
    pmf =
        (nn, mm, cc; precision = 120) -> lat_coeff_probability(
            nn,
            mm,
            cc;
            permutation = permutation,
            precision = precision,
        )
    n_coeffs =
        permutation ? (1 << n - 1) * (1 << n - 1) : (1 << n - 1) * (1 << n)
    expected_max_distribution(
        n,
        n,
        pmf,
        n_coeffs;
        vmin = vmin,
        vmax = vmax,
        precision = precision,
    )
end

# BCT coefficient PMF (Bonnetain-Perrin-Tian ASIACRYPT 2019)

"""
    bct_coeff_probability(n, m, c; precision = 120) -> BigFloat

Probability that any fixed non-trivial BCT entry of a uniformly random
permutation of `F₂ⁿ` equals `c` (`m` must equal `n`). Odd `c` yield `0`.

Bonnetain-Perrin-Tian ASIACRYPT 2019:

  Let B = 2^(n-1), A = 2^(2n-2) - 2^(n-1).
  P(BCT = c) = Σ_{(j₁, j₂) : 2j₁ + 4j₂ = c}
                C(B, j₁) · (2^n - 2)^(B - j₁) ·
                C(A, j₂) · (2^(2n) - 2^(n+1))^(A - j₂)
              ────────────────────────────────────────
                              (2^n - 1)^(B + 2A)

The double sum is sparse: for each `c`, only `j₁` values with
`c - 2j₁ ≥ 0` and divisible by 4 contribute, and only one `j₂` follows.
"""
function bct_coeff_probability(
    n::Integer,
    m::Integer,
    c::Integer;
    precision::Int = 120,
)
    n == m ||
        throw(ArgumentError("bct_coeff_probability: m=$m must equal n=$n"))
    isodd(c) && return BigFloat(0)
    c < 0 && return BigFloat(0)
    setprecision(BigFloat, precision) do
        B = BigInt(1) << (n - 1)
        A = (BigInt(1) << (2n - 2)) - B
        two_n = BigInt(1) << n
        x_b = two_n - 2                       # (2^n - 2)
        x_a = (BigInt(1) << (2n)) - (two_n << 1)   # (2^(2n) - 2^(n+1))
        denom_base = two_n - 1                       # (2^n - 1)
        denom_exp = B + 2A                          # (2^n - 1)^(B + 2A)
        denom = BigFloat(denom_base)^denom_exp
        result = BigFloat(0)
        # Iterate j1 in 0..min(B, c÷2); j2 = (c - 2j1)/4 must be an integer in
        # 0..A.
        j1_max = min(B, BigInt(c) ÷ 2)
        for j1 = BigInt(0):j1_max
            rem = BigInt(c) - 2 * j1
            rem % 4 == 0 || continue
            j2 = rem ÷ 4
            j2 > A && continue
            term =
                BigFloat(binomial(B, j1)) *
                BigFloat(x_b)^(B - j1) *
                BigFloat(binomial(A, j2)) *
                BigFloat(x_a)^(A - j2)
            result += term / denom
        end
        result
    end
end

"""
    expected_boomerang_uniformity_distribution(n;
                                                vmin = 2, vmax = 128,
                                                precision = 120)
        -> Dict{Int, BigFloat}

PMF of the boomerang uniformity of a uniformly random permutation of
`F₂ⁿ`. Wires `(2^n - 1)²` trials to [`expected_max_distribution`](@ref).
"""
function expected_boomerang_uniformity_distribution(
    n::Integer;
    vmin::Integer = 2,
    vmax::Integer = 128,
    precision::Int = 120,
)
    n_coeffs = (1 << n - 1) * (1 << n - 1)
    expected_max_distribution(
        n,
        n,
        bct_coeff_probability,
        n_coeffs;
        vmin = vmin,
        vmax = vmax,
        precision = precision,
    )
end

# Aggregate anomaly scoring

"""
    _max_and_occurrences(spec::Spectrum) -> (v_max::Int, occurrences::Int)

The largest absolute value present in `spec` and how many times entries
of that absolute value occur. Internal.
"""
function _max_and_occurrences(spec::Spectrum)
    v_max = 0
    occurrences = 0
    for (k, count) in spec.counts
        ak = abs(k)
        if ak == v_max
            occurrences += count
        elseif ak > v_max
            v_max = ak
            occurrences = count
        end
    end
    v_max, occurrences
end

"""
    _proba_at_most_v_max(n, m, v_max, occurrences, pmf, precision) -> BigFloat

Probability that, of the `(2^m - 1)(2^n - 1)` non-trivial cells, none
exceed `v_max` and at most `occurrences` of them are exactly `v_max`.
Internal.
"""
function _proba_at_most_v_max(
    n::Integer,
    m::Integer,
    v_max::Integer,
    occurrences::Integer,
    pmf,
    precision::Int,
)
    setprecision(BigFloat, precision) do
        p_strictly_smaller = sum(
            pmf(n, m, i; precision = precision) for i = 0:(v_max-1);
            init = BigFloat(0),
        )
        p_equal = pmf(n, m, v_max; precision = precision)
        n_trials = BigInt(1 << n - 1) * BigInt(1 << m - 1)
        result = BigFloat(0)
        for occ = 0:occurrences
            term =
                BigFloat(binomial(n_trials, BigInt(occ))) *
                p_strictly_smaller^(n_trials - occ) *
                p_equal^occ
            result += term
        end
        result
    end
end

function _spec_and_pmf(s::SBox, table::Symbol)
    if table === :DDT
        return differential_spectrum(s), ddt_coeff_probability
    elseif table === :LAT
        perm = is_permutation(s)
        pmf =
            (nn, mm, cc; precision = 120) -> lat_coeff_probability(
                nn,
                mm,
                cc;
                permutation = perm,
                precision = precision,
            )
        return absolute_walsh_spectrum(s), pmf
    elseif table === :BCT
        is_permutation(s) || throw(
            ArgumentError("table_anomaly(:BCT, …) requires a permutation"),
        )
        return boomerang_spectrum(s), bct_coeff_probability
    else
        throw(
            ArgumentError(
                "table_anomaly: unknown table $(repr(table)); use :DDT, :LAT, or :BCT",
            ),
        )
    end
end

"""
    table_anomaly(s::SBox, table::Symbol; precision = 120) -> BigFloat

The **positive anomaly** of `s` against the random-permutation null
hypothesis for the given `table` (`:DDT`, `:LAT`, or `:BCT`).

Computed as `-log₂ P(observed max or smaller, with at most as many
ties)` — large values mean the observed maximum is implausibly small
under random, i.e., the S-box is *unusually good*.

Returns a `BigFloat`. A value near zero means the S-box's table is
consistent with a random permutation; large positive values indicate
structure.

# Examples
```jldoctest
julia> using VBF

julia> Float64(table_anomaly(load_literature_sbox("AES"), :DDT)) > 1.0
true
```
"""
function table_anomaly(s::SBox, table::Symbol; precision::Int = 120)
    spec, pmf = _spec_and_pmf(s, table)
    n = inputbits(s)
    v_max, occurrences = _max_and_occurrences(spec)
    p = _proba_at_most_v_max(n, n, v_max, occurrences, pmf, precision)
    setprecision(BigFloat, precision) do
        return -log2(p)
    end
end

"""
    table_negative_anomaly(s::SBox, table::Symbol; precision = 120) -> BigFloat

The **negative anomaly** of `s` against the random null hypothesis for
the given `table`. Symmetric counterpart of [`table_anomaly`](@ref):
large values mean the observed maximum is implausibly *large* (more
ties than random would predict).

A nontrivial negative anomaly is rare for cryptographic S-boxes — it
flags structural over-concentration.
"""
function table_negative_anomaly(s::SBox, table::Symbol; precision::Int = 120)
    spec, pmf = _spec_and_pmf(s, table)
    n = inputbits(s)
    v_max, occurrences = _max_and_occurrences(spec)
    setprecision(BigFloat, precision) do
        m = n
        p_anomaly =
            _proba_at_most_v_max(n, m, v_max, occurrences, pmf, precision)
        p_equal = pmf(n, m, v_max; precision = precision)
        p_strictly_smaller = sum(
            pmf(n, m, i; precision = precision) for i = 0:(v_max-1);
            init = BigFloat(0),
        )
        card = BigInt(1 << n - 1) * BigInt(1 << m - 1)
        p_precise_equal =
            BigFloat(binomial(card, BigInt(occurrences))) *
            p_equal^occurrences *
            p_strictly_smaller^(card - occurrences)
        return -log2(p_precise_equal - p_anomaly + 1)
    end
end
