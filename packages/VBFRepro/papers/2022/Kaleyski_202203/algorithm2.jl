# Implements Algorithm 2 from Section 3.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications, 2021
# Section: 3 — Guessing the outer permutation, Algorithm 2
#
# Algorithm 2: Enumerate all invertible linear L1 : F₂ⁿ → F₂ⁿ
#   such that L1 maps the F-partition onto the G-partition respecting sizes.
#
# Pseudocode:
#   1. For each size-preserving bucket map σ (F-buckets → G-buckets):
#      a. DFS over basis choices e0,...,e_{n-1}: guess L1(eᵢ) ∈ Cᵢ, extend by linearity.
#      b. Backtrack if any linear combination lands in wrong-sized bucket.
#   2. Return all valid L1 LUTs.
#
# Proposition 6: the set K of linear perms preserving F's own partition is a subgroup.
# |K| = number of partition_automorphisms, an EA-invariant.
#
# Table 1 "Permutations" column (not timing): counts |K| per n=6,8 function.
# VBF API used: SBox, ea_partition, outer_permutations, enumerate_bucket_maps,
#               partition_automorphisms

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    algorithm2_self_automorphisms(F::SBox; io, k) -> Int

Count |K| = #{invertible linear L : L permutes each bucket of the F-partition}.
This is the "Permutations" value in Table 1 of the paper (Proposition 6, K group).
"""
function algorithm2_self_automorphisms(
    F::SBox{N,T};
    io::IO = stdout,
    k::Int = 4,
    label::AbstractString = "F",
) where {N,T}
    auts = partition_automorphisms(F, k)
    n_aut = length(auts)
    print_kv("  |K| (partition automorphisms) for $label", n_aut, io)
    return n_aut
end

"""
    algorithm2_outer_candidates(F::SBox, G::SBox; io, k) -> Int

Count total outer permutation candidates L1 mapping F-partition to G-partition.
This is the search space for the outer step of the EA-equivalence test.
"""
function algorithm2_outer_candidates(
    F::SBox{N,T},
    G::SBox{N,T};
    io::IO = stdout,
    k::Int = 4,
    label_F = "F",
    label_G = "G",
) where {N,T}
    partF = ea_partition(F, k)
    partG = ea_partition(G, k)
    sigmas = enumerate_bucket_maps(partF, partG)
    total = sum(length(outer_permutations(partF, partG, σ, T)) for σ in sigmas; init = 0)
    print_kv("  Outer permutation candidates ($label_F → $label_G)", total, io)
    return total
end

"""
    algorithm2_report(; io, n, k) -> NamedTuple

Demonstrate Algorithm 2 on n=6 quadratic APN functions.
Shows |K| per function (Table 1 "Permutations" column, n=6 block, no timing).
"""
function algorithm2_report(; io::IO = stdout, n::Int = 6, k::Int = 4, limit::Int = 13)
    print_section(
        "Algorithm 2 — Outer permutation enumeration, |K| per function (n=$n)", io,
    )
    println(io, "  (Table 1 'Permutations' column only; timing columns excluded.)")
    println(io, "  |K| = #{invertible linear L preserving F's partition} = EA-invariant.")
    println(io)

    db = load_catalog()
    rows = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = n))
    rows = rows[1:min(limit, end)]

    results = NamedTuple[]
    for r in rows
        F = load_sbox(db, r.canonical_name)
        n_aut = algorithm2_self_automorphisms(F; io, k, label = r.canonical_name)
        push!(results, (; name = r.canonical_name, K_size = n_aut))
    end

    # Spot-check: Gold x^3 at n=6 should give 1008 (Table 1, row 1.1)
    gold = gold_x3(n)
    k_gold = algorithm2_self_automorphisms(gold; io, k, label = "Gold x^3 (n=$n, Table 1 row 1.1)")
    gold_ok = (n == 6 && k_gold == 1008) || n != 6
    print_check("Gold x^3 n=6 |K| == 1008 (Table 1 row 1.1)", gold_ok, io)

    return (; results, gold_K_size = k_gold, gold_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    algorithm2_report()
end
