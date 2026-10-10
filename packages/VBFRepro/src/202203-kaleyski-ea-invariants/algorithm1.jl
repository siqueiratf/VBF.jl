# Implements Algorithm 1 from Section 3.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications, 2021
# Section: 3 — Guessing the outer permutation, Algorithm 1
#
# Algorithm 1: Partition F₂ⁿ by the multiplicities of Σ₄^F(0).
#   1. For each v ∈ F₂ⁿ, compute M_4^F(0,v) = #{ 3-tuples (y1,y2,y3) :
#      F(y1)⊕F(y2)⊕F(y3)⊕F(y1⊕y2⊕y3) = v }.
#   2. Group elements by multiplicity → partition K1,...,Ks.
#   3. If partitions of F and G have incompatible block-size multisets →
#      conclude F ≇_EA G (fast rejection).
#
# Pseudocode:
#   partition = ea_partition(F, k=4)
#   If sort(partition.bucket_sizes) ≠ sort(partition_G.bucket_sizes) → not EA-equiv
# VBF API used: SBox, ea_partition, EAPartition, nbuckets, ea_partition_signature

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    algorithm1_partition_demo(F::SBox; io, k) -> EAPartition

Display the partition of F₂ⁿ induced by Σ_k^F(0) multiplicities.
"""
function algorithm1_partition_demo(
    F::SBox{N,T};
    io::IO = stdout,
    k::Int = 4,
    label::AbstractString = "F",
) where {N,T}
    p = ea_partition(F, k)
    println(io, "  Partition of F_2^$N for $label (k=$k):")
    println(io, "    nbuckets     = $(nbuckets(p))")
    sorted = sort(p.bucket_sizes; rev = true)
    println(io, "    bucket sizes = $sorted")
    println(io, "    multiplicities = $(p.bucket_multiplicities)")
    return p
end

"""
    algorithm1_invariance_check(F::SBox, G::SBox; io, k) -> Bool

Check that F and G have the same partition signature (necessary for EA-equiv).
"""
function algorithm1_invariance_check(
    F::SBox{N},
    G::SBox{N};
    io::IO = stdout,
    k::Int = 4,
    label_F = "F",
    label_G = "G",
) where {N}
    sig_F = ea_partition_signature(F, k)
    sig_G = ea_partition_signature(G, k)
    ok = (sig_F == sig_G)
    print_check("Partition signatures equal ($label_F vs $label_G)", ok, io)
    return ok
end

"""
    algorithm1_report(; io, n_values) -> NamedTuple

Demonstrate Algorithm 1 on Gold x^3 and catalog n=6 functions.
"""
function algorithm1_report(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section("Algorithm 1 — Partition of F₂ⁿ by Σ₄^F(0) multiplicities", io)

    db = load_catalog()
    all_ok = true

    for n in n_values
        println(io, "\n  n = $n:")
        F = gold_x3(n)
        algorithm1_partition_demo(F; io, label = "Gold x^3")

        # EA-equivalent G should have same partition signature
        sz = 1 << n
        G_lut = UInt8[UInt8(xor(Int(F.lut[xor(x, 1) + 1]), 2)) for x = 0:(sz - 1)]
        G = SBox{n,UInt8}(G_lut)
        ok = algorithm1_invariance_check(F, G; io, label_F = "Gold x^3", label_G = "G=F(x⊕1)⊕2")
        all_ok &= ok

        # Non-equivalent function from catalog (different family)
        rows = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = n))
        if length(rows) ≥ 2
            # Take the second function in the list (different from first)
            H = load_sbox(db, rows[2].canonical_name)
            algorithm1_partition_demo(H; io, label = rows[2].canonical_name)
        end
    end

    return (; all_ok, n_values)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    algorithm1_report()
end
