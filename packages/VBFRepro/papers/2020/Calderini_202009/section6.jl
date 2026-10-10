# Implements Section 6: On the EA-classes of functions in dimension 7, 8 and 9.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Section: 6 — On the EA-classes of functions in dimension 7, 8 and 9
#
# Pseudocode:
#   1. Theorem 7 (5 ≤ n ≤ 9): x^{-1} has exactly 2 Walsh-zero n-dim subspaces
#      and is an involution → its CCZ-class is a single EA-class, and
#      CCZ-equivalence to x^{-1} coincides with affine equivalence.
#      Verified exactly for n = 5, 6, 7 (and n = 8, 9 in the report; n = 8 has
#      du = 4 — the paper extends the computation to this case explicitly).
#   1b. Theorem 8 (n=5..9), coset-arithmetic half over ALL APN power classes:
#      enumerate the cyclotomic classes of APN exponents, pair each with its
#      inverse class (x^d ≃CCZ x^{d⁻¹}), drop the classes containing a Gold
#      function, and derive the EA-class count (2 = F, F⁻¹; 1 when F⁻¹ is
#      cyclotomically equivalent to F or does not exist). Reproduces Remarks
#      5-7 / Tables 2-4 for every non-Gold class. The "≤2" (simplex-count) half
#      is exact only for n=5 and the x^{-1}-linked classes (Theorem 7).
#   2. Remark 5 (n=7): x^13 has 2 EA-classes (13^{-1} = 88 ∉ coset(13));
#      x^57, x^63 have 1 (cyclotomically equivalent to their inverses).
#      The 2-simplex-code count is verified for x^63 (≃ x^126 = x^{-1}, same
#      cyclotomic coset ⟹ linearly equivalent). For the AB monomials x^13 and
#      x^57 the Walsh-zero set has ~2^13 points and subspace enumeration
#      exceeded 30 minutes (measured); their simplex counts stay MAGMA-only.
#   3. Remark 6 (n=8): x^127 ≃ x^254 = x^{-1} (same coset): 2 simplex codes,
#      1 EA-class (involution). x^57: single-simplex-code claim is MAGMA-only —
#      enumeration over |Z| = 16575 measured at > 30 min (opt-in flag).
#   4. Remark 7 (n=9): coset arithmetic for x^13, x^19, x^241 (2 classes each,
#      inverse exponent in a different coset) and x^255 ≃ x^510 = x^{-1}.
#   5. Tables 2/3/4 full upper-bound columns: out of scope (AB Walsh-zero
#      subspace enumeration for n ≥ 7 measured at > 30 min per function;
#      the paper computed them with MAGMA code equivalence).
# VBF API used: walsh_zeroes, extract_linear_subspaces, conway_polynomial,
#               gf_monomial_lut, differential_uniformity, is_permutation,
#               load_apn_function

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

"""
    theorem7_verify(n; io) -> NamedTuple

Theorem 7: x^{-1} over GF(2ⁿ) has exactly 2 Walsh-zero n-dim subspaces.
Since x^{-1} is an involution these represent a single EA-class, so any
permutation CCZ-equivalent to x^{-1} is affine-equivalent to it.
"""
function theorem7_verify(n::Int; io::IO = stdout)
    exp = (1 << n) - 2
    F = power_sbox(n, exp)
    is_perm = is_permutation(F)
    du = differential_uniformity(F)

    Z = walsh_zeroes(F)
    subspaces = extract_linear_subspaces(Z, n; max_bits = 2n)
    n_subsp = length(subspaces)

    n_size = 1 << n
    is_involution = all(F.lut[F.lut[x + 1] + 1] == x for x = 0:(n_size - 1))

    print_kv(io, "n", n)
    print_kv(io, "exponent d = 2ⁿ-2", exp)
    print_kv(io, "is permutation", is_perm)
    print_kv(io, "differential uniformity", du)
    print_kv(io, "is involution (F = F⁻¹)", is_involution)
    print_kv(io, "#Walsh-zero $n-dim subspaces", n_subsp)
    print_check(io, "Theorem 7: exactly 2 simplex codes → 1 EA-class", n_subsp == 2)
    print_check(io, "x^{-1} is an involution → the 2 spaces give the same class", is_involution)

    return (; n, exp, is_perm, du, n_subsp, is_involution)
end

"""
    coset_class_count(d, n) -> NamedTuple

Remarks 5-7 arithmetic: for a monomial permutation x^d over GF(2ⁿ), the
CCZ-class of a non-Gold APN power function splits into the EA-classes of F and
F⁻¹ (Theorem 8); these coincide iff d⁻¹ mod 2ⁿ-1 lies in the cyclotomic coset
of d (cyclotomic equivalence ⟹ affine equivalence).
Returns `(; d, inv_exp, coset, same)` — `same == true` ⟹ 1 EA-class, else 2.
"""
function coset_class_count(d::Int, n::Int)
    m = (1 << n) - 1
    gcd(d, m) == 1 || throw(ArgumentError("x^$d is not a permutation of GF(2^$n)"))
    inv_exp = invmod(d, m)
    coset = cyclotomic_coset(d, m)
    return (; d, inv_exp, coset, same = inv_exp in coset)
end

"""
    theorem8_verify_n5(; io) -> NamedTuple

Theorem 8 for n=5, exact: x^15 — the only APN power CCZ-class over GF(2⁵) with
no Gold member (see `theorem8_census`; the catalog name `n5_Kasami_x15` is a
misnomer, the Kasami exponent at n=5 is 13 ∈ coset(11), whose class *is* Gold's
because 11⁻¹ = 17 ∈ coset(3)) — has exactly 2 Walsh-zero 5-dim subspaces, and
15⁻¹ = 29 lies in the cyclotomic coset of 15, so the CCZ-class is a single
EA-class. Note 15·2 = 30 = 2⁵-2, so x^15 is linearly equivalent to x^{-1}:
at n=5 Theorem 8's only non-Gold instance coincides with Theorem 7's.
"""
function theorem8_verify_n5(; io::IO = stdout)
    F = load_apn_function("n5_Kasami_x15")
    du = differential_uniformity(F)
    is_perm = is_permutation(F)

    Z = walsh_zeroes(F)
    n_subsp = length(extract_linear_subspaces(Z, 5; max_bits = 10))

    r = coset_class_count(15, 5)

    print_kv(io, "n", 5)
    print_kv(io, "F = x^15 (n5_Kasami_x15)", "")
    print_kv(io, "is APN permutation", is_perm && du == 2)
    print_kv(io, "inverse exponent 15⁻¹ mod 31", r.inv_exp)
    print_kv(io, "cyclotomic coset of 15 mod 31", r.coset)
    print_check(io, "29 = 15⁻¹ is in the same cyclotomic coset as 15", r.same)
    print_kv(io, "#Walsh-zero 5-dim subspaces", n_subsp)
    print_check(io, "Theorem 8: ≤2 Walsh-zero subspaces → ≤2 EA-classes", n_subsp <= 2)
    println(io, "  15⁻¹ = 29 in the coset of 15 ⟹ x^15 ≃linear (x^15)⁻¹ ⟹ 1 EA-class.")

    return (; n_subsp, inv_exp = r.inv_exp, in_same_coset = r.same)
end

"""
    is_gold_exponent(d, n) -> Bool

`true` iff some element of the cyclotomic coset of `d` mod 2ⁿ-1 is a Gold
exponent 2ⁱ+1 with gcd(i, n) = 1 (i.e. x^d is linearly equivalent to a Gold
APN function).
"""
function is_gold_exponent(d::Int, n::Int)
    m = (1 << n) - 1
    c = cyclotomic_coset(d, m)
    return any(mod((1 << i) + 1, m) in c for i = 1:(n - 1) if gcd(i, n) == 1)
end

"""
    apn_power_ccz_classes(n) -> Vector{NamedTuple}

CCZ-classes of the APN power functions over GF(2ⁿ), one entry per class.

Cyclotomic classes of exponents (x^d ≃linear x^e iff e ∈ coset(d)) are paired
with their inverse class (x^d and x^{d⁻¹} are CCZ-equivalent, being
compositional inverses), so each entry is one CCZ-class. Fields:

- `rep`, `inv_rep` — coset minima of d and d⁻¹ (`inv_rep == rep` iff x^d is
  cyclotomically equivalent to its inverse; `-1` if x^d is not a permutation);
- `gold` — the class contains a Gold function (either `rep`'s or `inv_rep`'s
  coset holds a Gold exponent). Theorem 8 speaks about the `!gold` classes;
- `ea_classes` — Theorem 8's prediction for the non-Gold classes: 2 (F and
  F⁻¹) unless F⁻¹ is cyclotomically equivalent to F (or does not exist), in
  which case 1.
"""
function apn_power_ccz_classes(n::Int)
    m = (1 << n) - 1
    seen = Set{Int}()
    out = NamedTuple[]
    for d = 2:(m - 1)
        d in seen && continue
        c = cyclotomic_coset(d, m)
        union!(seen, c)
        differential_uniformity(power_sbox(n, d)) == 2 || continue
        rep = minimum(c)
        is_perm = gcd(rep, m) == 1
        inv_rep = is_perm ? minimum(cyclotomic_coset(invmod(rep, m), m)) : -1
        # Pair the class with its inverse class: report each CCZ-class once.
        is_perm && inv_rep < rep && continue
        gold = is_gold_exponent(rep, n) || (is_perm && is_gold_exponent(inv_rep, n))
        ea_classes = (!is_perm || inv_rep == rep) ? 1 : 2
        push!(out, (; rep, inv_rep, is_perm, gold, ea_classes))
    end
    return out
end

# Paper's EA-class counts for the non-Gold APN power classes (Remarks 5-7 and
# Tables 2/3/4): class representative (coset minimum) => paper's # EA-classes.
# n=7: x^13 (coset min 11), x^57 (coset min 23), x^63 (inverse).
# n=8: x^57 (coset min 39, not a permutation).
# n=9: x^13, x^19, x^241 (coset min 47), x^255 (inverse).
# The x^57 (n=7) entry is the paper's *claimed* 1 — arithmetically false
# (57⁻¹ = 78 ∉ coset(57)); see remark5_verify and the README's P1.
const PAPER_NONGOLD_EA_COUNTS = Dict(
    5 => Dict(15 => 1),
    6 => Dict{Int,Int}(),
    7 => Dict(11 => 2, 23 => 1, 63 => 1),
    8 => Dict(39 => 1),
    9 => Dict(13 => 2, 19 => 2, 47 => 2, 255 => 1),
)
const PAPER_X57_N7_CLASS = 23   # coset minimum of 57 mod 127

"""
    theorem8_census(n; io) -> NamedTuple

Theorem 8 for 5 ≤ n ≤ 9, coset-arithmetic half, over **all** APN power CCZ
classes (not just the paper's hand-picked representatives): enumerate every
cyclotomic class of APN exponents, pair each with its inverse class, drop the
classes containing a Gold function, and derive the EA-class count of each
remaining class (2 = F and F⁻¹, or 1 when F⁻¹ is cyclotomically equivalent to
F or does not exist).

The counts are compared with the paper's Remarks 5-7 / Tables 2-4. The one
disagreement is the known paper error on x^57 (n=7) — see `remark5_verify`.

The *upper* half of Theorem 8 ("at most 2", i.e. exactly 2 simplex codes) is
verified exactly only where the Walsh-zero subspace enumeration is affordable:
n=5 (`theorem8_verify_n5`) and the classes linearly equivalent to x^{-1}
(x^63 at n=7, x^255 at n=9 — `theorem7_verify`). The AB classes (x^13, x^57 at
n=7; x^13, x^19, x^241 at n=9) and x^57 at n=8 have |Z| ≈ 2^13..2^14 and were
measured at > 30 min each: they stay MAGMA-only.
"""
function theorem8_census(n::Int; io::IO = stdout)
    classes = apn_power_ccz_classes(n)
    non_gold = filter(c -> !c.gold, classes)
    expect = PAPER_NONGOLD_EA_COUNTS[n]
    print_kv(io, "APN power CCZ-classes over GF(2^$n)", length(classes))
    for c in classes
        inv_s = c.is_perm ? "x^$(c.inv_rep)" : "not a permutation"
        tag = c.gold ? "Gold class" : "non-Gold ⇒ Theorem 8: $(c.ea_classes) EA-class(es)"
        println(io, "  x^$(c.rep) | inverse: $inv_s | $tag")
    end
    ok = true
    for c in non_gold
        paper = get(expect, c.rep, nothing)
        if paper === nothing
            print_check(io, "x^$(c.rep): non-Gold class listed by the paper", false)
            ok = false
        elseif n == 7 && c.rep == PAPER_X57_N7_CLASS
            # P1: paper claims 1 EA-class for x^57 via a false cyclotomic claim.
            print_check(
                io,
                "x^57 (class x^23): computed $(c.ea_classes) EA-classes, paper claims " *
                "$paper — known paper error (57⁻¹ = 78 ∉ coset(57))",
                c.ea_classes == 2,
            )
            ok &= c.ea_classes == 2
        else
            print_check(
                io,
                "x^$(c.rep): $(c.ea_classes) EA-class(es) — matches the paper ($paper)",
                c.ea_classes == paper,
            )
            ok &= c.ea_classes == paper
        end
    end
    n_listed = length(expect)
    print_check(io, "All $(length(non_gold)) non-Gold classes accounted for (paper lists $n_listed)",
        length(non_gold) == n_listed)
    ok &= length(non_gold) == n_listed
    return (; n, classes, non_gold, ok)
end

"""
    theorem8_gold_inverse_check(; io) -> Bool

Substantiates the reading of "non-Gold" used by `theorem8_census`: a power
class whose *inverse* exponent is Gold lies in the Gold CCZ-class (x^d and
x^{d⁻¹} are compositional inverses, hence CCZ-equivalent). Decided exactly at
n=5, where `are_ccz_equivalent` is cheap: x^11 (Kasami x^13's coset, 11⁻¹ = 17
∈ coset(3)) is CCZ-equivalent to Gold x^3, while x^15 (the genuinely non-Gold
class) is not.
"""
function theorem8_gold_inverse_check(; io::IO = stdout)
    G3 = power_sbox(5, 3)
    a = are_ccz_equivalent(power_sbox(5, 11), G3)
    b = are_ccz_equivalent(power_sbox(5, 15), G3)
    print_check(io, "n=5: x^11 (11⁻¹ = 17 ∈ coset(3)) is CCZ-equivalent to Gold x^3", a)
    print_check(io, "n=5: x^15 (the non-Gold class) is NOT CCZ-equivalent to Gold x^3", !b)
    return a && !b
end

"""
    remark5_verify(; io, check_x57_ae::Bool = false) -> Bool

Remark 5 (n=7): x^13 has 2 EA-classes (13⁻¹ = 88 in a different coset) and
x^63 has 1 (coset contains 125 = 63⁻¹; also 126 = 2·63, so x^63 ≃ x^{-1}).

DISCREPANCY (x^57): the paper claims x^57 is "cyclotomically equivalent (and
thus affine equivalent) to its inverse", giving a single EA-class. Computed:
57⁻¹ mod 127 = 78, and 78 ∉ coset(57) = {57,114,101,75,23,46,92} — the
cyclotomic claim is arithmetically false. With `check_x57_ae = true` (~10 s)
the complete affine-equivalence decision confirms x^57 ≁AE x^78 (control:
AE(x^63, x^125) = true), so the paper's justification fails; by the paper's
own x^13 argument the class would split into the EA-classes of F and F⁻¹.
WE(C₂) of the two codes is equal, so EA-equivalence-with-drift is not ruled
out at the invariant level; settling the exact count (1 vs 2) needs MAGMA
code equivalence. Table 2's "≤ 2" bound is unaffected.
"""
function remark5_verify(; io::IO = stdout, check_x57_ae::Bool = false)
    ok = true

    r13 = coset_class_count(13, 7)
    print_kv(io, "x^13: 13⁻¹ mod 127", r13.inv_exp)
    print_check(io, "x^13: inverse in a different coset → 2 EA-classes (Remark 5)", !r13.same)
    ok &= !r13.same

    r63 = coset_class_count(63, 7)
    print_kv(io, "x^63: 63⁻¹ mod 127", r63.inv_exp)
    print_check(io, "x^63: coset contains its inverse → 1 EA-class (Remark 5)", r63.same)
    inv_in = 126 in r63.coset
    print_check(io, "x^63 ≃ x^126 = x^{-1} (126 ∈ coset of 63)", inv_in)
    println(io, "  ⇒ x^63's simplex-code count equals x^{-1}'s (= 2, Theorem 7 n=7).")
    ok &= r63.same && inv_in

    r57 = coset_class_count(57, 7)
    print_kv(io, "x^57: 57⁻¹ mod 127", r57.inv_exp)
    print_kv(io, "x^57: cyclotomic coset", r57.coset)
    print_check(
        io,
        "DISCREPANCY: paper's cyclotomic claim for x^57 is false (78 ∉ coset)",
        !r57.same,
    )
    ok &= !r57.same
    if check_x57_ae
        F57 = power_sbox(7, 57)
        F78 = power_sbox(7, 78)
        not_ae = !are_affine_equivalent(F57, F78)
        ctrl = are_affine_equivalent(power_sbox(7, 63), power_sbox(7, 125))
        print_check(io, "x^57 NOT affine-equivalent to x^78 (complete AE decision)", not_ae)
        print_check(io, "control: x^63 AE x^125 (coset-mates)", ctrl)
        we_eq = code_weight_enumerator(ea_matrix(F57)) == code_weight_enumerator(ea_matrix(F78))
        print_check(io, "WE(C₂(x^57)) == WE(C₂(x^78)) (EA undecided at invariant level)", we_eq)
        ok &= not_ae && ctrl && we_eq
    end
    println(io, "  x^57's exact EA-class count (paper: 1; paper's own x^13 argument")
    println(io, "  applied to the computed cosets: 2) needs MAGMA code equivalence.")
    println(io, "  x^13, x^57 are AB: |Z| ≈ 2^13, subspace enumeration measured > 30 min —")
    println(io, "  their 2-simplex-code counts remain MAGMA-only (Table 2 likewise).")
    return ok
end

"""
    remark6_verify(; io, check_x57::Bool = false) -> Bool

Remark 6 (n=8): x^127 ≃ x^254 = x^{-1} (2 simplex codes, involution → 1
EA-class; verified via Theorem 7 n=8 in the report). With
`check_x57 = true` also counts x^57's simplex codes (paper: exactly 1);
measured cost: |Z| = 16575 and the subspace enumeration did NOT finish
within 30 minutes — beyond the reproduction budget, off by default
(the claim stays MAGMA-only).
"""
function remark6_verify(; io::IO = stdout, check_x57::Bool = false)
    coset127 = cyclotomic_coset(127, 255)
    ok = 254 in coset127
    print_check(io, "x^127 ≃ x^254 = x^{-1} over GF(2⁸) (254 ∈ coset of 127)", ok)
    println(io, "  ⇒ 2 simplex codes and 1 EA-class from Theorem 7 (n=8, du=4 case).")
    println(io, "  x^57 is not a permutation of GF(2⁸) (gcd(57,255)=3); paper: exactly")
    println(io, "  one simplex code ⇒ one EA-class. Enumeration over |Z| = 16575 did not")
    println(io, "  finish within 30 min (measured) — MAGMA-only unless check_x57 = true.")
    # Theorem-8 half that IS affordable: x^57 is not a permutation over GF(2⁸),
    # so its CCZ-class has no F⁻¹ member and Theorem 8 gives a single EA-class —
    # the same value (1) the paper obtains from its single simplex code.
    x57_perm = gcd(57, 255) == 1
    cls = filter(c -> !c.gold, apn_power_ccz_classes(8))
    thm8_x57 = length(cls) == 1 && cls[1].rep == 39 && cls[1].ea_classes == 1
    print_check(io, "x^57 (n=8) is not a permutation (gcd(57,255) = 3)", !x57_perm)
    print_check(io, "Theorem 8 ⇒ 1 EA-class for x^57 (n=8) — the paper's Table 3 value", thm8_x57)
    ok &= !x57_perm && thm8_x57
    if check_x57
        F = power_sbox(8, 57)
        Z = walsh_zeroes(F)
        n_subsp = length(extract_linear_subspaces(Z, 8; max_bits = 16))
        print_check(io, "x^57 (n=8): exactly 1 simplex code (Remark 6)", n_subsp == 1)
        ok &= n_subsp == 1
    end
    return ok
end

"""
    remark7_verify(; io) -> Bool

Remark 7 (n=9): x^13, x^19, x^241 have 2 EA-classes each (inverse exponent in
a different cyclotomic coset); x^255 ≃ x^510 = x^{-1} has 1 (involution).
"""
function remark7_verify(; io::IO = stdout)
    ok = true
    for d in (13, 19, 241)
        r = coset_class_count(d, 9)
        print_kv(io, "x^$d: d⁻¹ mod 511", r.inv_exp)
        print_check(io, "x^$d: inverse in a different coset → 2 EA-classes", !r.same)
        ok &= !r.same
    end
    coset255 = cyclotomic_coset(255, 511)
    inv_in = 510 in coset255
    print_check(io, "x^255 ≃ x^510 = x^{-1} (1 EA-class, involution)", inv_in)
    ok &= inv_in
    return ok
end

"""
    section6_report(io)

Section 6: Theorem 7 (n=5..9), Theorem 8 (n=5 exact), Remarks 5-7,
Tables 2/3/4 upper-bound columns out of scope (measured cost notes).
"""
function section6_report(io::IO = stdout)
    println(io, "# Calderini (2020) — Section 6: EA-classes in dimension 7, 8, 9")
    println(io, "# Scope: Theorem 7 exact n=5..9; Theorem 8 exact n=5; Remarks 5-7 via")
    println(io, "#        cyclotomic cosets + inverse-function simplex counts.")
    println(io, "# Tables 2/3/4 upper-bound columns: MAGMA-only (AB subspace enumeration")
    println(io, "# for n ≥ 7 measured at > 30 min per function; see remark5_verify).")

    print_section(io, "Theorem 7 — CCZ~x^{-1} iff AE~x^{-1} (5 ≤ n ≤ 9)")
    println(io, "  (n=9 subspace enumeration takes ~4 minutes; n≤8 are seconds)")
    for n = 5:9
        println(io, "\n  n=$n:")
        theorem7_verify(n; io)
    end

    print_section(io, "Theorem 8 — non-Gold APN power functions, ≤2 EA-classes (n=5 exact)")
    theorem8_verify_n5(; io)

    print_section(io, "Theorem 8 — census of all APN power CCZ-classes, n=5..9")
    println(io, "  Coset arithmetic (exact) for every APN power class; the \"≤2\" half is")
    println(io, "  exact only for n=5 and the x^{-1}-linked classes (Theorem 7) — the AB")
    println(io, "  classes' simplex counts stay MAGMA-only (measured > 30 min each).")
    theorem8_gold_inverse_check(; io)
    for n = 5:9
        println(io, "\n  n=$n:")
        theorem8_census(n; io)
    end

    print_section(io, "Remark 5 (n=7) — x^13, x^57, x^63 (x^57: discrepancy found)")
    remark5_verify(; io, check_x57_ae = true)

    print_section(io, "Remark 6 (n=8) — x^57 and the inverse function")
    remark6_verify(; io, check_x57 = false)

    print_section(io, "Remark 7 (n=9) — x^13, x^19, x^241, x^255")
    remark7_verify(; io)
end