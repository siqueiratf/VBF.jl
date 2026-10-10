# Implements Theorem B.3 — Carlet functions (m even) are EA-equivalent to Zhou–Pott.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: Appendix B — The Carlet family C
#
#   Theorem B.3. Let m be even. All Carlet functions on F are EA-equivalent to a
#   Zhou–Pott function.
#   Proof. C = (xy, (1,β,γ,δ)_q). For any c₁,c₂,c₃,c₄,
#       f(c₁x+c₂y, c₃x+c₄y) = c₁c₃x² + (c₁c₄+c₂c₃)xy + c₂c₄y² = N₁(x)+N₂(y)+d₁xy.
#   By Lemma B.2 pick M ∈ GL(2,M) with g(c₁x+c₂y, c₃x+c₄y) = d₂·(1,0,0,u)_q for a
#   non-cube u. Then L ∘ C ∘ M + N is a Zhou–Pott function with
#       L = diag(m_{1/d₁}, m_{1/d₂}),  N = (N₁ N₂; 0 0).
#
# Pseudocode:
#   1. Fix a Carlet function C = (xy, (1,β,γ,δ)_q) on M = F_{2^m}, m even.
#   2. Search GL(2,M) (projectively — scaling c only rescales d₁,d₂) for M with
#      g ∘ M ∝ (1,0,0,u)_q, u a non-cube. Lemma B.2's transitivity guarantees one.
#   3. Build L and N as above and CHECK POINTWISE that L ∘ C ∘ M + N equals the
#      Zhou–Pott function ZP(q, r=q, u) — the EA-equivalence, verified as an
#      identity on all 2ⁿ points, not merely asserted.
#   4. Confirm the result really is a Zhou–Pott function (admissible d = u) and
#      that C and it have equal mugshots (necessary for EA-equivalence).
#   5. NEGATIVE CONTROL: m ODD. Theorem B.3 is stated only for even m, and the
#      Remark B.4 discussion says the odd case does not reduce this way. Check
#      that for m odd no non-cube exists at all (x ↦ x³ is a bijection), so the
#      target (1,0,0,u)_q with u a non-cube does not exist — the theorem's
#      hypothesis is genuinely used.
#
# TWO BOOKKEEPING POINTS the paper glosses over (neither affects the result):
#
#  (a) j = 0.  The construction turns C into (xy, (1,0,0,u)_q). Written in Table
#      2.1's Zhou–Pott form ((1,0,0,d)_q, (0,0,1,0)_r) that is r = 2⁰ = 1, i.e.
#      j = 0 — but Table 2.1's Zhou–Pott note demands 0 < j < m. So the target of
#      Theorem B.3 lies outside the j-range Table 2.1 states for the family.
#      (Lemma A.1 does speak of "a Zhou–Pott function with j ≠ 0", which confirms
#      j = 0 members are contemplated elsewhere in the paper.) The j = 0
#      admissibility condition degenerates to `d ≠ a^{q+1}`, i.e. exactly "d is a
#      non-cube" — which is what the construction delivers, so the target IS APN.
#
#  (b) coordinate order.  (xy, (1,0,0,u)_q) is the Zhou–Pott pair with its two
#      OUTPUT coordinates swapped. Swapping outputs is an F₂-linear permutation of
#      the codomain, hence an EA-equivalence, so the theorem stands; we make the
#      swap explicit below rather than silently absorbing it.
#
# VBF API used: apn_ea_mugshot, algebraic_degree, differential_uniformity,
#               gf_is_dth_power, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem4_8.jl"))

using VBF

"""
    carlet_to_zhou_pott(C) -> NamedTuple | nothing

Find `M = (c₁ c₂; c₃ c₄) ∈ GL(2,M)` and scalars `d₁, d₂` witnessing Theorem B.3:
`g ∘ M = d₂ · (1, 0, 0, u)_q` for a non-cube `u`, with `d₁ = det(M)`.
"""
function carlet_to_zhou_pott(C::BiPair)
    fld = C.fld
    N = order(fld)
    ncs = Set(noncubes(fld))
    for c1 = 0:(N-1), c2 = 0:(N-1), c3 = 0:(N-1), c4 = 0:(N-1)
        cs = (c1, c2, c3, c4)
        idx = findfirst(!=(0), cs)                    # projective normalisation
        idx === nothing && continue
        cs[idx] == 1 || continue
        d1 = gmul(fld, c1, c4) ⊻ gmul(fld, c2, c3)    # det(M) — see the proof
        d1 == 0 && continue
        gc = biproj_compose(fld, C.g, c1, c2, c3, c4)
        A, Bc, Cc, D = gc.c
        (A != 0 && Bc == 0 && Cc == 0 && D != 0) || continue
        u = gdiv(fld, D, A)                           # g∘M = A·(1,0,0,u)_q
        u in ncs || continue
        return (; c1, c2, c3, c4, d1 = d1, d2 = A, u = u)
    end
    nothing
end

"""
    theoremB_3_report(io = stdout; m = 4) -> NamedTuple
"""
function theoremB_3_report(io::IO = stdout; m::Int = 4)
    print_section("Theorem B.3 — Carlet (m even) is EA-equivalent to Zhou–Pott", io)
    iseven(m) || error("theoremB_3_report: the theorem is stated for even m")
    fld = BiField(m)
    N = order(fld)

    print_kv("m (even)", m, io)
    print_kv("non-cubes in M^× (needed for the ZP target)", length(noncubes(fld)), io)

    results = NamedTuple[]
    all_ok = true
    tested = 0
    for k = 1:(m-1)
        gcd(k, m) == 1 || continue
        for d = 0:(N-1)
            carlet_valid(fld, k, 0, 1, d) || continue
            C = carlet(fld, k, 0, 1, d)
            w = carlet_to_zhou_pott(C)
            if w === nothing
                all_ok = false
                println(io, "    [FAIL] no ZP target found for ", C.name)
                break
            end
            # Table-2.1-shaped Zhou–Pott target: ((1,0,0,u)_q, (0,0,1,0)_{r=2⁰}).
            # Note j = 0 — see point (a) in the file header.
            ZP = zhou_pott(fld, k, 0, w.u)

            # L ∘ C ∘ M + N = ZP with its two OUTPUT coordinates swapped
            # (point (b) in the header), checked pointwise on all 2ⁿ inputs.
            M = BlockMap(
                MonoMap(w.c1, 0),
                MonoMap(w.c2, 0),
                MonoMap(w.c3, 0),
                MonoMap(w.c4, 0),
            )
            Ninv1 = gmul(fld, w.c1, w.c3)              # N₁(x) = c₁c₃x²
            Ninv2 = gmul(fld, w.c2, w.c4)              # N₂(y) = c₂c₄y²
            ok = true
            for x = 0:(N-1), y = 0:(N-1)
                mx, my = block_apply(fld, M, x, y)
                f1, f2 = bipair_eval(C, mx, my)
                # L = diag(m_{1/d₁}, m_{1/d₂}); N cancels the x², y² terms of f₁
                lhs1 = gdiv(
                    fld,
                    f1 ⊻ gmul(fld, Ninv1, gmul(fld, x, x)) ⊻ gmul(fld, Ninv2, gmul(fld, y, y)),
                    w.d1,
                )
                lhs2 = gdiv(fld, f2, w.d2)
                zf, zg = bipair_eval(ZP, x, y)
                # output-coordinate swap: (lhs1, lhs2) ↔ (ZP.g, ZP.f)
                (lhs1 == zg && lhs2 == zf) || (ok = false; break)
            end
            ok || (all_ok = false)
            # j = 0 admissibility degenerates to "u is a non-cube"
            zp_admissible = !gf_is_dth_power(w.u, 3, m; modulus = fld.modulus)
            zp_apn = biprojective_is_apn(ZP)
            mug_eq = zp_apn && mugshot_of(C) == mugshot_of(ZP)
            (zp_admissible && mug_eq && zp_apn) || (all_ok = false)
            push!(
                results,
                (; k, d, u = w.u, identity_ok = ok, zp_admissible, zp_apn, mugshot_equal = mug_eq),
            )
            tested += 1
            break                                       # one d per k is enough
        end
    end

    print_kv("Carlet instances converted", tested, io)
    print_check(
        "L ∘ C ∘ M + N = (Zhou–Pott, outputs swapped) pointwise on all 2^$(2m) inputs",
        all(r -> r.identity_ok, results),
        io,
    )
    print_check(
        "the target is an admissible Zhou–Pott function (j = 0 ⇒ 'u is a non-cube')",
        all(r -> r.zp_admissible, results),
        io,
    )
    print_check("the target is APN", all(r -> r.zp_apn, results), io)
    print_check("mugshots agree (necessary for EA-equivalence)", all(r -> r.mugshot_equal, results), io)
    for r in results
        print_kv("  k=$(r.k), Carlet d=$(r.d)", "→ ZP(q=2^$(r.k), r=2^0, d=$(r.u)), u a non-cube", io)
    end
    println(
        io,
        "  [NOTE] the target has j = 0, outside Table 2.1's stated range 0 < j < m for",
    )
    println(
        io,
        "         Zhou–Pott; Lemma A.1 ('Zhou–Pott with j ≠ 0') shows j = 0 members are",
    )
    println(io, "         contemplated elsewhere in the paper. See the file header.")

    # ── negative control: m odd has no non-cubes at all ─────────────────────
    fld5 = BiField(5)
    nc5 = noncubes(fld5)
    print_check(
        "negative control: for m odd (m=5) M^× has NO non-cube ($(length(nc5)) found), " *
        "so the (1,0,0,u)_q target does not exist and Theorem B.3's even-m hypothesis is essential",
        isempty(nc5),
        io,
    )
    print_kv("completeness", "one Carlet instance per admissible k at m=$m", io)

    (;
        m = m,
        tested = tested,
        results = results,
        noncubes_m_odd = length(nc5),
        all_ok = all_ok && tested > 0 && isempty(nc5),
    )
end
