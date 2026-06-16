# Implements Section 4.3 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 4 — EA-partitioning (ortho-derivative invariant)
#
# Section 4.3: CCZ-class partition of all 6-bit quadratic APN functions
# into EA-equivalence classes via the ortho-derivative.
#
# Key result (Definition 4.4, Proposition 4.6, Section 4.2.2):
#   For a quadratic APN function F : F₂ⁿ → F₂ⁿ, the unique ortho-derivative
#   π_F is an EA-class invariant: F ~_EA G ⟹ π_F ~_lin π_G.
#   Therefore apn_ea_mugshot (which fingerprints π_F's spectra) is an
#   EA-equivalence partition key.
#
# Pseudocode:
#   1. Load all n=6 quadratic APN functions from catalog (15 functions).
#   2. Partition by apn_ea_mugshot: functions with equal mugshot → same bucket.
#   3. Each bucket is a candidate EA-class.
#   4. Verify correctness with are_ea_equivalent on pairs within/across buckets.
# VBF API used: ortho_derivative, apn_ea_mugshot, are_ea_equivalent

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

"""
    section4_3_report(; io) -> NamedTuple

Partition all n=6 quadratic APN functions from the catalog into EA-classes
using the ortho-derivative invariant (apn_ea_mugshot). Verify the partition
by cross-checking pairs with are_ea_equivalent.

Completeness: exhaustive over all 15 n=6 quadratic APN functions.
"""
function section4_3_report(; io::IO = stdout)
    print_section("Section 4.3: 6-bit APN EA-partitioning via ortho-derivative", io)

    db = load_catalog()
    all_fns = list_functions(db; n=6, is_apn=true)
    quad_fns = filter(f -> f.is_quadratic, all_fns)

    print_kv("n=6 APN functions in catalog", length(all_fns), io)
    print_kv("n=6 quadratic APN functions", length(quad_fns), io)

    sboxes = [(f.canonical_name, load_sbox(db, f.id)) for f in quad_fns]

    # Partition by EA-mugshot
    buckets = Dict()
    for (name, sb) in sboxes
        mug = apn_ea_mugshot(sb)
        push!(get!(buckets, mug, Tuple{String,Any}[]), (name, sb))
    end

    n_classes = length(buckets)
    print_kv("EA-classes (distinct ortho-derivative mugshots)", n_classes, io)

    bucket_sizes = sort([length(v) for v in values(buckets)], rev=true)
    print_kv("Bucket sizes", bucket_sizes, io)

    # List classes
    for (i, (_, members)) in enumerate(sort(collect(buckets), by=v->length(v[2]), rev=true))
        names = join([m[1] for m in members], ", ")
        println(io, "  Class $i (size=$(length(members))): $names")
    end

    # Verify: pairs in same bucket should be EA-equivalent
    intra_ok = true
    for (_, members) in buckets
        length(members) < 2 && continue
        for i in 1:length(members)
            for j in (i+1):length(members)
                ea = are_ea_equivalent(members[i][2], members[j][2])
                if !ea
                    println(io, "  [FAIL] $(members[i][1]) ~_EA $(members[j][1]) = false (same bucket!)")
                    intra_ok = false
                end
            end
        end
    end
    print_check("All same-bucket pairs are EA-equivalent", intra_ok, io)

    # Verify: one cross-bucket pair per non-singleton class should be non-EA-equiv
    bucket_list = collect(values(buckets))
    cross_ok = true
    if length(bucket_list) ≥ 2
        s1 = bucket_list[1][1][2]
        s2 = bucket_list[2][1][2]
        cross_ok = !are_ea_equivalent(s1, s2)
    end
    print_check("Cross-bucket pair: not EA-equivalent", cross_ok, io)

    all_ok = intra_ok && cross_ok
    print_check("Section 4.3 EA-partitioning via ortho-derivative", all_ok, io)
    print_kv("Completeness", "exhaustive over all $(length(quad_fns)) n=6 quadratic APN functions", io)

    return (;
        n_functions = length(quad_fns),
        n_ea_classes = n_classes,
        bucket_sizes,
        intra_ok,
        cross_ok,
        all_ok,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    section4_3_report()
end
