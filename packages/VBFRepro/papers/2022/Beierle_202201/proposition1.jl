# Implements Proposition 1 (ortho-derivative CCZ-distinctness check) from Beierle & Leander (2022).
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: §3.3 — EA-equivalence Check, p.7
#
# Proposition 1 (Canteaut–Couvreur–Perrin 2020/2022): For a quadratic APN function F,
# the ortho-derivative Π_F is uniquely defined and two EA-equivalent (= CCZ-equivalent
# for quadratic APNs by Theorem 1) quadratic APN functions have linear-equivalent
# ortho-derivatives. The differential spectrum of Π_F is therefore a CCZ-invariant,
# used here to certify that each new 8-bit instance differs from the Gold APN.
#
# VBF API used: SBox, ortho_derivative, differential_spectrum, sorted_pairs, gold_apn

include(joinpath(@__DIR__, "helpers.jl"))

import Random

"""
    ortho_derivative_signature(f::SBox) -> Vector{Pair{Int,Int}}

Compute the ortho-derivative differential spectrum of f as a CCZ-invariant.
Returns sorted (value => count) pairs of the differential_spectrum of the
ortho-derivative. Canteaut–Couvreur–Perrin (2022), Definition 3.
"""
function ortho_derivative_signature(f::SBox)
    od = ortho_derivative(f)
    sp = differential_spectrum(od)
    return sorted_pairs(sp)
end

"""
    ccz_distinctness(io; sample_size, seed, save_results) -> NamedTuple

Sample sample_size functions from apn_8bit.txt, compute their
ortho_derivative_signature, and compare to the Gold APN signature.
Beierle–Leander (2022), Results — ccz-distinctness.
Note: this is a bounded check on a sample; not exhaustive over all 12921 functions.
"""
function ccz_distinctness(
    io::IO = stdout;
    sample_size::Int = 10,
    seed::Int = 42,
    save_results::Bool = false,
    input_dir::AbstractString = joinpath(@__DIR__, "inputs"),
)
    print_section("ccz-distinctness (sampled, not exhaustive)", io)
    sample_size > 0 || throw(ArgumentError("sample_size must be positive"))
    print_kv("seed", seed, io)
    print_kv("sample_size", sample_size, io)
    print_kv("note", "sampled $sample_size / 12921 functions — NOT exhaustive", io)

    path8 = joinpath(input_dir, "apn_8bit.txt")
    if !isfile(path8)
        print_kv("status", "INCONCLUSIVE: original apn_8bit.txt unavailable", io)
        return (; status = :unavailable, sample_size = 0, distinct_from_gold = 0,
                 pairwise_distinct = missing, exhaustive = false)
    end
    n = 8

    # Reference: Gold APN signature for n=8.
    gold = gold_apn(n)
    gold_sig = ortho_derivative_signature(gold)
    print_kv("Gold APN (n=8) signature", gold_sig, io)

    # Load sample_size functions from the stream.
    sampled = SBox[]
    for f in stream_dataset(path8; limit = sample_size)
        push!(sampled, f)
    end
    print_kv("loaded", length(sampled), io)

    # Compute signatures.
    sigs = [ortho_derivative_signature(f) for f in sampled]

    # Count how many have signatures distinct from Gold.
    distinct_from_gold = count(s -> s != gold_sig, sigs)
    print_kv("distinct signature from Gold", distinct_from_gold, io)
    print_check(
        "all sampled differ from Gold in ortho-derivative signature",
        !isempty(sampled) && distinct_from_gold == length(sampled),
        io,
    )

    # Check for pairwise collisions among sampled functions.
    sig_set = Set(string(s) for s in sigs)
    pairwise_distinct = !isempty(sigs) && length(sig_set) == length(sigs)
    print_check("sampled functions are pairwise distinct in signature", pairwise_distinct, io)

    results = (;
        status = isempty(sampled) ? :inconclusive : :sampled,
        seed,
        sample_size = length(sampled),
        total = 12921,
        exhaustive = false,
        distinct_from_gold,
        pairwise_distinct,
        gold_sig,
    )
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "ccz_distinctness.toml"), "w") do f
            println(f, "# ccz_distinctness results")
            println(f, "seed = $seed")
            println(f, "sample_size = $(length(sampled))")
            println(f, "total = 12921")
            println(f, "exhaustive = false")
            println(f, "distinct_from_gold = $distinct_from_gold")
            println(f, "pairwise_distinct = $pairwise_distinct")
        end
    end
    return results
end