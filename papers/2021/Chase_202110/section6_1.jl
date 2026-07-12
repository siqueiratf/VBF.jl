# Implements Section 6.1 — the 64 WZ spaces of x^3 on F_{2^5} and the three
# EA classes inside its CCZ class ([Canteaut-Perrin, Lemma 12] made
# computer-free by the paper).
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 6.1 — Classifying EA classes of functions
#
# Pseudocode:
#   f = x^3 on F_{2^5}:
#     1. Enumerate all 5-dim subspaces of Z(f)  →  expect 64.
#     2. 32 of them: Prop 4.3 with m = n = 5 (31 spaces for μ ∈ F^*) plus
#        the trivial Z_0b — the thickness-5 (permutation-type) half.
#     3. 32 of them: Prop 4.1 with S = μF_2 (31 spaces for μ ∈ F^*) plus
#        the trivial Z_a0 (μ = 0) — the thickness-≤1 half.
#     4. Three EA classes (CP framework, verified computationally):
#        a. ≥ 3: the twists by Z_a0, Z_0b and an X × S space have pairwise
#           distinct EA invariants (algebraic degree, thickness spectrum).
#        b. ≤ 3: every EA class is a twist by some WZ space (CP Thm 4);
#           the 64 spaces fall into 4 orbits under the graph automorphism
#           (a, b) ↦ (u·a, u^{2^i+1}·b) — {Z_a0}, {Z_0b}, the 31 Prop-4.3
#           spaces, the 31 X × S spaces. Scaled bases give the IDENTICAL
#           twist (checked), completion changes give explicit (α, β) drift
#           certificates (checked), and the Prop-4.3 orbit merges with Z_0b
#           via affine equivalence to x^{1/3} (checked), Z_a0's twist merges
#           with f via the reliable ortho-derivative EA test (checked).
#        Classes: f (deg 2), x^{1/3} (deg 3), and a non-permutation class
#        (deg 3, thickness spectrum without n).
# VBF API used: gold_apn, walsh_zeroes, extract_linear_subspaces,
#   span_from_basis, thickness, thickness_spectrum, linear_basis,
#   complete_basis, are_ea_equivalent, are_affine_equivalent,
#   compositional_inverse, algebraic_degree, differential_uniformity,
#   is_permutation, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition4_1.jl"))
include(joinpath(@__DIR__, "proposition4_3.jl"))

"""
    section6_1_build(; modulus, drift_samples, seed) -> NamedTuple

Full reproduction of Section 6.1 (n = 5, i = 1, f = x^3).
"""
function section6_1_build(;
    modulus::Int = primitive_polynomial(5),
    drift_samples::Int = 3,
    seed::Int = 2021,
)
    n, i = 5, 1
    F = gold_apn(n, i; modulus)
    Finv = compositional_inverse(F)
    dual = gold_dual_table(n, i; modulus)
    tm = trace_mask_table(n; modulus)

    # --- 1-3. The 64 spaces and their 32 + 32 computer-free description. ---
    bases = extract_linear_subspaces(walsh_zeroes(F), n; max_bits = 2 * n)
    enumerated = Set{Vector{UInt32}}(sort(span_from_basis(b)) for b in bases)
    perm_half = Set{Vector{UInt32}}(
        to_mask_coords(proposition4_3_span(n, mu, n, i; modulus), tm, n) for
        mu = 1:(1<<n)-1
    )
    push!(perm_half, to_mask_coords(z_0b_span(n), tm, n))
    xs_half = Set{Vector{UInt32}}(
        to_mask_coords(
            proposition4_1_span([0, mu], n, i; modulus, dual, tm),
            tm,
            n,
        ) for mu = 1:(1<<n)-1
    )
    push!(xs_half, to_mask_coords(z_a0_span(n), tm, n))
    covered = union(perm_half, xs_half) == enumerated
    thick = [thickness(b, n) for b in bases]
    n_thick_full = count(==(n), thick)

    # --- 4. EA classification via orbit twists. ---
    fb(s) = linear_basis(s; nbits = 2 * n)
    v43 = proposition4_3_span(n, 1, n, i; modulus)
    vxs = proposition4_1_span([0, 1], n, i; modulus, dual, tm)
    b_za0 = fb(z_a0_span(n))
    b_z0b = fb(z_0b_span(n))
    b_43 = fb(v43)
    b_xs = fb(vxs)
    w_xs = setdiff(complete_basis(copy(b_xs), 2 * n), b_xs)

    g_f = twist_from_field_bases(F, b_za0, b_z0b, tm)
    g_inv = twist_from_field_bases(F, b_z0b, b_za0, tm)
    g_43 = twist_from_field_bases(F, b_43, b_za0, tm)
    g_xs = twist_from_field_bases(F, b_xs, w_xs, tm)

    # Orbits of the scaling action: sizes and twist-constancy (scaled bases
    # give the identical function — the scaling is a graph automorphism).
    orbit43 = Set(scale_span(u, v43, n, i; modulus) for u = 1:(1<<n)-1)
    orbitxs = Set(scale_span(u, vxs, n, i; modulus) for u = 1:(1<<n)-1)
    fixed_trivial =
        all(scale_span(u, z_a0_span(n), n, i; modulus) == z_a0_span(n) for u = 1:(1<<n)-1) &&
        all(scale_span(u, z_0b_span(n), n, i; modulus) == z_0b_span(n) for u = 1:(1<<n)-1)
    scale_b(u, bs) = UInt32[scale_pair(u, p, n, i; modulus) for p in bs]
    twists_constant = all(1:(1<<n)-1) do u
        twist_from_field_bases(F, scale_b(u, b_43), scale_b(u, b_za0), tm) == g_43 &&
        twist_from_field_bases(F, scale_b(u, b_xs), scale_b(u, w_xs), tm) == g_xs
    end
    orbits_cover =
        Set(to_mask_coords(s, tm, n) for s in orbit43) ∪
        Set([to_mask_coords(z_0b_span(n), tm, n)]) == perm_half &&
        Set(to_mask_coords(s, tm, n) for s in orbitxs) ∪
        Set([to_mask_coords(z_a0_span(n), tm, n)]) == xs_half

    # Completion independence: explicit (α, β) drift certificates against
    # `drift_samples` random alternative completions per orbit representative.
    rng = MersenneTwister(seed)
    drift_ok = true
    for (bS, bT, g) in
        ((b_za0, b_z0b, g_f), (b_z0b, b_za0, g_inv), (b_43, b_za0, g_43), (b_xs, w_xs, g_xs))
        for _ = 1:drift_samples
            bT2 = UInt32[]
            while length(bT2) < n
                c = UInt32(rand(rng, 0:(1<<(2 * n))-1))
                cand = UInt32[bS; bT2; c]
                rank_f2(cand; nbits = 2 * n) == length(cand) && push!(bT2, c)
            end
            g2 = twist_from_field_bases(F, bS, bT2, tm)
            drift_ok &= completion_drift_certificate(bS, bT, bT2, g, g2, tm)
        end
    end

    # Lower bound: three pairwise-distinct EA invariant keys.
    key(g) = (algebraic_degree(g), thickness_spectrum(g))
    keys3 = [key(g_f), key(g_inv), key(g_xs)]
    lower_bound_3 = length(unique(keys3)) == 3 && key(g_43) == key(g_inv)

    # Upper bound merges.
    merge_quad = are_ea_equivalent(g_f, F)                 # ortho-derivative route
    merge_inv = are_affine_equivalent(g_inv, Finv)
    merge_43 = are_affine_equivalent(g_43, Finv)
    n_ea_classes =
        (lower_bound_3 && merge_quad && merge_inv && merge_43 && twists_constant &&
         orbits_cover && fixed_trivial && drift_ok) ? 3 : -1

    (;
        n_enumerated = length(enumerated),
        n_perm_half = length(perm_half),
        n_xs_half = length(xs_half),
        disjoint = isempty(intersect(perm_half, xs_half)),
        covered,
        n_thick_full,
        orbit43_size = length(orbit43),
        orbitxs_size = length(orbitxs),
        orbits_cover,
        fixed_trivial,
        twists_constant,
        drift_ok,
        lower_bound_3,
        merge_quad,
        merge_inv,
        merge_43,
        n_ea_classes,
        class_degrees = sort([algebraic_degree(g_f), algebraic_degree(g_inv), algebraic_degree(g_xs)]),
        xs_nonpermutation = !is_permutation(g_xs) && differential_uniformity(g_xs) == 2,
    )
end

function section6_1_report(io::IO = stdout)
    r = section6_1_build()
    print_section("Section 6.1 — WZ spaces of x^3 on F_{2^5}, EA classes", io)
    print_check(io, "exactly 64 WZ spaces found ($(r.n_enumerated))", r.n_enumerated == 64)
    print_check(io, "32 = Prop 4.3(m=n) ∪ {Z_0b} (got $(r.n_perm_half))", r.n_perm_half == 32)
    print_check(io, "32 = Prop 4.1(S=μF_2) ∪ {Z_a0} (got $(r.n_xs_half))", r.n_xs_half == 32)
    print_check(io, "the two halves are disjoint and cover all 64", r.disjoint && r.covered)
    print_check(io, "32 spaces have thickness n (permutation-type)", r.n_thick_full == 32)
    print_check(
        io,
        "scaling orbits: {Z_a0}, {Z_0b}, 31 Prop-4.3, 31 X×S",
        r.orbit43_size == 31 && r.orbitxs_size == 31 && r.orbits_cover && r.fixed_trivial,
    )
    print_check(io, "scaled bases give identical twists (orbit ⟹ same EA class)", r.twists_constant)
    print_check(io, "completion changes: explicit (α, β) drift certificates", r.drift_ok)
    print_check(io, "≥ 3 classes: three distinct (degree, thickness spectrum) keys", r.lower_bound_3)
    print_check(
        io,
        "≤ 3 classes: Z_a0-twist ~EA f; Z_0b- and 4.3-twists affine ~ x^{1/3}",
        r.merge_quad && r.merge_inv && r.merge_43,
    )
    print_check(io, "CCZ class of x^3 has exactly 3 EA classes", r.n_ea_classes == 3)
    print_check(io, "third class: APN non-permutation of degree 3", r.xs_nonpermutation)
    print_kv(io, "EA class representative degrees", r.class_degrees)
    print_kv(io, "upper bound framework", "CP Theorem 4 (every EA class is a WZ-space twist)")
    print_kv(io, "completeness", "exhaustive (full WZ-space enumeration at n = 5)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section6_1_report()
end
