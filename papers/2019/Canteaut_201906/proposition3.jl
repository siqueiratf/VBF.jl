# Implements Proposition 3 — Condition on β for APN butterfly
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 4 — Necessary Condition for a Generalized Butterfly to be APN
#
# Pseudocode:
#   For each α ≠ 0,1 in F_{2^n}:
#     β₁ = α^{q-1} + α^{q+1},  β₂ = α^{1-q} + α^{q+1}
#     For each β ≠ 0 not in {β₁, β₂}:
#       assert V_{α,β} is NOT APN  (Prop 3 contrapositive)
#   α=1 exclusion (3-round Feistel argument in the paper, [12]):
#     For each β ≠ 0: assert differential_uniformity(V_{1,β}) ≥ 4
# VBF API used: gf_pow, butterfly_closed_lut (helpers), is_quadratic_apn,
#               differential_uniformity, beta_pair (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition3_build(n, i; modulus) -> Vector{NamedTuple}

For each α ≠ 0,1 in F_{2^n}, verify Proposition 3:
any APN butterfly has β ∈ {β₁, β₂}.
Returns one entry per α with fields (alpha, b1, b2, prop3_holds, n_apn_total).
"""
function proposition3_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    results = NamedTuple[]
    for alpha in 1:(1 << n) - 1
        alpha == 1 && continue          # α=1 excluded; verified not APN by alpha1_build below
        b1, b2 = beta_pair(n, i, alpha; modulus)
        n_outside = 0
        n_apn     = 0
        for beta in 1:(1 << n) - 1
            F   = butterfly_closed_lut(n, i, alpha, beta; modulus)
            apn = is_quadratic_apn(F)
            apn && (n_apn += 1)
            apn && beta != b1 && beta != b2 && (n_outside += 1)
        end
        push!(results, (; alpha, b1, b2,
                          prop3_holds = n_outside == 0,
                          n_apn_total = n_apn))
    end
    results
end

"""
    alpha1_build(n, i; modulus) -> NamedTuple

Computational verification of the paper's α=1 exclusion (Prop 3 proof):
for α=1 the open butterfly is functionally equivalent to a 3-round
Feistel network, hence has differential uniformity at least 4 and is
never APN. Checks every β ≠ 0.
Returns (; n, i, min_du, n_apn).
"""
function alpha1_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    min_du = typemax(Int)
    n_apn  = 0
    for beta in 1:(1 << n) - 1
        F  = butterfly_closed_lut(n, i, 1, beta; modulus)
        du = differential_uniformity(F)
        du < min_du && (min_du = du)
        du == 2 && (n_apn += 1)
    end
    (; n, i, min_du, n_apn)
end

function proposition3_report(io::IO = stdout;
                             cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Proposition 3 — APN ⟹ β ∈ {β₁, β₂}", io)
    for (n, i) in cases
        res = proposition3_build(n, i)
        all_hold = all(r.prop3_holds for r in res)
        n_apn    = sum(r.n_apn_total for r in res)
        print_check(io,
            "n=$n i=$i: all APN butterflies have β∈{β₁,β₂} ($(n_apn) APN pairs)",
            all_hold)
        a1 = alpha1_build(n, i)
        print_check(io,
            "n=$n i=$i: α=1 never APN (min diff. uniformity $(a1.min_du) ≥ 4 ∀β)",
            a1.min_du >= 4 && a1.n_apn == 0)
    end
    print_kv(io, "completeness",
             "exhaustive over F_{2^n} (full β sweep), all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition3_report()
end
