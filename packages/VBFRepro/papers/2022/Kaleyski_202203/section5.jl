# Implements verification of Section 5 computational results.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications, 2021
# Section: 5 — Computational results
#
# Paper claims (bounded verification on catalog APN functions):
#   - For n even: partitions have many distinct classes (mostly 12–16 buckets).
#   - "Gold-like" partition (3 classes: sizes 1, 70, 185 for n=8) is rarest.
#   - For n odd (n=5,7): trivial partition = 2 buckets ({0} and F₂ⁿ\{0}).
#   - Distinct partitions outnumber functions (most partitions are unique).
#
# Pseudocode:
#   For each APN function F in catalog:
#     1. Compute ea_partition(F, k=4) → signature (sorted bucket sizes).
#     2. Accumulate signature → count map.
#     3. Report: total funcs, distinct signatures, Gold-like count, trivial count.
# VBF API used: SBox, ea_partition, ea_partition_signature, nbuckets

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    is_trivial_partition(p::EAPartition) -> Bool

True iff the partition has exactly 2 buckets with sizes 1 and 2ⁿ-1
(the "trivial" partition found for all odd-n APN in the paper).
"""
function is_trivial_partition(p::EAPartition)
    nbuckets(p) == 2 || return false
    sz = sort(p.bucket_sizes)
    return sz[1] == 1 && sz[2] == (1 << p.n) - 1
end

"""
    is_gold_like_partition(p::EAPartition) -> Bool

True iff the partition has exactly 3 buckets (Gold-like structure).
At n=8 this corresponds to sizes [1, 70, 185]; at other n the sizes differ
but the 3-class structure is the Gold hallmark.
"""
is_gold_like_partition(p::EAPartition) = nbuckets(p) == 3

"""
    section5_survey(db; n_values, limit, io, k) -> NamedTuple

Compute partition statistics for catalog quadratic APN functions.
"""
function section5_survey(
    db;
    n_values::Vector{Int} = [5, 6],
    limit::Int = typemax(Int),
    io::IO = stdout,
    k::Int = 4,
)
    print_section("Section 5 — Partition statistics for known quadratic APN", io)
    println(io, "  (Bounded: catalog functions only, n ∈ $n_values)")
    println(io)

    all_sigs = Dict{Vector{Int},Int}()
    total = 0
    trivial_count = 0
    gold_like_count = 0
    per_n = Dict{Int,NamedTuple}()

    for n in n_values
        rows = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = n))
        rows = rows[1:min(limit, end)]
        n_funcs = length(rows)
        n_distinct = Set{Vector{Int}}()
        n_trivial = 0
        n_gold_like = 0
        for r in rows
            F = load_sbox(db, r.canonical_name)
            p = ea_partition(F, k)
            sig = sort(p.bucket_sizes; rev = true)
            push!(n_distinct, sig)
            all_sigs[sig] = get(all_sigs, sig, 0) + 1
            is_trivial_partition(p) && (n_trivial += 1)
            is_gold_like_partition(p) && (n_gold_like += 1)
        end
        trivial_count += n_trivial
        gold_like_count += n_gold_like
        total += n_funcs
        per_n[n] = (;
            n_funcs,
            n_distinct = length(n_distinct),
            n_trivial,
            n_gold_like,
        )
        println(io, "  n = $n:")
        println(io, "    functions:         $n_funcs")
        println(io, "    distinct sigs:     $(length(n_distinct))")
        println(io, "    trivial partitions: $n_trivial  (expected: all if n odd)")
        println(io, "    Gold-like (3 bkts): $n_gold_like")
    end

    println(io)
    println(io, "  Totals:")
    println(io, "    functions:          $total")
    println(io, "    distinct signatures: $(length(all_sigs))")
    println(io, "    trivial (2-bucket):  $trivial_count")
    println(io, "    Gold-like (3-bucket): $gold_like_count")

    # Check odd-n triviality
    odd_ns = [n for n in n_values if isodd(n)]
    odd_trivial_ok = all(per_n[n].n_trivial == per_n[n].n_funcs for n in odd_ns)
    print_check(
        "All odd-n functions have trivial partition (paper Section 5)",
        odd_trivial_ok,
        io,
    )

    # Gold x^3 should always be Gold-like (3 buckets)
    even_ns = [n for n in n_values if iseven(n)]
    gold_ok = true
    for n in even_ns
        F = gold_x3(n)
        p = ea_partition(F, k)
        g_ok = is_gold_like_partition(p)
        gold_ok &= g_ok
        print_check("Gold x^3 n=$n is Gold-like (3 buckets)", g_ok, io)
        print_kv("  Gold x^3 n=$n bucket sizes", sort(p.bucket_sizes; rev = true), io)
    end

    # n=8 Gold-like claim: sizes should be [185, 70, 1]
    if 8 in n_values
        F8 = gold_x3(8)
        p8 = ea_partition(F8, k)
        expected = [185, 70, 1]
        sizes8 = sort(p8.bucket_sizes; rev = true)
        gold8_ok = (sizes8 == expected)
        print_check(
            "Gold x^3 n=8 partition = [185, 70, 1] (paper Section 5)",
            gold8_ok,
            io,
        )
    end

    return (; total, n_distinct = length(all_sigs), trivial_count, gold_like_count, per_n, odd_trivial_ok, gold_ok)
end

"""
    section5_report(; io, n_values, limit) -> NamedTuple
"""
function section5_report(;
    io::IO = stdout,
    n_values::Vector{Int} = [5, 6],
    limit::Int = typemax(Int),
)
    print_header(io)
    db = load_catalog()
    return section5_survey(db; n_values, limit, io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section5_report()
end
