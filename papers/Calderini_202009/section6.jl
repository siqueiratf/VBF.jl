# Implements Section 6: On the EA-classes of functions in dimension 7, 8 and 9.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Section: 6 — On the EA-classes of functions in dimension 7, 8 and 9
#
# Pseudocode:
#   1. Theorem 7: for n=5,6, x^{-1} has exactly 2 Walsh-zero n-dim subspaces
#      → CCZ-equiv to x^{-1} iff AE-equiv to x^{-1} (since x^{-1} is an involution)
#   2. Theorem 8: for n=5 non-Gold APN x^{15}, count Walsh-zero subspaces ≤ 2
#      → CCZ-class partitioned into at most 2 EA-classes (F and F^{-1})
#   3. Tables 2/3/4 upper bounds: out of scope (Walsh-zero enumeration too slow for n=7,8,9)
# VBF API used: walsh_zeroes, extract_linear_subspaces, conway_polynomial, gf_pow,
#               differential_uniformity, is_permutation, load_apn_function,
#               are_ccz_equivalent, are_affine_equivalent

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

"""
    theorem7_verify(n; io) -> NamedTuple

Theorem 7: x^{-1} over GF(2^n) has exactly 2 Walsh-zero n-dim subspaces.
Since x^{-1} is an involution (F = F^{-1}), these 2 subspaces represent the same EA-class,
so any function CCZ-equiv to x^{-1} must be EA-equiv to x^{-1}.
"""
function theorem7_verify(n::Int; io::IO = stdout)
    exp = (1 << n) - 2
    F = power_sbox(n, exp)
    is_perm = is_permutation(F)
    du = differential_uniformity(F)

    Z = walsh_zeroes(F)
    subspaces = extract_linear_subspaces(Z, n; max_bits = 2n)
    n_subsp = length(subspaces)

    # x^{-1} is an involution: F(F(x)) = x for all x
    n_size = 1 << n
    is_involution = all(F.lut[F.lut[x + 1] + 1] == x for x = 0:(n_size - 1))

    print_kv(io, "n", n)
    print_kv(io, "exponent d = 2^n - 2", exp)
    print_kv(io, "is permutation", is_perm)
    print_kv(io, "differential uniformity", du)
    print_kv(io, "is involution (F = F^{-1})", is_involution)
    print_kv(io, "#Walsh-zero $n-dim subspaces", n_subsp)
    print_check(io, "Theorem 7: exactly 2 simplex codes → 1 EA-class", n_subsp == 2)
    print_check(io, "x^{-1} is involution → F and F^{-1} are the same function", is_involution)

    return (; n, exp, is_perm, du, n_subsp, is_involution)
end

"""
    theorem8_verify_n5(; io) -> NamedTuple

Theorem 8 for n=5: the Kasami function x^{15} (only non-Gold APN for n=5) has
at most 2 Walsh-zero 5-dim subspaces, bounding EA-classes ≤ 2 in its CCZ-class.
"""
function theorem8_verify_n5(; io::IO = stdout)
    F = load_apn_function("n5_Kasami_x15")
    du = differential_uniformity(F)
    is_perm = is_permutation(F)

    Z = walsh_zeroes(F)
    subspaces = extract_linear_subspaces(Z, 5; max_bits = 10)
    n_subsp = length(subspaces)

    inv_exp = powermod(15, 31 - 2, 31)   # 15^{-1} mod 31

    # Verify 29 is in the same cyclotomic coset as 15 mod 31:
    # coset of 15: {15, 30, 29, 27, 23} — so 29 is linearly equiv to 15 → same EA-class
    coset15 = let c = Int[]; x = 15; for _ in 1:5; push!(c, x); x = (2x) % 31; end; c end
    in_same_coset = inv_exp in coset15

    print_kv(io, "n", 5)
    print_kv(io, "F = x^15 (n5_Kasami_x15)", "")
    print_kv(io, "is APN permutation", is_perm && du == 2)
    print_kv(io, "inverse exponent d^{-1} mod 31", inv_exp)
    print_kv(io, "cyclotomic coset of 15 mod 31", coset15)
    print_check(io, "29 = 15^{-1} is in the same cyclotomic coset as 15", in_same_coset)
    print_kv(io, "#Walsh-zero 5-dim subspaces", n_subsp)
    print_check(io, "Theorem 8: ≤2 Walsh-zero subspaces → ≤2 EA-classes in CCZ-class", n_subsp <= 2)
    println(io, "  Note: since 15^{-1} = 29 is in the same cyclotomic coset as 15,")
    println(io, "  x^15 and x^29 = (x^15)^{-1} are linearly equivalent → 1 EA-class total.")
    println(io, "  Note: are_ccz_equivalent is incomplete for degenerate k=4 partitions")
    println(io, "  (Gold/Kasami), so CCZ-equiv of x^15 and x^29 is verified via coset argument.")

    return (; n_subsp, inv_exp, in_same_coset)
end

"""
    section6_report(io)

Section 6: Theorem 7 (n=5,6), Theorem 8 (n=5), Tables 2/3/4 (out of scope).
"""
function section6_report(io::IO = stdout)
    println(io, "# Calderini (2020) — Section 6: EA-classes in dimension 7, 8, 9")
    println(io, "# Scope: Theorem 7 (exact n=5,6), Theorem 8 (exact n=5)")
    println(io, "# Tables 2/3/4: OUT OF SCOPE (Walsh-zero enumeration too slow for n≥7)")

    print_section(io, "Theorem 7 — CCZ~x^{-1} iff AE~x^{-1} (n=5,6)")
    println(io, "  Proof via simplex code count: x^{-1} has exactly 2 Walsh-zero")
    println(io, "  n-dim subspaces for 5≤n≤9, and it is an involution (F=F^{-1}),")
    println(io, "  so there is only 1 EA-class (not 2 distinct ones).")

    println(io, "\n  n=5:")
    r5 = theorem7_verify(5; io)
    println(io, "\n  n=6:")
    r6 = theorem7_verify(6; io)

    print_section(io, "Theorem 8 — Non-Gold APN power functions have ≤2 EA-classes (n=5)")
    theorem8_verify_n5(; io)
    println(io, "\n  Note: Tables 2 (n=7), 3 (n=8), 4 (n=9) in the paper give upper bounds")
    println(io, "  via code equivalence in MAGMA. Walsh-zero enumeration for n=7 requires")
    println(io, "  several minutes; for n≥8 it is infeasible without specialized software.")
end
