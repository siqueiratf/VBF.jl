# Implements Definition 3.2 and its cluster — i-compatible subspaces
# (Definition 3.2, Example 3.3, Proposition 3.4, Lemma 3.5, Corollary 3.6,
#  and the exhaustive 2-dimensional search stated after Corollary 3.6).
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 3 — Walsh zeros of Gold functions
#
# Pseudocode:
#   S i-compatible  ⟺  S^{-1/(2^i+1)} is an additive subspace.
#   Ex 3.3:   {0}, F_2, F_{2^n} are i-compatible; μS is whenever S is.
#   Prop 3.4: subfields F_{2^m} (m | n) are i-compatible.
#   Lemma 3.5: 3 | n, ξ ∈ F_8 ⟹ ξ^{-1/(2^i+1)} = ξ^{2^i}.
#   Cor 3.6:  every additive subspace of the F_8-subfield is i-compatible.
#   Exhaustive: a 2-dim subspace {0,u,v,u⊻v} is i-compatible iff
#               d(u) ⊻ d(v) ⊻ d(u⊻v) = 0 with d = gold_dual (d is injective);
#               count over all 2-dim subspaces; expect 0 if 3∤n, 2^n-1 if 3|n,
#               with the 3|n witnesses being exactly the μ·(2-dim subspaces
#               of F_8).
# VBF API used: gf_mul, gf_pow, subfield_elements, extract_linear_subspaces,
#   span_from_basis, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    is_icompatible(S, n, i; modulus, dual) -> Bool

Definition 3.2: `S` (list of field elements, an additive subspace containing
0) is i-compatible iff `S^{-1/(2^i+1)}` is additively closed.
"""
function is_icompatible(
    S::Vector{Int},
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    dual::Vector{Int} = gold_dual_table(n, i; modulus),
)
    # The whole field is always i-compatible: gold_dual is a bijection.
    length(S) == (1 << n) && length(Set(S)) == (1 << n) && return true
    sd = Set{Int}(dual[s+1] for s in S)
    length(sd) == length(S) || return false
    for x in sd, y in sd
        (x ⊻ y) in sd || return false
    end
    true
end

"All additive subspaces of the F_{2^m}-subfield of F_{2^n}, of dimension `d`."
function subfield_subspaces(n::Int, m::Int, d::Int; modulus::Int = primitive_polynomial(n))
    els = UInt32.(filter(!=(0), subfield_elements(n, m; modulus)))
    bases = extract_linear_subspaces(els, d; max_bits = n)
    [Int.(sort(span_from_basis(b))) for b in bases]
end

"""
    count_2dim_icompatible(n, i; modulus) -> NamedTuple

Exhaustive search over all (2^n-1)(2^n-2)/6 two-dimensional subspaces of
F_{2^n}. Returns the found subspaces (as sorted 4-element spans) and, when
3 | n, whether they are exactly the μ-scalings of the 2-dim subspaces of the
F_8-subfield (Cor 3.6 + Ex 3.3(ii)).
"""
function count_2dim_icompatible(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    dual = gold_dual_table(n, i; modulus)
    found = Vector{NTuple{4,Int}}()
    total = 0
    for u = 1:(1<<n)-1, v = (u+1):(1<<n)-1
        w = u ⊻ v
        w > v || continue
        total += 1
        if dual[u+1] ⊻ dual[v+1] ⊻ dual[w+1] == 0
            push!(found, (0, u, v, w))
        end
    end
    expected = n % 3 == 0 ? (1 << n) - 1 : 0
    scaled_match = true
    if n % 3 == 0
        scaled = Set{NTuple{4,Int}}()
        for sp in subfield_subspaces(n, 3, 2; modulus), mu = 1:(1<<n)-1
            t = sort([gf_mul(mu, s, n; modulus) for s in sp])
            push!(scaled, (t[1], t[2], t[3], t[4]))
        end
        scaled_match = scaled == Set(found)
    end
    (; n, i, total, count = length(found), expected, matches_expected = length(found) == expected, scaled_match)
end

"""
    definition3_2_build(n, i; modulus) -> NamedTuple

Checks for the whole Section 3 cluster at (n, i).
"""
function definition3_2_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    dual = gold_dual_table(n, i; modulus)
    rng = MersenneTwister(2021)
    full = collect(0:(1<<n)-1)
    # Example 3.3(i)
    ex33_i =
        is_icompatible([0], n, i; modulus, dual) &&
        is_icompatible([0, 1], n, i; modulus, dual) &&
        is_icompatible(full, n, i; modulus, dual)
    # Example 3.3(ii): μS for S = F_2 (all μ — exhaustive, they are the 1-dim spaces)
    ex33_ii = all(is_icompatible([0, mu], n, i; modulus, dual) for mu = 1:(1<<n)-1)
    # Proposition 3.4: subfields F_{2^m}, m | n
    prop3_4 = all(
        is_icompatible(subfield_elements(n, m; modulus), n, i; modulus, dual) for
        m in filter(m -> n % m == 0, 1:n)
    )
    # Lemma 3.5 and Corollary 3.6 (only when 3 | n)
    lemma3_5 = true
    cor3_6 = true
    if n % 3 == 0
        f8 = subfield_elements(n, 3; modulus)
        lemma3_5 = all(dual[xi+1] == gf_pow(xi, 1 << i, n; modulus) for xi in f8)
        cor3_6 = all(
            is_icompatible(sp, n, i; modulus, dual) for d = 1:3 for
            sp in subfield_subspaces(n, 3, d; modulus)
        )
        # scalings of subfield subspaces (Ex 3.3(ii) + Cor 3.6), sampled μ
        for _ = 1:20
            mu = rand(rng, 1:(1<<n)-1)
            sp = rand(rng, subfield_subspaces(n, 3, 2; modulus))
            sc = [gf_mul(mu, s, n; modulus) for s in sp]
            cor3_6 &= is_icompatible(sc, n, i; modulus, dual)
        end
    end
    (; n, i, ex33_i, ex33_ii, prop3_4, lemma3_5, cor3_6, applicable_3div = n % 3 == 0)
end

function definition3_2_report(
    io::IO = stdout;
    n::Int = 9,
    i::Int = 1,
    modulus::Int = primitive_polynomial(n),
)
    r = definition3_2_build(n, i; modulus)
    print_section("Definition 3.2 cluster — i-compatible subspaces, n=$n, i=$i", io)
    print_check(io, "Ex 3.3(i): {0}, F_2, F_{2^$n} are i-compatible", r.ex33_i)
    print_check(io, "Ex 3.3(ii): μF_2 i-compatible for all μ", r.ex33_ii)
    print_check(io, "Prop 3.4: subfields F_{2^m} (m | $n) are i-compatible", r.prop3_4)
    if r.applicable_3div
        print_check(io, "Lemma 3.5: ξ^{-1/(2^$i+1)} = ξ^{2^$i} on F_8", r.lemma3_5)
        print_check(io, "Cor 3.6: subspaces of F_8-subfield (+ sampled μ-scalings)", r.cor3_6)
    end
    c = count_2dim_icompatible(n, i; modulus)
    print_check(
        io,
        "2-dim i-compatible count = $(c.expected) ($(c.count) found / $(c.total) subspaces)",
        c.matches_expected,
    )
    n % 3 == 0 && print_check(io, "2-dim witnesses = μ·(2-dim subspaces of F_8)", c.scaled_match)
    print_kv(io, "completeness", "exhaustive over 2-dim subspaces of F_{2^$n}")
end

if abspath(PROGRAM_FILE) == @__FILE__
    for (n, i) in ((5, 1), (7, 1), (9, 1), (9, 2))
        definition3_2_report(; n, i)
    end
end
