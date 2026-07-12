# Implements Definition 1 — the open butterfly H_R (the permutation half)
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 2.1 — Definition
#
# Definition 1 defines two functions of (F_{2^n})^2:
#   closed butterfly  V_R(x,y) = (R(x,y), R(y,x))                     -> butterfly_closed_lut
#   open   butterfly  H_R(x,y) = (R_{R_y^{-1}(x)}(y), R_y^{-1}(x))    -> butterfly_open_lut
#
# Pseudocode:
#   For each (alpha, beta) != 0:
#     H = butterfly_open_lut(n, i, alpha, beta)
#     V = butterfly_closed_lut(n, i, alpha, beta)
#     assert is_permutation(H)                       (tex: "H_R is a permutation")
#     assert H(H(z)) = z for all z                   (tex: "H_R is an involution")
#     assert differential_uniformity(H) = differential_uniformity(V)
#     if V is APN:  assert algebraic_degree(H) = n+1 and are_ccz_equivalent(H, V)
#   For beta = 1 (the Perrin et al. / Fu et al. subfamily) and alpha != 0,1:
#     assert algebraic_degree(H) = n+1               (tex: "algebraic degree n+1")
#
# H_R is why the paper matters: APN-ness is CCZ-invariant, so the APN closed
# butterflies at n=3 give APN *permutations* on 6 bits, and Theorem 1 says there
# are no others.  V_R itself is never a permutation.
#
# Note on the degree: algebraic_degree(H_R) = n+1 is the tex's claim for the
# beta=1 subfamily with alpha != 0 (Perrin et al.).  For general beta the degree
# does drop to n for some pairs (13 of the 49 at n=3, i=1) — but never on an APN
# pair, so the assertion is scoped to where the paper makes it.
#
# VBF API used: is_permutation, algebraic_degree, differential_uniformity,
#               are_ccz_equivalent, butterfly_open_lut / butterfly_closed_lut (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    definition1_build(n, i; modulus, pairs, check_ccz) -> NamedTuple

Sweep `pairs` (default: every (α,β) ≠ 0) and check the Definition 1 properties
of the open butterfly H_R against the closed butterfly V_R.

`check_ccz` runs `are_ccz_equivalent(H, V)` on the APN pairs only.  It is
deliberately not run on non-APN pairs: outside the quadratic-APN fast path the
general CCZ search on 2n = 6 bits is not tractable here (it exhausts memory).

Returns
(; n, i, n_pairs, all_perm, all_involution, all_du_match, n_apn,
   apn_deg_ok, apn_ccz_ok, beta1_deg_ok, deg_np1_count).
"""
function definition1_build(n::Int, i::Int;
                           modulus::Int = primitive_polynomial(n),
                           pairs = [(a, b) for a in 1:(1 << n) - 1, b in 1:(1 << n) - 1],
                           check_ccz::Bool = true)
    check_params(n, i)
    n_pairs        = 0
    all_perm       = true
    all_involution = true
    all_du_match   = true
    n_apn          = 0
    apn_deg_ok     = true
    apn_ccz_ok     = true
    beta1_deg_ok   = true
    deg_np1_count  = 0
    for (alpha, beta) in pairs
        n_pairs += 1
        H = butterfly_open_lut(n, i, alpha, beta; modulus)
        V = butterfly_closed_lut(n, i, alpha, beta; modulus)
        is_permutation(H) || (all_perm = false)
        all(Int(H.lut[Int(H.lut[z + 1]) + 1]) == z for z in 0:(1 << (2 * n)) - 1) ||
            (all_involution = false)
        du_v = differential_uniformity(V)
        differential_uniformity(H) == du_v || (all_du_match = false)
        deg = algebraic_degree(H)
        deg == n + 1 && (deg_np1_count += 1)
        # tex (Perrin et al.): degree n+1 for the β=1 subfamily, α ≠ 0,1
        beta == 1 && alpha != 1 && deg != n + 1 && (beta1_deg_ok = false)
        if du_v == 2
            n_apn += 1
            deg == n + 1 || (apn_deg_ok = false)
            check_ccz && !are_ccz_equivalent(H, V) && (apn_ccz_ok = false)
        end
    end
    (; n, i, n_pairs, all_perm, all_involution, all_du_match, n_apn,
       apn_deg_ok, apn_ccz_ok, beta1_deg_ok, deg_np1_count)
end

function definition1_report(io::IO = stdout; cases = ((3, 1), (3, 2)))
    print_section("Definition 1 — open butterfly H_R (involution, permutation, CCZ ≅ V_R)", io)
    for (n, i) in cases
        r = definition1_build(n, i)
        print_check(io,
            "n=$n i=$i: H_R is a permutation and an involution ($(r.n_pairs) pairs)",
            r.all_perm && r.all_involution)
        print_check(io,
            "n=$n i=$i: DU(H_R) = DU(V_R) for every (α,β)",
            r.all_du_match)
        print_check(io,
            "n=$n i=$i: deg(H_R) = n+1 = $(n + 1) for β=1, α≠0,1 (Perrin et al.)",
            r.beta1_deg_ok)
        print_check(io,
            "n=$n i=$i: on the $(r.n_apn) APN pairs, deg(H_R)=n+1 and H_R CCZ≅ V_R",
            r.n_apn > 0 && r.apn_deg_ok && r.apn_ccz_ok)
    end
    # n=5: the β=1 subfamily (Perrin/Fu), where the tex's degree claim lives.
    # A full 961-pair sweep would need 961 DDTs on 10 bits; β=1 is the meaningful slice.
    r5 = definition1_build(5, 1; pairs = [(a, 1) for a in 1:31], check_ccz = false)
    print_check(io,
        "n=5 i=1, β=1: H_R permutation/involution, DU(H_R)=DU(V_R), no APN pair ($(r5.n_pairs) α)",
        r5.all_perm && r5.all_involution && r5.all_du_match && r5.n_apn == 0)
    print_check(io,
        "n=5 i=1, β=1: deg(H_R) = n+1 = 6 for α≠0,1",
        r5.beta1_deg_ok)
    print_kv(io, "completeness",
             "exhaustive (α,β) sweep over F_{2^n}*, n=3 (i∈{1,2}); n=5 (i=1) β=1 slice")
end

if abspath(PROGRAM_FILE) == @__FILE__
    definition1_report()
end
