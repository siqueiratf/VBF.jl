# Implements Proposition 4 — Trace Condition A_α(e) ↔ APN, and the Prop 4 ↔ Prop 5 bridge
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 4 — Necessary Condition for a Generalized Butterfly to be APN
#
# Pseudocode:
#   A_α(e) = α^{2^i-1} · e(1+α)² / ((1+αe)(α+e)^{2^i})
#   prop4_cond(α) = ∀ e ∉ {0, α, 1/α}: Tr(A_α(e)^τ) = 1
#   For each α ≠ 0,1 and every β ≠ 0:
#     assert is_apn(V_{α,β}) == (β ∈ {β₁,β₂} and prop4_cond(α))   (Prop 4, both directions)
#   Bridge: assert prop4_cond(α) == refined_trace_cond(α)          (Prop 4 ↔ Prop 5)
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, primitive_polynomial, is_quadratic_apn,
#               butterfly_closed_lut / beta_pair / refined_trace_cond (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    prop4_trace_cond(n, i, alpha; modulus) -> Bool

Proposition 4 trace condition: Tr(A_α(e)^τ) = 1 for all e ∉ {0, α, 1/α},
where A_α(e) = α^{2^i-1} · e(1+α)² / ((1+αe)(α+e)^{2^i}).
(The proposition display in the source tex shows an extra α in the
numerator; the derivation in the proof and in Proposition 5's proof both
use e(1+α)², which is the version verified here.)
"""
function prop4_trace_cond(n::Int, i::Int, alpha::Int;
                          modulus::Int = primitive_polynomial(n))
    q    = 1 << i
    tau  = tau_exp(n, i)
    ainv = gf_inv(alpha, n; modulus)
    one_a2 = gf_mul(1 ⊻ alpha, 1 ⊻ alpha, n; modulus)      # (1+α)²
    pref   = gf_pow(alpha, q - 1, n; modulus)               # α^{2^i-1}
    all(0:((1 << n) - 1)) do e
        (e == 0 || e == alpha || e == ainv) && return true
        num = gf_mul(e, one_a2, n; modulus)
        den = gf_mul(1 ⊻ gf_mul(alpha, e, n; modulus),
                     gf_pow(alpha ⊻ e, q, n; modulus), n; modulus)
        A = gf_mul(pref, gf_mul(num, gf_inv(den, n; modulus), n; modulus),
                   n; modulus)
        gf_trace(gf_pow(A, tau, n; modulus), n; modulus) == 1
    end
end

"""
    proposition4_build(n, i; modulus) -> Vector{NamedTuple}

For each α ≠ 0,1 verify Proposition 4 in both directions over a full β sweep:
V_{α,β} is APN ⟺ β ∈ {β₁,β₂} and prop4_trace_cond(α).
Also verifies the change-of-variables bridge prop4_trace_cond ↔ Prop 5's
refined_trace_cond for every α.
Returns one entry per α: (alpha, cond, rtc, bridge, n_apn, iff_holds).
"""
function proposition4_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    results = NamedTuple[]
    for alpha in 1:(1 << n) - 1
        alpha == 1 && continue   # α=1 verified not APN in proposition3.jl (alpha1_build)
        b1, b2 = beta_pair(n, i, alpha; modulus)
        cond   = prop4_trace_cond(n, i, alpha; modulus)
        rtc    = refined_trace_cond(n, i, alpha; modulus)
        n_viol = 0
        n_apn  = 0
        for beta in 1:(1 << n) - 1
            F   = butterfly_closed_lut(n, i, alpha, beta; modulus)
            apn = is_quadratic_apn(F)
            apn && (n_apn += 1)
            expected = (beta == b1 || beta == b2) && cond
            apn == expected || (n_viol += 1)
        end
        push!(results, (; alpha, cond, rtc,
                          bridge    = cond == rtc,
                          n_apn,
                          iff_holds = n_viol == 0))
    end
    results
end

function proposition4_report(io::IO = stdout;
                             cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Proposition 4 — Trace Condition A_α(e) ↔ APN", io)
    for (n, i) in cases
        res      = proposition4_build(n, i)
        all_iff  = all(r.iff_holds for r in res)
        all_brdg = all(r.bridge for r in res)
        n_cond   = count(r.cond for r in res)
        n_apn    = sum(r.n_apn for r in res)
        print_check(io,
            "n=$n i=$i: APN ⟺ β∈{β₁,β₂} ∧ Tr(A_α(e)^τ)=1 ∀e ($(n_cond) α, $(n_apn) APN pairs)",
            all_iff)
        print_check(io,
            "n=$n i=$i: Prop 4 cond ↔ Prop 5 refined cond (bridge)",
            all_brdg)
    end
    print_kv(io, "completeness",
             "exhaustive over F_{2^n} (full β sweep), all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition4_report()
end
