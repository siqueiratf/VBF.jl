# Implements Theorem 3.3 — the new APN family F₄.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: 3.1 — Family F₄ (Table 2.1, last row)
#
#   Theorem 3.3. Let B ∈ M^× ∖ C_M and a ∈ K^× with B^{q+r} ≠ a^{q+1}, and let
#       F(x,y) = ((1,0,0,B)_q, (0,1,a/B,0)_r)
#              = (x^{q+1} + B y^{q+1},  x^r y + (a/B) x y^r)
#   where q = 2^k, m ≡ 2 (mod 4), gcd(k,m) = 1 and r = qQ. Then F is APN.
#
# Pseudocode:
#   1. Enumerate every admissible (k, B, a) on M (Table 2.1's Notes column).
#   2. Certify APN with the Lemma 2.1 kernel criterion — O(2^m · m³).
#   3. Cross-certify a sample with the ground-truth differential_uniformity on
#      the full 2ⁿ LUT (feasible only up to n = 12).
#   4. NEGATIVE CONTROLS: break each hypothesis separately —
#        (a) B a cube;
#        (b) B^{q+r} = a^{q+1}
#      and confirm the function stops being APN. Without these, "F₄ is APN"
#      would be untestable in the falsifiable direction.
#
# Smallest instance: m ≡ 2 (mod 4) and m > 2 forces m = 6, i.e. n = 12.
# (m = 2 admits no F₄ at all: there B^{q+r} = a^{q+1} = 1 always.)
#
# VBF API used: SBox, differential_uniformity, algebraic_degree, is_permutation,
#               gf_is_dth_power, in_subfield, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""
    f4_condition_violations(fld, k) -> NamedTuple

Parameter pairs that break exactly one hypothesis of Theorem 3.3:

* `cube_B`   — `(B, a)` with `B` a **cube** (all other conditions intact);
* `norm_eq`  — `(B, a)` with `B` a non-cube but `B^{q+r} = a^{q+1}`.

These are the negative controls; both are expected to destroy APN-ness.
"""
function f4_condition_violations(fld::BiField, k::Integer)
    l = k + fld.m ÷ 2
    cube_B = NTuple{2,Int}[]
    norm_eq = NTuple{2,Int}[]
    for a in kstar(fld)
        for B in cubes(fld)
            push!(cube_B, (B, a))
        end
        for B in noncubes(fld)
            Bqr = gmul(fld, frob(fld, B, k), frob(fld, B, l))
            aq1 = gmul(fld, frob(fld, a, k), a)
            Bqr == aq1 && push!(norm_eq, (B, a))
        end
    end
    (; cube_B = cube_B, norm_eq = norm_eq)
end

"""
    theorem3_3_report(io = stdout; m = 6, ddt_sample = 4, full_search = false,
                      save_results = false) -> NamedTuple

Verify Theorem 3.3. Default `m = 6` (n = 12) is exhaustive over all admissible
`(k, B, a)`. `full_search = true` additionally certifies one instance at
`m = 10` (n = 20) and `m = 14` (n = 28) via the Lemma 2.1 criterion — dimensions
where a DDT (2⁴⁰ / 2⁵⁶ cells) is out of reach.
"""
function theorem3_3_report(
    io::IO = stdout;
    m::Int = 6,
    ddt_sample::Int = 4,
    full_search::Bool = false,
    save_results::Bool = false,
)
    print_section("Theorem 3.3 — the new biprojective APN family F₄", io)
    fld = BiField(m)
    n = 2m
    params = f4_parameters(fld)

    print_kv("m (needs m ≡ 2 mod 4, m > 2 ⇒ smallest is 6)", m, io)
    print_kv("n = 2m", n, io)
    print_kv("modulus of M", string(fld.modulus, base = 2), io)
    print_kv("non-cubes in M^×", length(noncubes(fld)), io)
    print_kv("K^× = F_{2^{m/2}}^×", length(kstar(fld)), io)
    print_kv("admissible (k, B, a) triples", length(params), io)

    # ── (1) Lemma 2.1 criterion on every admissible triple ──────────────────
    not_apn = String[]
    for (k, B, a) in params
        F = family_f4(fld, k, B, a)
        biprojective_is_apn(F) || push!(not_apn, F.name)
    end
    print_check(
        "all $(length(params)) admissible F₄ instances are APN (Lemma 2.1 criterion)",
        isempty(not_apn),
        io,
    )
    for s in not_apn
        println(io, "    [FAIL] not APN: ", s)
    end

    # ── (2) ground-truth DDT cross-check on a sample ────────────────────────
    ddt_ok = true
    quad_ok = true
    sample = params[1:min(ddt_sample, length(params))]
    for (k, B, a) in sample
        S = bipair_sbox(family_f4(fld, k, B, a))
        differential_uniformity(S) == 2 || (ddt_ok = false)
        algebraic_degree(S) == 2 || (quad_ok = false)
    end
    print_check(
        "differential_uniformity == 2 on the full 2^$n LUT ($(length(sample)) sampled)",
        ddt_ok,
        io,
    )
    print_check("algebraic degree == 2 (quadratic, as Theorem 4.2 requires)", quad_ok, io)

    # ── (3) negative controls: each hypothesis is necessary ─────────────────
    v = f4_condition_violations(fld, 1)
    cube_broken = 0
    for (B, a) in v.cube_B[1:min(6, length(v.cube_B))]
        biprojective_is_apn(family_f4(fld, 1, B, a)) || (cube_broken += 1)
    end
    norm_broken = 0
    for (B, a) in v.norm_eq[1:min(6, length(v.norm_eq))]
        biprojective_is_apn(family_f4(fld, 1, B, a)) || (norm_broken += 1)
    end
    n_cube = min(6, length(v.cube_B))
    n_norm = min(6, length(v.norm_eq))
    print_check(
        "negative control: B a cube ⇒ NOT APN ($cube_broken/$n_cube)",
        cube_broken == n_cube && n_cube > 0,
        io,
    )
    print_check(
        "negative control: B^{q+r} = a^{q+1} ⇒ NOT APN ($norm_broken/$n_norm)",
        norm_broken == n_norm && n_norm > 0,
        io,
    )
    if n_norm > 0
        B, a = v.norm_eq[1]
        S = bipair_sbox(family_f4(fld, 1, B, a))
        print_kv(
            "  e.g. B=$B, a=$a: differential_uniformity",
            differential_uniformity(S),
            io,
        )
    end
    print_kv("completeness", "exhaustive over all admissible (k,B,a) at m=$m", io)

    # ── (4) opt-in: large dimensions via the Lemma 2.1 criterion ────────────
    large = NamedTuple[]
    if full_search
        for mm in (10, 14)
            fl = BiField(mm)
            ps = f4_parameters(fl)
            isempty(ps) && continue
            k, B, a = first(ps)
            t = @elapsed ok = biprojective_is_apn(family_f4(fl, k, B, a))
            print_check(
                "F₄ APN at m=$mm (n=$(2mm)), k=$k B=$B a=$a — Lemma 2.1 criterion only " *
                "($(round(t, digits = 2))s; a 2^$(2mm) × 2^$(2mm) DDT is infeasible)",
                ok,
                io,
            )
            push!(large, (; m = mm, n = 2mm, k, B, a, apn = ok, admissible = length(ps)))
        end
    else
        println(io, "  [SKIP] m = 10, 14 (n = 20, 28) — enable with full_search=true")
    end

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem3_3_m$(m).txt"), "w") do fh
            println(fh, "# F4 admissible parameters, m=$m, modulus=$(fld.modulus)")
            println(fh, "# k B a")
            for (k, B, a) in params
                println(fh, "$k $B $a")
            end
        end
    end

    (;
        m = m,
        n = n,
        admissible = length(params),
        not_apn = not_apn,
        ddt_ok = ddt_ok,
        quadratic = quad_ok,
        cube_negative = (cube_broken, n_cube),
        norm_negative = (norm_broken, n_norm),
        large_dims = large,
        all_ok = isempty(not_apn) &&
                 ddt_ok &&
                 quad_ok &&
                 cube_broken == n_cube > 0 &&
                 norm_broken == n_norm > 0,
    )
end
