# Implements Lemma 4.5 — Z^{(q,r)} ≤ Aut_EL(F) for every biprojective pair.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: 4.1 — The group theoretic framework
#
#   Lemma 4.5. Let F = (f₁(x,y), f₂(x,y)) be a (q,r)-biprojective polynomial
#   pair. Then Z_P^{(q,r)} ≤ Z^{(q,r)} ≤ Aut_EL(F), where
#       Z^{(q,r)} = { diag(m_a, m_a, m_{a^{q+1}}, m_{a^{r+1}}) : a ∈ M^× }.
#
# Pseudocode:
#   1. The lemma's calculation is the pointwise identity
#        F(a x, a y) = (a^{q+1} f(x,y), a^{r+1} g(x,y)).
#      Verify it for every a ∈ M^× and every (x,y) ∈ M × M.
#   2. |Z^{(q,r)}| = 2^m − 1 and it is cyclic — check the orbit of a primitive
#      element has full length.
#   3. NEGATIVE CONTROLS (else the check would be vacuous):
#        (a) the same F with a WRONG exponent pair (q, r') — the group element
#            diag(m_a, m_a, m_{a^{q+1}}, m_{a^{r'+1}}) must NOT stabilise Γ_F;
#        (b) a non-biprojective perturbation F + (x², 0) — a genuinely
#            bihomogeneous-degree-breaking term — must lose the automorphism.
#
# VBF API used: gf_mul/gf_pow (via helpers), print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""
    z_qr_order(F) -> Int

Order of the cyclic group `Z^{(q,r)}` realised as automorphisms — the number of
distinct `a ∈ M^×` giving a graph automorphism (should be `2^m − 1`).
"""
z_qr_order(F::BiPair) = count(a -> z_qr_is_automorphism(F, a), mstar(F.fld))

"""
    perturbed_pair(F) -> BiPair

`F` with `x²` added to the first component. `x²` is F₂-**linear**, so the sum
is still a quadratic function on `M × M`, but it is no longer bihomogeneous of
bidegree `q+1`: this is exactly the structure Lemma 4.5 relies on.
Implemented as the `(1,0,0,0)_0` biprojective added to `f` — representable only
because we build a *new* pair whose first component is evaluated as
`f(x,y) ⊕ x²`, so we wrap it as a closure-free `BiPair` on a perturbed field
evaluation below.
"""
struct PerturbedPair
    F::BiPair
end

"""`F(x,y) + (x², 0)` — the non-biprojective negative control."""
function perturbed_eval(P::PerturbedPair, x::Integer, y::Integer)
    fld = P.F.fld
    f1, f2 = bipair_eval(P.F, x, y)
    (f1 ⊻ gmul(fld, x, x), f2)
end

"""Does `diag(m_a, m_a, m_{a^{q+1}}, m_{a^{r+1}})` stabilise the graph of `F + (x²,0)`?"""
function perturbed_z_is_automorphism(P::PerturbedPair, a::Integer)
    F = P.F
    fld = F.fld
    aq1 = gmul(fld, frob(fld, a, kexp(F)), a)
    ar1 = gmul(fld, frob(fld, a, lexp(F)), a)
    for x = 0:(order(fld)-1), y = 0:(order(fld)-1)
        f1, f2 = perturbed_eval(P, x, y)
        g1, g2 = perturbed_eval(P, gmul(fld, a, x), gmul(fld, a, y))
        (g1 == gmul(fld, aq1, f1) && g2 == gmul(fld, ar1, f2)) || return false
    end
    true
end

"""
    lemma4_5_corpus(m) -> Vector{BiPair}

One admissible instance of every Table 2.1 family that exists on `M = F_{2^m}`.
"""
function lemma4_5_corpus(m::Integer)
    fld = BiField(m)
    N = order(fld)
    out = BiPair[]
    for k = 1:(m-1)
        gcd(k, m) == 1 || continue
        if isodd(m)
            push!(out, gold_odd(fld, k))
        else
            a = findfirst(x -> gf_trace(x, m; modulus = fld.modulus) == 1, 0:(N-1))
            a === nothing || push!(out, gold_even(fld, k, a - 1))
        end
        d = findfirst(x -> taniguchi_valid(fld, k, x), 0:(N-1))
        d === nothing || push!(out, taniguchi(fld, k, d - 1))
        dc = findfirst(x -> carlet_valid(fld, k, 0, 1, x), 0:(N-1))
        dc === nothing || push!(out, carlet(fld, k, 0, 1, dc - 1))
        if iseven(m)
            for j = 1:(m-1)
                ex = zhou_pott_excluded_d(fld, k, j)
                dz = findfirst(x -> x != 0 && !(x in ex), 0:(N-1))
                dz === nothing || push!(out, zhou_pott(fld, k, j, dz - 1))
            end
        end
        f1_valid(fld, k) && push!(out, family_f1(fld, k))
        f2_valid(fld, k) && push!(out, family_f2(fld, k))
    end
    ps = f4_parameters(fld)
    isempty(ps) || push!(out, family_f4(fld, ps[1]...))
    out
end

"""
    lemma4_5_report(io = stdout; m_values = (3, 4, 5, 6)) -> NamedTuple

Verify `Z^{(q,r)} ≤ Aut_EL(F)` on every Table 2.1 family instance, together with
the two negative controls.
"""
function lemma4_5_report(io::IO = stdout; m_values = (3, 4, 5, 6))
    print_section("Lemma 4.5 — Z^{(q,r)} ≤ Aut_EL(F)", io)
    total = 0
    ok_all = true
    order_ok = true
    for m in m_values
        fld = BiField(m)
        for F in lemma4_5_corpus(m)
            total += 1
            all(a -> z_qr_is_automorphism(F, a), mstar(fld)) || (ok_all = false;
            println(io, "    [FAIL] ", F.name))
            z_qr_order(F) == order(fld) - 1 || (order_ok = false)
        end
    end
    print_kv("m values", join(m_values, ", "), io)
    print_kv("biprojective pairs checked", total, io)
    print_check("F(ax, ay) = (a^{q+1} f, a^{r+1} g) for every a ∈ M^×", ok_all, io)
    print_check("|Z^{(q,r)}| = 2^m − 1 (cyclic, full order)", order_ok, io)

    # ── negative control (a): wrong exponent in the group element ───────────
    fld = BiField(5)
    F = family_f1(fld, 1)                       # (q, r) = (2, 4)
    wrong = [a for a in mstar(fld) if z_qr_is_automorphism(F, a; ll = lexp(F) + 1)]
    print_check(
        "negative control: diag(…, m_{a^{r'+1}}) with r' ≠ r is NOT an automorphism " *
        "(only $(length(wrong))/$(order(fld) - 1) of the a survive; the identity a=1 is expected)",
        length(wrong) < order(fld) - 1,
        io,
    )

    # ── negative control (b): a non-biprojective perturbation ───────────────
    P = PerturbedPair(F)
    surv = [a for a in mstar(fld) if perturbed_z_is_automorphism(P, a)]
    print_check(
        "negative control: F + (x², 0) is not stabilised by Z^{(q,r)} " *
        "($(length(surv))/$(order(fld) - 1) survive)",
        length(surv) < order(fld) - 1,
        io,
    )
    print_kv("completeness", "exhaustive over a ∈ M^× and (x,y) ∈ M × M", io)

    (;
        checked = total,
        automorphism_ok = ok_all,
        order_ok = order_ok,
        wrong_exponent_survivors = length(wrong),
        perturbed_survivors = length(surv),
        all_ok = ok_all &&
                 order_ok &&
                 length(wrong) < order(fld) - 1 &&
                 length(surv) < order(fld) - 1,
    )
end
