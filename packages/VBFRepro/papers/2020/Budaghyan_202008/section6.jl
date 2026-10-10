# Implements Section VI — Isotopic Shifts of Gold Functions.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: VI — Lemma VI.6 (monomial L), Theorem VI.3 (main APN construction)
#
# Pseudocode:
#   Lemma VI.6:
#     (i)  L(x) = u·x, u ∉ F₂  →  G_{i,L} linearly equivalent to G_i
#     (ii) n odd, L(x) = u·x^{2^i}  →  G_{i,L} APN, linearly equiv to G_{2i}
#     (iv) gcd(j,n)=1, j≠i (n odd)  →  G_{i,L} not APN
#   Theorem VI.3 (n = km, q = 2^m, L an F_q-linear q-polynomial, gcd(i,n)=1):
#     d  = gcd(q−1, (q^k−1)/(q−1))
#     d' = same prime factors as d, each at its multiplicity in (q^k−1)/(q−1)
#     U  = ⟨ζ^{d'(q−1)}⟩,  W = {y·ζ^j : 0 ≤ j < d', y ∈ U},  |W| = (q^k−1)/(q−1)
#     G_{i,L} is APN over F_{q^k}  ⟺
#       (i)   ∀u ∈ W: L(u) ∉ {0, u}
#       (ii)  n even ⟹ |{L(u)/u : u ∈ W} ∩ F₄| ≤ 1
#       (iii) ∀ distinct u,v ∈ W with u^{2^i}L(v) + v·L(u)^{2^i} ≠ 0:
#               (v^{2^i}L(u) + u·L(v)^{2^i}) / (u^{2^i}L(v) + v·L(u)^{2^i}) ∉ F_q*
#     Instance (Section VII-B, n = 9, k = m = 3): [a,b,d] = [ζ^424, ζ, ζ^34],
#     c² + c = d, L(x) = a·x^{2^6} + b·x^{2^3} + c·x, G_{1,L} is the new APN.
# VBF API used: gold_apn, terms_to_lut, gf_mul, gf_pow, gf_inv, in_subfield,
#               are_linear_equivalent, are_ea_equivalent, SBox,
#               differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
using Dates

# ── Field pinning ─────────────────────────────────────────────────────────────

"""
    section6_check_field_pinning(; io) -> NamedTuple

Pin the field the paper's ζ^k exponents live in.  The paper never states a
modulus, so *every* coefficient it quotes (ζ^424, ζ^34, ζ^337, …) is meaningful
only relative to a concrete pair (modulus, ζ).  What makes the reproduction work
is that `primitive_polynomial(9) = 529 = x⁹+x⁴+1` (the Conway/Magma default, and
the modulus recorded for the n=9 catalog entries) with ζ = 2 primitive.

This is not cosmetic: at n = 8 the same convention breaks — `primitive_polynomial(8)`
is 283 (the AES polynomial) and 2 has multiplicative order 51, not 255.  Hence
[`primitive_element`](@ref) searches for ζ instead of assuming 2.
"""
function section6_check_field_pinning(; io::IO = devnull)
    mod9 = primitive_polynomial(9)
    ok_mod = mod9 == 529                                   # x⁹ + x⁴ + 1
    ord2 = multiplicative_order(2, 9; modulus = mod9)
    ok_zeta = ord2 == 511                                  # 2 is primitive
    zeta9 = primitive_element(9; modulus = mod9)
    ok_smallest = zeta9 == 2

    # Counter-example that motivates searching for ζ rather than assuming 2.
    mod8 = primitive_polynomial(8)
    ord2_n8 = multiplicative_order(2, 8; modulus = mod8)
    ok_n8 = ord2_n8 != 255 && multiplicative_order(
        primitive_element(8; modulus = mod8), 8; modulus = mod8) == 255

    print_section(io, "Section VI — field pinning for the paper's ζ^k exponents")
    print_kv(io, "primitive_polynomial(9)", "$mod9 (x⁹+x⁴+1)")
    print_kv(io, "multiplicative order of 2 in GF(2⁹)", ord2)
    print_check(io, "modulus is x⁹+x⁴+1 (529)", ok_mod)
    print_check(io, "ζ = 2 is primitive in GF(2⁹) (order 511)", ok_zeta)
    print_check(io, "smallest primitive element of GF(2⁹) is 2", ok_smallest)
    print_kv(io, "contrast: order of 2 in GF(2⁸), modulus $mod8", ord2_n8)
    print_check(io, "at n=8, 2 is NOT primitive → ζ must be searched", ok_n8)

    (; mod9, ord2, zeta9, ok_mod, ok_zeta, ok_smallest, ord2_n8, ok_n8)
end

# ── Lemma VI.6 ────────────────────────────────────────────────────────────────

"""
    section6_check_lemmaVI6(; io) -> NamedTuple

Verify Lemma VI.6 cases (i), (ii), (iv) for G_1 = x³ over GF(2⁵).
Scope: 3 of the lemma's 5 cases; (iii) and (v) are not implemented.
"""
function section6_check_lemmaVI6(; io::IO = devnull)
    n  = 5
    mod = primitive_polynomial(n)
    G1  = gold_apn(n, 1; modulus = mod).lut
    G2  = gold_apn(n, 2; modulus = mod).lut  # x⁵, APN since gcd(2,5)=1
    F1  = SBox{n}(collect(Int, G1))
    F2  = SBox{n}(collect(Int, G2))

    # Case (i): L(x) = ζ·x, ζ∉F₂  →  G_{1,L} lin-equiv to G_1
    zeta = primitive_element(n; modulus = mod)
    L_scalar = terms_to_lut([(zeta, 1)], n, mod)          # L(x) = ζ·x
    shift_i = SBox{n}(isotopic_shift_lut(G1, L_scalar))
    ok_i = are_linear_equivalent(shift_i, F1)

    # Case (ii): n=5 odd, j=i=1, L(x) = x^{2^1}=x²  →  G_{1,L} EA-equiv to G_2
    # G_{i,L}(x) = u·x^{2^{i+1}} + u^{2^i}·G_{2i}(x), so G_{1,L} = G_2 + linear → EA-equiv
    L_frob = terms_to_lut([(1, 2)], n, mod)               # L(x) = x²
    shift_ii = SBox{n}(isotopic_shift_lut(G1, L_frob))
    ok_ii = are_ea_equivalent(shift_ii, F2)

    # Case (iv): gcd(j,n)=1, j≠i → not APN.  Take j=2, n=5: gcd(2,5)=1, j≠1=i
    L_j2 = terms_to_lut([(1, 4)], n, mod)                 # L(x) = x⁴
    shift_iv = SBox{n}(isotopic_shift_lut(G1, L_j2))
    ok_iv = differential_uniformity(shift_iv) > 2

    print_section(io, "Section VI — Lemma VI.6 (G_1 over GF(2⁵); cases (i),(ii),(iv) of 5)")
    print_check(io, "Case (i):  L(x)=ζ·x  → G_{1,L} ≈_lin G_1", ok_i)
    print_check(io, "Case (ii): L(x)=x²   → G_{1,L} ≈_EA  G_2", ok_ii)
    print_check(io, "Case (iv): L(x)=x⁴, gcd(2,5)=1 → not APN", ok_iv)

    (; ok_i, ok_ii, ok_iv)
end

# ── Theorem VI.3: the conditions (i), (ii), (iii) ─────────────────────────────

"""
    theorem_vi3_setup(n, m; modulus) -> NamedTuple

Build the objects Theorem VI.3 quantifies over: `q = 2^m`, `k = n/m`,
`d = gcd(q−1, S)` with `S = (q^k−1)/(q−1)`, the integer `d'` (same prime factors
as `d`, each raised to its multiplicity in `S`), the subgroup `U = ⟨ζ^{d'(q−1)}⟩`
of order `S/d'`, and `W = {y·ζ^j : 0 ≤ j < d', y ∈ U}`.

By construction `gcd(q−1, S/d') = 1` and `|W| = S`; both are asserted by
[`section6_check_theoremVI3_setup`](@ref).
"""
function theorem_vi3_setup(n::Int, m::Int; modulus::Int = primitive_polynomial(n))
    n % m == 0 || throw(ArgumentError("theorem_vi3_setup: m=$m must divide n=$n"))
    k = n ÷ m
    q = 1 << m
    S = ((1 << n) - 1) ÷ (q - 1)          # (q^k − 1)/(q − 1)
    d = gcd(q - 1, S)

    dprime = 1
    t = d
    p = 2
    while t > 1                            # prime factors of d
        if t % p == 0
            while t % p == 0
                t ÷= p
            end
            e = 0                          # multiplicity of p in S
            s = S
            while s % p == 0
                s ÷= p
                e += 1
            end
            dprime *= p^e
        end
        p += 1
    end

    zeta = primitive_element(n; modulus = modulus)
    gU = gf_pow(zeta, dprime * (q - 1), n; modulus = modulus)
    U = Int[]
    y = 1
    while true
        push!(U, y)
        y = gf_mul(y, gU, n; modulus = modulus)
        y == 1 && break
    end
    W = Int[]
    for j in 0:dprime-1
        zj = gf_pow(zeta, j, n; modulus = modulus)
        for y in U
            push!(W, gf_mul(y, zj, n; modulus = modulus))
        end
    end

    (; n, m, k, q, S, d, dprime, zeta, U, W, modulus)
end

"""
    theorem_vi3_conditions(L_lut, setup, i) -> NamedTuple

Evaluate conditions (i), (ii), (iii) of Theorem VI.3 for the q-polynomial `L`.
`all` is their conjunction — the theorem's right-hand side.
"""
function theorem_vi3_conditions(L_lut::AbstractVector{<:Integer}, setup, i::Int)
    (; n, m, q, W, modulus) = setup
    e = 1 << i

    # (i) for any u ∈ W, L(u) ∉ {0, u}
    cond_i = true
    for u in W
        lu = Int(L_lut[u+1])
        if lu == 0 || lu == u
            cond_i = false
            break
        end
    end

    # (ii) n even ⟹ |{L(u)/u : u ∈ W} ∩ F₄| ≤ 1
    cond_ii = true
    if iseven(n)
        seen = Set{Int}()
        for u in W
            r = gf_mul(
                Int(L_lut[u+1]),
                gf_inv(u, n; modulus = modulus),
                n;
                modulus = modulus,
            )
            in_subfield(r, 2, n; modulus = modulus) && push!(seen, r)
        end
        cond_ii = length(seen) ≤ 1
    end

    # (iii) for distinct u,v ∈ W with denominator ≠ 0, the ratio is not in F_q*
    cond_iii = true
    nw = length(W)
    outer = true
    for ii in 1:nw
        outer || break
        for jj in 1:nw
            ii == jj && continue
            u, v = W[ii], W[jj]
            lu, lv = Int(L_lut[u+1]), Int(L_lut[v+1])
            den = gf_mul(gf_pow(u, e, n; modulus = modulus), lv, n; modulus = modulus) ⊻
                  gf_mul(v, gf_pow(lu, e, n; modulus = modulus), n; modulus = modulus)
            den == 0 && continue
            num = gf_mul(gf_pow(v, e, n; modulus = modulus), lu, n; modulus = modulus) ⊻
                  gf_mul(u, gf_pow(lv, e, n; modulus = modulus), n; modulus = modulus)
            r = gf_mul(num, gf_inv(den, n; modulus = modulus), n; modulus = modulus)
            if r != 0 && in_subfield(r, m, n; modulus = modulus)
                cond_iii = false
                outer = false
                break
            end
        end
    end

    (; cond_i, cond_ii, cond_iii, all = cond_i && cond_ii && cond_iii)
end

"""
    section6_check_theoremVI3_setup(; io) -> NamedTuple

Structural checks on the (d, d', U, W) construction, for every configuration the
iff is tested at.  Pins `gcd(q−1, S/d') = 1`, `|U| = S/d'` and `|W| = S`.
"""
function section6_check_theoremVI3_setup(; io::IO = devnull)
    print_section(io, "Section VI — Theorem VI.3: the sets d, d', U, W")
    rows = NamedTuple[]
    for (n, m) in ((6, 3), (6, 2), (8, 4), (8, 2), (9, 3))
        s = theorem_vi3_setup(n, m)
        ok_coprime = gcd(s.q - 1, s.S ÷ s.dprime) == 1
        ok_U = length(s.U) == s.S ÷ s.dprime
        ok_W = length(s.W) == s.S && length(unique(s.W)) == s.S
        ok = ok_coprime && ok_U && ok_W
        print_check(io,
            "n=$n m=$m k=$(s.k) q=$(s.q): d=$(s.d) d'=$(s.dprime) |U|=$(length(s.U)) " *
            "|W|=$(length(s.W)) = (q^k−1)/(q−1) = $(s.S), ζ=$(s.zeta)", ok)
        push!(rows, (; n, m, k = s.k, q = s.q, d = s.d, dprime = s.dprime,
            nU = length(s.U), nW = length(s.W), S = s.S, zeta = s.zeta, ok))
    end
    (; rows, all_ok = all(r.ok for r in rows))
end

"""
    section6_vi3_coefficient_sets(n, m; nsample, extra) -> Vector{Vector{Int}}

Coefficient vectors (b₀, b₁, …, b_{k−1}) of the q-polynomials
L(x) = Σ bⱼ·x^{q^j} to test the iff on: exhaustive when 2^{nk} is small enough,
otherwise a deterministic pseudo-random sample plus `extra` (used to inject the
paper's own APN parameter sets at n = 9, where the space is 2^27).
"""
function section6_vi3_coefficient_sets(
    n::Int,
    m::Int;
    max_enum::Int = 300_000,
    nsample::Int = 800,
    extra::Vector{Vector{Int}} = Vector{Vector{Int}}(),
)
    N = 1 << n
    k = n ÷ m
    sets = Vector{Vector{Int}}()
    if BigInt(N)^k ≤ max_enum
        cur = zeros(Int, k)
        function rec(pos)
            if pos > k
                push!(sets, copy(cur))
                return
            end
            for a in 0:N-1
                cur[pos] = a
                rec(pos + 1)
            end
        end
        rec(1)
    else
        for idx in 0:nsample-1                       # deterministic LCG sample
            h = idx
            cs = Int[]
            for j in 1:k
                h = (h * 1103515245 + 12345 + j * 7919) % N
                push!(cs, h)
            end
            push!(sets, cs)
        end
    end
    append!(sets, extra)
    sets
end

"""
    section6_check_theoremVI3_iff(; n, m, i, io, ...) -> NamedTuple

Test Theorem VI.3 as an **iff**, in both directions: for every q-polynomial L in
the scan, `G_{i,L}` is APN ⟺ conditions (i)+(ii)+(iii) hold.  `mismatches`
counts either direction failing.

Non-vacuity: the scan must contain both APN and non-APN L, else "0 mismatches"
would be free.  `nonvacuous` reports this.
"""
function section6_check_theoremVI3_iff(;
    n::Int = 6,
    m::Int = 3,
    i::Int = 1,
    io::IO = devnull,
    max_enum::Int = 300_000,
    nsample::Int = 800,
    extra::Vector{Vector{Int}} = Vector{Vector{Int}}(),
)
    gcd(i, n) == 1 || throw(ArgumentError("Theorem VI.3 needs gcd(i,n)=1"))
    s = theorem_vi3_setup(n, m)
    mod = s.modulus
    k = s.k
    N = 1 << n
    G = gold_apn(n, i; modulus = mod).lut
    exps = [s.q^j for j in 0:k-1]

    sets = section6_vi3_coefficient_sets(n, m; max_enum, nsample, extra)
    n_apn = 0
    n_cond = 0
    mismatches = 0
    examples = Vector{Any}()
    for cs in sets
        L = terms_to_lut([(cs[j], exps[j]) for j in 1:k], n, mod)
        F = SBox{n}(isotopic_shift_lut(G, L))
        apn = differential_uniformity(F) == 2
        cond = theorem_vi3_conditions(L, s, i).all
        apn && (n_apn += 1)
        cond && (n_cond += 1)
        if apn != cond
            mismatches += 1
            length(examples) < 3 && push!(examples, (; coeffs = cs, apn, cond))
        end
    end

    tested = length(sets)
    exhaustive = BigInt(N)^k ≤ max_enum
    ok = mismatches == 0
    nonvacuous = n_apn > 0 && n_apn < tested

    print_section(io,
        "Section VI — Theorem VI.3 iff (n=$n, m=$m, k=$k, q=$(s.q), G_$i)")
    print_kv(io, "q-polynomials tested",
        "$tested ($(exhaustive ? "exhaustive" : "sampled from $(BigInt(N)^k)"))")
    print_kv(io, "APN shifts", n_apn)
    print_kv(io, "L satisfying conditions (i)+(ii)+(iii)", n_cond)
    print_kv(io, "mismatches (either direction)", mismatches)
    print_check(io, "G_{i,L} APN ⟺ conditions (i)+(ii)+(iii)", ok)
    print_check(io, "scan is non-vacuous (both APN and non-APN L present)", nonvacuous)
    isempty(examples) || print_kv(io, "mismatch examples", examples)

    (; n, m, k, q = s.q, i, tested, exhaustive, n_apn, n_cond, mismatches, ok,
       nonvacuous, examples)
end

# ── Theorem VI.3: the n=9 instance (Section VII-B) ────────────────────────────

"""
    section6_theorem_vi3_parameters(; modulus) -> NamedTuple

Compute the parameters [a, b, c, d] for Theorem VI.3, n=9, m=3, k=3.
[a, b, d] = [ζ^424, ζ, ζ^34] from Section VII-B of the paper; c satisfies c²+c=d.

ζ is the primitive element of GF(2⁹) under `modulus`; for the default modulus
529 = x⁹+x⁴+1 that is ζ = 2 (asserted by [`section6_check_field_pinning`](@ref)).
Every exponent below is meaningless without that pinning.
"""
function section6_theorem_vi3_parameters(;
    modulus::Int = primitive_polynomial(9),
)
    n   = 9
    zeta = primitive_element(n; modulus = modulus)
    a = gf_pow(zeta, 424, n; modulus = modulus)
    b = gf_pow(zeta,   1, n; modulus = modulus)
    d = gf_pow(zeta,  34, n; modulus = modulus)
    c = find_c_for_d(d, n; modulus = modulus)
    (; n, modulus, zeta, a, b, c, d)
end

"""
    section6_build_theorem_vi3_apn(params) -> SBox{9}

Construct the APN function G_{1,L} from Theorem VI.3 (Section VII-B, n=9).
L(x) = a·x^{2^6} + b·x^{2^3} + c·x over GF(2^9) — an F₈-linear q-polynomial.
"""
function section6_build_theorem_vi3_apn(params = section6_theorem_vi3_parameters())
    (; n, modulus, a, b, c) = params
    G1 = gold_apn(n, 1; modulus = modulus).lut          # x³
    L  = terms_to_lut([(a, 64), (b, 8), (c, 1)], n, modulus)
    SBox{n}(isotopic_shift_lut(G1, L))
end

"""
    section6_table1_row8(; modulus) -> SBox{9}

Table I, entry N.8 written out as the paper's explicit polynomial
ζ³³⁷x¹²⁹ + ζ⁴²⁴x⁶⁶ + ζ²x¹⁷ + ζx¹⁰ + ζ³⁴x³ over GF(2⁹).
"""
function section6_table1_row8(; modulus::Int = primitive_polynomial(9))
    n = 9
    z = primitive_element(n; modulus = modulus)
    ζ(t) = gf_pow(z, t, n; modulus = modulus)
    SBox{n}(
        terms_to_lut(
            [(ζ(337), 129), (ζ(424), 66), (ζ(2), 17), (ζ(1), 10), (ζ(34), 3)],
            n,
            modulus,
        ),
    )
end

"""
    section6_check_theoremVI3(; io) -> NamedTuple

Verify Theorem VI.3 at its headline instance: G_{1,L} with [a,b,d]=[ζ^424,ζ,ζ^34]
is APN over GF(2^9), equals the explicit Table I row-8 polynomial, and satisfies
conditions (i),(ii),(iii).  Also verifies the two other m=3 parameter sets from
Section VII-B.
"""
function section6_check_theoremVI3(; io::IO = devnull)
    mod = primitive_polynomial(9)
    p   = section6_theorem_vi3_parameters(; modulus = mod)
    F   = section6_build_theorem_vi3_apn(p)

    du = differential_uniformity(F)
    is_apn = (du == 2)
    matches_table1 = (F == section6_table1_row8(; modulus = mod))

    # conditions (i),(ii),(iii) on this L
    s = theorem_vi3_setup(9, 3; modulus = mod)
    L = terms_to_lut([(p.a, 64), (p.b, 8), (p.c, 1)], 9, mod)
    conds = theorem_vi3_conditions(L, s, 1)

    # the other two m=3 parameter sets of Section VII-B
    G1 = gold_apn(9, 1; modulus = mod).lut
    others = NamedTuple[]
    for (ea, eb, ed) in ((263, 1, 272), (508, 1, 132))
        a2 = gf_pow(p.zeta, ea, 9; modulus = mod)
        b2 = gf_pow(p.zeta, eb, 9; modulus = mod)
        d2 = gf_pow(p.zeta, ed, 9; modulus = mod)
        c2 = find_c_for_d(d2, 9; modulus = mod)
        L2 = terms_to_lut([(a2, 64), (b2, 8), (c2, 1)], 9, mod)
        F2 = SBox{9}(isotopic_shift_lut(G1, L2))
        push!(others, (; ea, eb, ed, du = differential_uniformity(F2)))
    end
    others_apn = all(o.du == 2 for o in others)

    print_section(io, "Section VI — Theorem VI.3  (n=9, k=m=3, G_1 isotopic shift)")
    print_kv(io, "ζ", p.zeta)
    print_kv(io, "a = ζ^424", "0x$(string(p.a, base=16))")
    print_kv(io, "b = ζ",     "0x$(string(p.b, base=16))")
    print_kv(io, "d = ζ^34",  "0x$(string(p.d, base=16))")
    print_kv(io, "c (c²⊕c=d)","0x$(string(p.c, base=16))")
    print_kv(io, "differential uniformity", du)
    print_check(io, "G_{1,L} is APN (du=2)", is_apn)
    print_check(io, "G_{1,L} == Table I row 8 polynomial (LUT-identical)", matches_table1)
    print_check(io, "L satisfies Theorem VI.3 (i)+(ii)+(iii)", conds.all)
    print_check(io,
        "other Sec. VII-B m=3 sets [ζ^263,ζ,ζ^272], [ζ^508,ζ,ζ^132] are APN too",
        others_apn)

    (; is_apn, du, matches_table1, conds, others, others_apn, F, params = p)
end

function section6_report(io::IO = stdout)
    print_section(io, "Section VI: Isotopic Shifts of Gold Functions")
    section6_check_field_pinning(; io)
    section6_check_lemmaVI6(; io)
    section6_check_theoremVI3_setup(; io)
    section6_check_theoremVI3(; io)
    section6_check_theoremVI3_iff(; n = 6, m = 3, i = 1, io)
    section6_check_theoremVI3_iff(; n = 6, m = 2, i = 1, io)
    section6_check_theoremVI3_iff(; n = 8, m = 4, i = 1, io)
    section6_check_theoremVI3_iff(;
        n = 9, m = 3, i = 1, io, nsample = 800,
        extra = section6_vi3_known_n9_coefficients(),
    )
end

"""
    section6_vi3_known_n9_coefficients(; modulus) -> Vector{Vector{Int}}

The three m=3 parameter sets the paper reports in Section VII-B, as q-polynomial
coefficient vectors (c, b, a) for L(x) = c·x + b·x^8 + a·x^64.  Injected into the
n=9 iff scan so that it contains APN positives (the space is 2^27; a blind sample
would almost surely contain none).
"""
function section6_vi3_known_n9_coefficients(; modulus::Int = primitive_polynomial(9))
    z = primitive_element(9; modulus = modulus)
    ζ(t) = gf_pow(z, t, 9; modulus = modulus)
    [
        [find_c_for_d(ζ(34), 9; modulus = modulus), ζ(1), ζ(424)],
        [find_c_for_d(ζ(272), 9; modulus = modulus), ζ(1), ζ(263)],
        [find_c_for_d(ζ(132), 9; modulus = modulus), ζ(1), ζ(508)],
    ]
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    section6_report()
end
