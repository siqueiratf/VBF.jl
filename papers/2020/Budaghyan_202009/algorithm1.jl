# Implements Algorithm 1 (Section IV.A — Filtering Out Shift Candidates)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.A — The Case of Fixed u₁,...,uₖ: Filtering Out Shift Candidates
#
# Pseudocode (Algorithm 1):
#   For each i in [K]:
#     D_i ← F₂ⁿ
#     A ← {D_a^{u_i}F(x) ⊕ F(u_i) : a≠0, a⊕u_i∉U, x∉U∪(a+U)}
#     D_i ← D_i \ A
#   If G is APN then v_i ∈ D_i for every i.
#
# Section IV-A also gives three worked examples (example_a/b/c below).
# VBF API used: SBox, differential_uniformity, gold_apn, span_from_basis,
#               gf_pow, gf_mul, gf_monomial_lut, are_ccz_equivalent

include(joinpath(@__DIR__, "helpers.jl"))

"""
    algorithm1_filter(F, U) -> Vector{Int}

Algorithm 1: for each i ∈ [K], compute the domain D_i ⊆ F₂ⁿ of allowed shift values.
Returns the sizes |D_i| (one per point in U).
Also returns the forbidden sets A_i.
"""
function algorithm1_filter(F::SBox{N,T}, U::AbstractVector{<:Integer}) where {N,T}
    n = 1 << N
    lut = F.lut
    U = collect(Int, U)
    K = length(U)
    U_set = Set(U)

    domain_sizes = Int[]
    forbidden_sets = [Set{Int}() for _ = 1:K]

    for (i, ui) in enumerate(U)
        Fi_ui = Int(lut[ui+1])  # F(u_i)
        forbidden = forbidden_sets[i]

        for a = 1:(n-1)
            a ⊻ ui ∈ U_set && continue  # require a+u_i ∉ U
            Fab = Int(lut[(a ⊻ ui)+1])  # F(a ⊕ u_i) for shifted derivative
            aU = Set(u ⊻ a for u in U)

            for x = 0:(n-1)
                (x ∈ U_set || x ∈ aU) && continue  # x ∉ U ∪ (a+U)
                # D_a^{u_i}F(x) = F(x) ⊕ F(x⊕a) ⊕ F(a⊕u_i)
                val = Int(lut[x+1]) ⊻ Int(lut[(x ⊻ a)+1]) ⊻ Fab
                # forbidden value for v_i: D_a^{u_i}F(x) ⊕ F(u_i)
                push!(forbidden, val ⊻ Fi_ui)
            end
        end

        push!(domain_sizes, n - length(forbidden))
    end
    domain_sizes, forbidden_sets
end

"""
    algorithm1_domains(F, U; drop_zero=true) -> Vector{Vector{Int}}

The domains `D_i` themselves (Algorithm 1 returns `D_i = F₂ⁿ \\ A_i`), one sorted
vector per point of `U`.

`drop_zero = true` removes `v = 0` from every domain. Algorithm 1 as printed never
filters `0` out — but `v_i = 0` means "do not change `u_i`", and Corollary 1 (and
hence the whole shift search) assumes `v_i ≠ 0`. Dropping it is what makes the
paper's Section IV-A domains read literally: Example (b)'s domain is the singleton
`{α²⁵}`, not `{0, α²⁵}`.
"""
function algorithm1_domains(
    F::SBox{N,T},
    U::AbstractVector{<:Integer};
    drop_zero::Bool = true,
) where {N,T}
    n = 1 << N
    _, forbidden_sets = algorithm1_filter(F, U)
    [sort([v for v = 0:(n-1) if v ∉ fs && !(drop_zero && v == 0)]) for fs in forbidden_sets]
end

"""
    example_a(; io) -> NamedTuple

Section IV-A, first example: `F(x) = x³` over `F₂⁵` with
`U = {αⁱ : i ∈ {0} ∪ [5]} = {α⁰, α¹, …, α⁵}`. Algorithm 1 empties every domain,
so **no** choice of shifts `(v₁, …, v₆)` can make `G` APN — the paper's headline
case (0.14 s of filtering replacing an estimated 75 h of exhaustive search).

Robust: this holds for all 30 primitive α of GF(2⁵).
"""
function example_a(; io::IO = stdout)
    n = 5
    mod = primitive_polynomial(n)
    α = 2                       # the class of x; primitive for the default modulus
    F = gold_apn(n, 1)
    U = [gf_pow(α, i, n; modulus = mod) for i = 0:5]

    print_section("Section IV-A, Example (a) — U = {α⁰,…,α⁵} over F₂⁵: no APN G", io)
    print_kv("α (primitive)", "$α  (is_primitive_element: $(is_primitive_element(α, n)))", io)
    print_kv("U", U, io)

    D = algorithm1_domains(F, U)
    for (i, d) in enumerate(D)
        print_kv("  D_$i \\ {0}", isempty(d) ? "∅" : string(d), io)
    end
    empty_all = all(isempty, D)
    print_check("every domain is empty ⇒ no APN G by shifting U (paper: \"no values at all are left\")",
        empty_all, io)

    (; all_ok = empty_all, U, domains = D)
end

"""
    example_b(; io) -> NamedTuple

Section IV-A, second example: `F(x) = x³` over `F₂⁵` with `U = ⟨1, α, α²⟩ = {0,…,7}`.
Filtering leaves the **singleton** domain `{α²⁵}` for every `v_i`; shifting all
eight points by `α²⁵` gives an APN `G` at distance 8 which is CCZ-equivalent to `x⁵`.

β-sensitivity (cf. P3): only 5 of the 30 primitive elements of GF(2⁵) reproduce
this; the repo default α = 2 is one of them, and is the one the paper's α denotes
(the class of x modulo the defining polynomial).
"""
function example_b(; io::IO = stdout, check_ccz::Bool = true)
    n = 5
    mod = primitive_polynomial(n)
    α = 2
    F = gold_apn(n, 1)
    U = Int.(span_from_basis(UInt32[1, α, gf_pow(α, 2, n; modulus = mod)]))
    sort!(U)

    print_section("Section IV-A, Example (b) — U = ⟨1,α,α²⟩ over F₂⁵: singleton domain", io)
    print_kv("U (= {0,…,7})", U, io)

    D = algorithm1_domains(F, U)
    α25 = gf_pow(α, 25, n; modulus = mod)
    singleton = all(d == [α25] for d in D)
    print_kv("D_i \\ {0} (all i)", first(D), io)
    print_check("every domain is the singleton {α²⁵} = {$α25}", singleton, io)

    G = apply_modifications(F, U, fill(α25, length(U)))
    apn = differential_uniformity(G) == 2
    d = hamming_distance(F, G)
    print_check("G (all 8 points shifted by α²⁵) is APN", apn, io)
    print_check("d(x³, G) = 8", d == 8, io)

    ccz = true
    if check_ccz
        x5 = SBox{n}(gf_monomial_lut(n, 5))
        ccz = are_ccz_equivalent(G, x5)
        print_check("G is CCZ-equivalent to x⁵ (paper's claim; catalog class n5_Gold_x5)", ccz, io)
    end

    # Uniform shifts: α²⁵ is the *only* one that works, matching the singleton domain.
    apn_shifts = [v for v = 1:((1 << n) - 1)
                  if differential_uniformity(apply_modifications(F, U, fill(v, length(U)))) == 2]
    only_one = apn_shifts == [α25]
    print_check("α²⁵ is the only uniform shift of U giving an APN G", only_one, io)

    all_ok = singleton && apn && d == 8 && ccz && only_one
    (; all_ok, U, v = α25, distance = d, domains = D)
end

"""
    example_c(; io, β) -> NamedTuple

Section IV-A, third example: `F(x) = x³` over `F₂⁶` with `U = ⟨1, β, β⁴, β²¹⟩`
(16 points). Filtering leaves `D = {β⁷, β¹⁴, β²⁸, β³⁵, β⁴⁹, β⁵⁶}` for every `v_i`;
any *uniform* choice `v₁ = ⋯ = v₁₆ = v ∈ D` yields an APN `G` (at distance 16),
CCZ-equivalent to `x⁶ + x⁹ + β⁷x⁴⁸`, while any mixed choice does not.

**Paper issue P3 / R2 — β must be pinned.** The example is stated for an arbitrary
"β primitive in F₂ⁿ", but it only reproduces for **18 of the 36** primitive elements
of GF(2⁶); the repo's implicit default β = 2 is one of the 18 that *fail*
(it yields `D_i = {0}` for all i, i.e. Algorithm 1 rules out any APN G).
We therefore pin `β = 7`, the smallest primitive element that reproduces the
paper. Note it is the *subspace* `U` that is β-sensitive, not the coefficient:
`x⁶ + x⁹ + c·x⁴⁸` is APN for exactly `c ∈ {6, 11, 20, 26, 28, 31}`, and β⁷ = 6
already at β = 2.
"""
function example_c(; io::IO = stdout, β::Int = 7, check_ccz::Bool = true)
    n = 6
    mod = primitive_polynomial(n)
    F = gold_apn(n, 1)
    prim = is_primitive_element(β, n)

    powβ(e) = gf_pow(β, e, n; modulus = mod)
    U = Int.(span_from_basis(UInt32[1, β, powβ(4), powβ(21)]))
    sort!(U)
    D_expected = sort([powβ(e) for e in (7, 14, 28, 35, 49, 56)])

    print_section("Section IV-A, Example (c) — U = ⟨1,β,β⁴,β²¹⟩ over F₂⁶ (β pinned, P3)", io)
    print_kv("β", "$β  (primitive: $prim; β=2 does NOT reproduce the example — see P3)", io)
    print_kv("U (16 points)", U, io)

    D = algorithm1_domains(F, U)
    domains_ok = length(U) == 16 && all(d == D_expected for d in D)
    print_kv("D_i \\ {0} (all i)", first(D), io)
    print_check("every domain equals {β⁷,β¹⁴,β²⁸,β³⁵,β⁴⁹,β⁵⁶} = $D_expected", domains_ok, io)

    # Uniform shifts: all six give an APN G at distance 16.
    uniform = [(v, differential_uniformity(apply_modifications(F, U, fill(v, 16))),
        hamming_distance(F, apply_modifications(F, U, fill(v, 16)))) for v in D_expected]
    uniform_ok = all(du == 2 && dd == 16 for (_, du, dd) in uniform)
    print_check("all 6 uniform shifts v ∈ D give an APN G at distance 16", uniform_ok, io)

    # Mixed shifts: none is APN (the paper: "if at least two different values are
    # selected ... the resulting function is not APN").
    mixed_apn = 0
    mixed_total = 0
    for i = 1:6, j = 1:6
        i == j && continue
        mixed_total += 1
        V = [k ≤ 8 ? D_expected[i] : D_expected[j] for k = 1:16]
        differential_uniformity(apply_modifications(F, U, V)) == 2 && (mixed_apn += 1)
    end
    mixed_ok = mixed_apn == 0
    print_check("no two-valued (mixed) shift combination is APN (0 of $mixed_total)", mixed_ok, io)

    ccz = true
    if check_ccz
        b7 = powβ(7)
        target = SBox{n}([
            gf_pow(x, 6, n; modulus = mod) ⊻ gf_pow(x, 9, n; modulus = mod) ⊻
            gf_mul(b7, gf_pow(x, 48, n; modulus = mod), n; modulus = mod) for x = 0:63
        ])
        G = apply_modifications(F, U, fill(D_expected[1], 16))
        ccz = differential_uniformity(target) == 2 && are_ccz_equivalent(G, target)
        print_check("G is CCZ-equivalent to x⁶ + x⁹ + β⁷x⁴⁸ (which is APN)", ccz, io)
        print_kv("catalog", "x⁶+x⁹+β⁷x⁴⁸ is absent from the APN catalog (see README, catalog gap)", io)
    end

    all_ok = prim && domains_ok && uniform_ok && mixed_ok && ccz
    (; all_ok, β, U, D = D_expected, mixed_apn, mixed_total)
end

"""
    algorithm1_report(; io, n, K, seed) -> NamedTuple

Demonstrate Algorithm 1 filtering on Gold x^3 for various n and K.
Shows |D_i| vs 2^n and verifies that APN shifts lie in the allowed domain.
"""
function algorithm1_report(; io::IO = stdout, n::Int = 6, K::Int = 1, seed::Int = 7)
    F = gold_apn(n, 1)
    sz = 1 << n

    # pick K random distinct points
    rng_state = [seed]
    rng = () -> begin
        rng_state[1] = (rng_state[1] * 1664525 + 1013904223) & 0xFFFFFFFF
        rng_state[1]
    end
    points = Int[]
    while length(points) < K
        x = Int(rng() % sz)
        x ∉ points && push!(points, x)
    end

    print_section("Algorithm 1 — Filtering shift domains (n=$n, K=$K)", io)
    print_kv("F", "Gold x^3 over F₂^$n", io)
    print_kv("U (0-based)", points, io)

    domain_sizes, forbidden_sets = algorithm1_filter(F, points)
    for (i, (dsz, fset)) in enumerate(zip(domain_sizes, forbidden_sets))
        print_kv("  |D_$i|", "$dsz / $sz ($(sz - dsz) values filtered)", io)
    end

    # Algorithm 1's guarantee: *if* G is APN then v_i ∈ D_i for every i. Sweep every
    # uniform shift v (a single fixed v is useless here — for K ≤ 2 at n=5 the
    # Corollary 2 bound already forbids an APN G, so the check would never fire).
    n_apn = 0
    all_in_domain = true
    for v = 1:(sz-1)
        G = apply_modifications(F, points, fill(v, K))
        differential_uniformity(G) == 2 || continue
        n_apn += 1
        all(v ∉ forbidden_sets[i] for i = 1:K) || (all_in_domain = false)
    end
    print_kv("uniform shifts v with G APN", "$n_apn / $(sz - 1)", io)
    print_check("every APN uniform shift lies in all D_i (Algorithm 1's guarantee)",
        all_in_domain, io)

    all_ok = all(d < sz for d in domain_sizes) && all_in_domain
    print_check("filtering reduces domain (|D_i| < $sz for all i)", all(d < sz for d in domain_sizes), io)
    (; all_ok, n, K, domain_sizes, sz, n_apn_shifts = n_apn)
end

"""
    algorithm1_examples_report(; io) -> NamedTuple

The three worked examples of Section IV-A.
"""
function algorithm1_examples_report(; io::IO = stdout, check_ccz::Bool = true)
    a = example_a(; io)
    b = example_b(; io, check_ccz)
    c = example_c(; io, check_ccz)
    (; all_ok = a.all_ok && b.all_ok && c.all_ok, a, b, c)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    algorithm1_report()
    algorithm1_examples_report()
end
