# Implements Theorem 3
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 3 — Another example
#
# Pseudocode:
#   1. Let n,m with gcd(m,n)=1; a∈GF(2ⁿ), b∈GF(2ⁿ)*, and
#      G(x,y) = x^{2^{2m}+2^{3m}} + a·x^{2^{2m}}·y^{2^m} + b·y^{2^m+1}
#   2. F(x,y) := (xy, G(x,y)) on GF(2ⁿ)×GF(2ⁿ), packed as SBox{2n}
#   3. F is APN ⟺ P(x)=x^{2^m+1}+ax+b has no root in GF(2ⁿ)   (Theorem 3)
#   4. On half=4 (F₂⁸): a≠0 gives 2 new CCZ-classes; ≥3 classes total, and the
#      mugshot buckets reproduce the paper's Section-3 b⁵ table exactly
# VBF API used: taniguchi_apn, taniguchi_apn_representatives, are_ccz_equivalent,
#               differential_uniformity, algebraic_degree, apn_ea_mugshot,
#               APNEAMugshot, gf_pow, primitive_polynomial

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem3_verify(; half, m) -> NamedTuple

For all (a, b) with b≠0 over GF(2^half): verify the IFF condition
P(x)=x^{2^m+1}+ax+b rootless ⟺ F(x,y)=(xy,G(x,y)) APN.
Returns counts of APN and non-APN instances, plus pass/fail.
"""
function theorem3_verify(; half::Int = 4, m::Int = 1)
    n = half
    gcd(m, n) == 1 || error("need gcd(m,n)=1, got m=$m n=$n")
    apn_count = 0
    non_apn_count = 0
    for a = 0:(1<<n)-1, b = 1:(1<<n)-1
        rootless = projective_polynomial_rootless(n, m, a, b)
        F = taniguchi_apn(n, m, a, b)
        is_apn = differential_uniformity(F) == 2
        rootless == is_apn ||
            return (; ok=false, apn_count=0, non_apn_count=0,
                      msg="IFF failed: a=$a b=$b rootless=$rootless is_apn=$is_apn")
        rootless ? (apn_count += 1) : (non_apn_count += 1)
    end
    (; ok=true, apn_count, non_apn_count, msg="all $(apn_count+non_apn_count) pairs checked")
end

"""
    theorem3_ccz_classes(half) -> NamedTuple

Distinct ortho-derivative EA-signatures (`apn_ea_mugshot`) of Taniguchi's Theorem 3
family on F₂^{2·half}, with an explicit `are_ccz_equivalent` certificate that the
representatives are pairwise CCZ-**in**equivalent.

Distinct signatures prove inequivalence, but *equal* signatures do not prove
equivalence — so the number of signatures is a **lower bound** on the number of
CCZ-classes in the family, never an exact count. (The paper argues the same way,
via Γ-ranks, so the strength matches.) On half=4 the bound is 3: one old class
(a=0, Zhou–Pott) and two new ones (a≠0).
"""
function theorem3_ccz_classes(half::Int = 4)
    reps = taniguchi_apn_representatives(half)
    n_sigs = length(reps)
    n_new = count(r -> r.new, reps)
    all_quad = all(algebraic_degree(r.sbox) == 2 for r in reps)
    pairwise_inequiv = all(
        !are_ccz_equivalent(reps[p].sbox, reps[q].sbox) for p = 1:n_sigs for
        q = (p+1):n_sigs
    )
    (; n_od_signatures=n_sigs, ccz_classes_lower_bound=n_sigs, n_new,
       all_quadratic=all_quad, pairwise_ccz_inequivalent=pairwise_inequiv, reps)
end

"""
    theorem3_b5_partition(half=4) -> NamedTuple

The paper's Section-3 table. Group **every** admissible APN triple (m,a,b) on
F₂^{2·half} by `apn_ea_mugshot` and check that the buckets are exactly the three
rows of the table:

| row | Γ-rank on F₂⁸ (Magma, paper) |
|---|---|
| a = 0 (falls back into Zhou–Pott Cor 1, i=2) | 13642 |
| a ≠ 0 and b⁵ = 1 | 13700 |
| a ≠ 0 and b⁵ ≠ 1 | 13798 |

The Γ-ranks themselves are Magma numbers we cannot recompute (`gamma_rank` refuses
n=8). What *is* checkable — and is checked here — is that the b⁵ split is precisely
the mugshot split, i.e. that the paper's three rows are three genuinely different
EA-classes and that nothing falls outside them. The b⁵ criterion is the paper's
F₂⁸ statement (`half = 4`), where b⁵=1 ⟺ b is a cube in GF(2⁴).
"""
function theorem3_b5_partition(half::Int = 4)
    n = half
    mod = primitive_polynomial(n)
    buckets = Dict{APNEAMugshot,Vector{NTuple{3,Int}}}()
    for m = 1:(n-1)
        gcd(m, n) == 1 || continue
        for a = 0:(1<<n)-1, b = 1:(1<<n)-1
            projective_polynomial_rootless(n, m, a, b; modulus=mod) || continue
            F = taniguchi_apn(n, m, a, b; modulus=mod)
            (differential_uniformity(F) == 2 && algebraic_degree(F) == 2) || continue
            push!(get!(buckets, apn_ea_mugshot(F), NTuple{3,Int}[]), (m, a, b))
        end
    end
    b5_is_1(b) = gf_pow(b, 5, n; modulus=mod) == 1
    rows = map(collect(values(buckets))) do mem
        kind = if all(t -> t[2] == 0, mem)
            :a0
        elseif all(t -> t[2] != 0 && b5_is_1(t[3]), mem)
            :a_nonzero_b5_eq_1
        elseif all(t -> t[2] != 0 && !b5_is_1(t[3]), mem)
            :a_nonzero_b5_ne_1
        else
            :mixed   # a mugshot bucket straddling two rows of the paper's table
        end
        (; kind, size=length(mem))
    end
    sort!(rows; by = r -> r.size)
    kinds = [r.kind for r in rows]
    (; n_buckets=length(buckets), rows, kinds, sizes=[r.size for r in rows],
       total=sum(r -> r.size, rows; init=0),
       partition_exact=(kinds == [:a0, :a_nonzero_b5_eq_1, :a_nonzero_b5_ne_1]))
end

function theorem3_report(io::IO = stdout)
    print_section(io, "Theorem 3 — APN iff P(x) rootless")

    for (half, m) in [(4, 1), (5, 1)]
        r = theorem3_verify(; half, m)
        print_check(io, "half=$half m=$m IFF check ($(r.apn_count)+$(r.non_apn_count) pairs)", r.ok)
    end

    r3 = theorem3_ccz_classes(4)
    print_check(io, "half=4: ≥ 3 CCZ-classes (3 distinct OD signatures)",
                r3.ccz_classes_lower_bound == 3)
    print_check(io, "half=4: the 3 representatives are pairwise CCZ-inequivalent",
                r3.pairwise_ccz_inequivalent)
    print_check(io, "half=4: 2 of them are new (a≠0)", r3.n_new == 2)
    print_check(io, "half=4: all reps are quadratic APN", r3.all_quadratic)
    print_kv(io, "CCZ-classes on F₂⁸",
             "≥ $(r3.ccz_classes_lower_bound) (lower bound: equal OD signatures would not prove equivalence)")
    print_kv(io, "new classes (a≠0)", r3.n_new)

    print_section(io, "Theorem 3 — Section-3 table: the b⁵ partition")
    p = theorem3_b5_partition(4)
    print_check(io, "half=4: admissible APN (m,a,b) fall into exactly 3 mugshot buckets",
                p.n_buckets == 3)
    print_check(io, "half=4: buckets are exactly {a=0} / {a≠0,b⁵=1} / {a≠0,b⁵≠1}",
                p.partition_exact)
    print_check(io, "half=4: bucket sizes 20 / 30 / 120 (170 admissible triples)",
                p.sizes == [20, 30, 120] && p.total == 170)
    for r in p.rows
        rank = r.kind === :a0 ? "13642" :
               r.kind === :a_nonzero_b5_eq_1 ? "13700" :
               r.kind === :a_nonzero_b5_ne_1 ? "13798" : "?"
        print_kv(io, "  $(r.kind)", "$(r.size) admissible (m,a,b)  →  Γ-rank $rank  [Magma, paper]")
    end
    println(io, "  completeness: exhaustive over all (a,b) for half∈{4,5}; the b⁵")
    println(io, "  partition is exhaustive over every admissible APN (m,a,b) at half=4")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_report()
end
