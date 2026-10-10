# Implements Proposition 6 + Theorem 1 — Refined trace condition ⟹ n ≤ 3
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 5 — The Necessary Condition Needs a Small Branch Size
#
# Pseudocode (Prop 6 counting argument, reproduced step by step):
#   D = 1/(1+α²),  F_D(x) = (x^{2^i+1} + x)/(x + D)
#   Im(F_D) = { F_D(x) : x ∉ {0,1,D} }
#   Eq (6):  Σ_{c ∈ Im(F_D)} |{x ∉ {0,1,D} : F_D(x)=c}| = 2^n - 3     [0 ∉ Im(F_D)]
#   c = 1 has exactly one preimage
#   g_D(c) = cD / (1+c)^{2^{n-i}+1}
#   Eq (7):  2^n - 4 = Σ_{c ∈ Im(F_D)\{0,1}} |{u : u^{2^i+1}+u+g_D(c) = 0}|
#   T = { g_D(c) : c ∈ Im(F_D)\{0,1} },  i₁ = |T ∩ S₁|,  i₃ = |T ∩ S₃|
#   Eq (8):  2^n - 4 = i₁ + 3·i₃
#   lemma:   |T| = |Im(F_D)\{0,1}|                (needs the refined trace condition)
#   bounds:  i₁ ≤ 2^{n-1}-1,  i₃ ≤ (2^{n-1}-1)/3,  i₁+i₃ = |T| ≤ 2^{n-1}-1
#            (the last from |Im(F_D)| ≤ 2^{n-1}, itself a consequence of the rtc)
#            ⟹ i₁ + 3i₃ ≤ 2^n - (2^{n-1}+5)/3
#   contradiction with Eq (8) iff (2^{n-1}+5)/3 > 4 ⟺ 2^{n-1} > 7 ⟺ n > 3.
#
# Eq (6) and Eq (7) are partition identities: they hold for *every* α.  The lemma
# |T| = |Im(F_D)\{0,1}| and Eq (8) do NOT — they hold exactly on the α satisfying
# the refined trace condition (n=3: 3 of 6; n=5: 0 of 30; n=7: 0 of 126).  That is
# what makes this a real reproduction of the argument and not a tautology.
#
# Theorem 1 (APN generalised butterfly ⟹ n = 3) is then swept two ways:
#   - by LUT, n ∈ {3,5}: build V_{α,β} for β ∈ {β₁,β₂} and test APN-ness;
#   - by the refined trace condition alone (Proposition 5), which needs NO LUT and
#     costs 2^n field ops per α — so it reaches n = 15 in seconds.
# VBF API used: is_quadratic_apn, gf_mul, gf_pow, gf_inv,
#               butterfly_closed_lut / beta_pair / refined_trace_cond / coprime_exponents (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition6_build(n, i; modulus) -> NamedTuple

For branch size n, verify no APN butterfly exists when n > 3.
Checks both: refined_trace_cond is never satisfied, and V_{α,β₁/β₂} is never APN.
Returns (; n, i, rtc_count, apn_pairs).
"""
function proposition6_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    rtc_count = 0
    apn_pairs = Tuple{Int,Int}[]
    for alpha in 1:(1 << n) - 1
        alpha == 1 && continue   # α=1 verified not APN in proposition3.jl (alpha1_build)
        refined_trace_cond(n, i, alpha; modulus) && (rtc_count += 1)
        b1, b2 = beta_pair(n, i, alpha; modulus)
        for beta in (b1, b2)
            F = butterfly_closed_lut(n, i, alpha, beta; modulus)
            is_quadratic_apn(F) && push!(apn_pairs, (alpha, beta))
        end
    end
    (; n, i, rtc_count, apn_pairs)
end

"""
    prop6_counting(n, i, alpha; modulus) -> NamedTuple

Reproduce the counting argument in the proof of Proposition 6 for one α ≠ 0,1.

Returns
(; alpha, D, rtc, im_size, imr_size, c1_preimages, zero_in_im,
   eq6, eq6_ok, eq7, eq7_ok, t_size, i1, i3,
   lemma_ok, eq8_ok, im_bound_ok, s1_bound_ok, s3_bound_ok, sum_bound_ok, final_bound_ok)

where `eq6_ok`/`eq7_ok` are the partition identities (true for every α) and
`lemma_ok`/`eq8_ok`/`im_bound_ok` are the rtc-dependent steps.
"""
function prop6_counting(n::Int, i::Int, alpha::Int;
                        modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    alpha in (0, 1) && throw(ArgumentError("prop6_counting: α must differ from 0 and 1"))
    len = 1 << n
    e   = (1 << i) + 1
    D   = gf_inv(1 ⊻ gf_mul(alpha, alpha, n; modulus), n; modulus)   # D = 1/(1+α²)
    FD(x) = gf_mul(gf_pow(x, e, n; modulus) ⊻ x,
                   gf_inv(x ⊻ D, n; modulus), n; modulus)
    gD(c) = gf_mul(gf_mul(c, D, n; modulus),
                   gf_inv(gf_pow(1 ⊻ c, (1 << (n - i)) + 1, n; modulus), n; modulus),
                   n; modulus)

    # Proposition 1 solution counts of x^{2^i+1} + x = a, giving S₁ and S₃
    nsol = zeros(Int, len)
    for x in 0:len-1
        nsol[(gf_pow(x, e, n; modulus) ⊻ x) + 1] += 1
    end
    inS1(a) = a != 0 && nsol[a + 1] == 1
    inS3(a) = a != 0 && nsol[a + 1] == 3

    # Im(F_D) with preimage counts, over x ∉ {0,1,D}
    pre = Dict{Int,Int}()
    for x in 0:len-1
        (x == 0 || x == 1 || x == D) && continue
        c = FD(x)
        pre[c] = get(pre, c, 0) + 1
    end
    im_size      = length(pre)
    zero_in_im   = haskey(pre, 0)
    c1_preimages = get(pre, 1, 0)
    eq6          = sum(values(pre))                      # Eq (6): = 2^n - 3

    # Eq (7) and T = { g_D(c) : c ∈ Im(F_D)\{0,1} }
    imr = [c for c in keys(pre) if c != 0 && c != 1]
    eq7 = 0
    T   = Set{Int}()
    for c in imr
        g = gD(c)
        push!(T, g)
        eq7 += nsol[g + 1]        # |{u : u^{2^i+1}+u+g_D(c) = 0}|, by Prop 1 either 1 or 3
    end
    i1 = count(inS1, T)
    i3 = count(inS3, T)

    (; alpha, D,
       rtc = refined_trace_cond(n, i, alpha; modulus),
       im_size, imr_size = length(imr), c1_preimages, zero_in_im,
       eq6, eq6_ok = eq6 == 2^n - 3,
       eq7, eq7_ok = eq7 == 2^n - 4,
       t_size = length(T), i1, i3,
       lemma_ok        = length(T) == length(imr),          # |T| = |Im(F_D)\{0,1}|
       eq8_ok          = i1 + 3 * i3 == 2^n - 4,            # Eq (8)
       im_bound_ok     = im_size <= 2^(n - 1),              # Tr(F_D(x)^τ) ≡ 1 ⟹ |Im| ≤ 2^{n-1}
       s1_bound_ok     = i1 <= 2^(n - 1) - 1,               # |S₁| bound
       s3_bound_ok     = 3 * i3 <= 2^(n - 1) - 1,           # |S₃| = (2^{n-1}-1)/3
       sum_bound_ok    = i1 + i3 <= 2^(n - 1) - 1,
       # i₁ + 3i₃ ≤ 2^n - (2^{n-1}+5)/3, cleared of the denominator
       final_bound_ok  = 3 * (i1 + 3 * i3) <= 3 * 2^n - (2^(n - 1) + 5))
end

"""
    prop6_contradiction(n) -> Bool

The closing arithmetic of Proposition 6: Eq (8) gives i₁+3i₃ = 2^n-4 while the
bounds give i₁+3i₃ ≤ 2^n-(2^{n-1}+5)/3.  The two contradict exactly when
(2^{n-1}+5)/3 > 4 ⟺ 2^{n-1} > 7 ⟺ n > 3.  Hence the refined trace condition
forces n ≤ 3.  Integer form: 3(2^n-4) > 3·2^n - (2^{n-1}+5).
"""
prop6_contradiction(n::Int) = 3 * (2^n - 4) > 3 * 2^n - (2^(n - 1) + 5)

"""
    proposition6_counting_build(n, i; modulus) -> Vector{NamedTuple}

`prop6_counting` for every α ≠ 0,1.
"""
proposition6_counting_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n)) =
    [prop6_counting(n, i, alpha; modulus) for alpha in 2:(1 << n) - 1]

"""
    theorem1_build(i; n_values, moduli) -> Vector{NamedTuple}

Verify Theorem 1 by LUT: APN closed butterfly ⟹ n = 3.
Tests n ∈ {3, 5} (both odd).  Larger n are handled by `theorem1_rtc_sweep`,
which needs no LUT at all.
"""
function theorem1_build(i::Int = 1;
                        n_values  = [3, 5],
                        moduli = Dict(n => primitive_polynomial(n) for n in n_values))
    results = NamedTuple[]
    for n in n_values
        r = proposition6_build(n, i; modulus = moduli[n])
        push!(results, r)
    end
    results
end

"""
    theorem1_rtc_sweep(; n_values) -> Vector{NamedTuple}

Verify Theorem 1 for large branch sizes *without building any LUT*.

By Proposition 5, APN-ness of the butterfly is equivalent to the refined trace
condition, which is a 2^n-element trace check on α alone.  So a 2^{2n}-entry LUT
is never needed: n = 15 costs a fraction of a second.  For every n in `n_values`
and every i with gcd(i,n) = 1, count the α ≠ 0,1 satisfying the condition.
Returns one entry per (n, i): (; n, i, rtc_count).
"""
function theorem1_rtc_sweep(; n_values = [3, 5, 7, 9, 11, 13, 15])
    results = NamedTuple[]
    for n in n_values, i in coprime_exponents(n)
        rtc_count = count(alpha -> alpha != 1 && refined_trace_cond(n, i, alpha),
                          1:(1 << n) - 1)
        push!(results, (; n, i, rtc_count))
    end
    results
end

function proposition6_report(io::IO = stdout;
                             i_n3 = (1, 2), i_n5 = (1, 2, 3, 4),
                             rtc_n_values = [3, 5, 7, 9, 11, 13, 15])
    print_section("Proposition 6 + Theorem 1 — APN butterfly ⟹ n = 3", io)

    # --- the counting argument itself ---
    for i in i_n3
        res = proposition6_counting_build(3, i)
        rtc = [r for r in res if r.rtc]
        print_check(io,
            "n=3 i=$i: Eq (6) Σ|preim| = 2^n-3 and Eq (7) = 2^n-4 for all α ($(length(res)) α)",
            all(r.eq6_ok && r.eq7_ok && r.c1_preimages == 1 && !r.zero_in_im for r in res))
        print_check(io,
            "n=3 i=$i: |T| = |Im(F_D)\\{0,1}| and Eq (8) 2^n-4 = i₁+3i₃ on the $(length(rtc)) rtc α " *
            "(|Im|=$(join(unique(r.im_size for r in rtc), ",")), i₁=$(join(unique(r.i1 for r in rtc), ",")), i₃=$(join(unique(r.i3 for r in rtc), ",")))",
            !isempty(rtc) && all(r.lemma_ok && r.eq8_ok for r in rtc))
        print_check(io,
            "n=3 i=$i: bounds i₁≤2^{n-1}-1, 3i₃≤2^{n-1}-1, |Im|≤2^{n-1}, i₁+3i₃ ≤ 2^n-(2^{n-1}+5)/3",
            all(r.im_bound_ok && r.s1_bound_ok && r.s3_bound_ok && r.sum_bound_ok &&
                r.final_bound_ok for r in rtc))
        print_check(io,
            "n=3 i=$i: the lemma and Eq (8) break down on the $(count(!r.rtc for r in res)) non-rtc α " *
            "(the argument is rtc-dependent, not a tautology)",
            all(!r.lemma_ok && !r.eq8_ok for r in res if !r.rtc))
    end
    print_check(io,
        "contradiction (2^{n-1}+5)/3 > 4 ⟺ n > 3: false at n=3, true at n=5,7,9,…,15",
        !prop6_contradiction(3) && all(prop6_contradiction(n) for n in 5:2:15))

    # --- Theorem 1, by LUT ---
    for i in i_n3
        res3 = proposition6_build(3, i)
        print_check(io,
            "n=3 i=$i: APN butterflies exist ($(length(res3.apn_pairs)) pairs)",
            !isempty(res3.apn_pairs))
    end
    for i in i_n5
        res5 = proposition6_build(5, i)
        print_check(io,
            "n=5 i=$i: no APN butterfly, rtc never true (Prop 6 + Thm 1)",
            isempty(res5.apn_pairs) && res5.rtc_count == 0)
    end

    # --- Theorem 1, by refined trace condition alone (no LUT) ---
    sweep = theorem1_rtc_sweep(; n_values = rtc_n_values)
    for n in rtc_n_values
        rs = [r for r in sweep if r.n == n]
        expected = n == 3 ? 3 : 0
        print_check(io,
            "n=$n: rtc_count = $(join(unique(r.rtc_count for r in rs), ",")) for all $(length(rs)) coprime i " *
            (n == 3 ? "(the 6-bit APN case)" : "(no APN butterfly)"),
            all(r.rtc_count == expected for r in rs))
    end
    print_kv(io, "completeness",
             "counting argument: exhaustive over α≠0,1 (n=3); Theorem 1 by LUT: n∈{3,5}, " *
             "all coprime i; by refined trace condition: n∈$(rtc_n_values), all coprime i")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition6_report()
end
