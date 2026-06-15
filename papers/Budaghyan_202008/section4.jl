# Implements Section IV — Isotopic Shifts of APN Functions.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: IV (Theorem IV.1 and Corollary IV.2)
#
# Pseudocode:
#   Theorem IV.1:
#     1. F_L = 0  ⟺  L(a) ∈ {0, a} for all a ∈ F_q*
#     2. If L linear: F_L = 0  ⟺  L = 0 or L(x) = x
#   Corollary IV.2(ii):
#     3. For DO APN F and linear L, M: F_L = F_M  ⟺  L = M or L(x) = M(x) ⊕ x
# VBF API used: gold_apn, SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))
using Dates

"""
    section4_check_theoremIV1(; io) -> NamedTuple

Verify Theorem IV.1: degenerate linear maps produce the zero isotopic shift.
Tested on G_1 = x³ over GF(2⁵).
"""
function section4_check_theoremIV1(; io::IO = devnull)
    n = 5
    mod = primitive_polynomial(n)

    G1 = gold_lut(n, 1; modulus = mod)

    L_zero = zero_map_lut(n)
    L_id   = identity_map_lut(n)
    L_frob = linear_monomial_lut(n, 1, 1; modulus = mod)  # L(x) = x²

    shift_zero = isotopic_shift_lut(G1, L_zero)
    shift_id   = isotopic_shift_lut(G1, L_id)
    shift_frob = isotopic_shift_lut(G1, L_frob)

    ok_zero = is_zero_map(shift_zero)
    ok_id   = is_zero_map(shift_id)
    ok_frob = !is_zero_map(shift_frob)

    print_section(io, "Section IV — Theorem IV.1")
    print_check(io, "L=0   → F_L = 0", ok_zero)
    print_check(io, "L=id  → F_L = 0 (since L(a)=a ∈ {0,a})", ok_id)
    print_check(io, "L=x²  → F_L ≠ 0 (x²∉{0,a} for a∉F₂)", ok_frob)

    (; ok_zero, ok_id, ok_frob)
end

"""
    section4_check_corollaryIV2(; io) -> NamedTuple

Verify Corollary IV.2(ii): F_L = F_M iff M = L or M(x) = L(x) ⊕ x.
Tested on G_1 = x³ over GF(2⁵) with L(x) = x², M(x) = x² ⊕ x.
"""
function section4_check_corollaryIV2(; io::IO = devnull)
    n = 5
    mod = primitive_polynomial(n)

    G1 = gold_lut(n, 1; modulus = mod)

    # L(x) = x²
    L = linear_monomial_lut(n, 1, 1; modulus = mod)
    # M(x) = x² ⊕ x  (= L(x) ⊕ x)
    M = [L[x+1] ⊻ x for x in 0:(1<<n)-1]
    # N(x) = x³ (different from L and L⊕id)
    N_map = linear_monomial_lut(n, 2, 1; modulus = mod)  # x⁴ ≠ x² or x²⊕x

    shift_L = isotopic_shift_lut(G1, L)
    shift_M = isotopic_shift_lut(G1, M)
    shift_N = isotopic_shift_lut(G1, N_map)

    shifts_equal    = shift_L == shift_M
    shifts_unequal  = shift_L != shift_N

    print_section(io, "Section IV — Corollary IV.2(ii)")
    print_check(io, "F_L = F_M when M(x)=L(x)⊕x", shifts_equal)
    print_check(io, "F_L ≠ F_N for unrelated N", shifts_unequal)

    (; shifts_equal, shifts_unequal)
end

function section4_report(io::IO = stdout)
    print_section(io, "Section IV: Isotopic Shifts of APN Functions")
    section4_check_theoremIV1(; io)
    section4_check_corollaryIV2(; io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    section4_report()
end
