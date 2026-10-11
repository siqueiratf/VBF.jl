using VBF
# Implements small diagnostics: sigma-index spot check and properties of sampled functions
# Study: census of quadratic APN functions on F_2^8 (packages/VBFSearch/data/research/archive/census)
#
# Math:
#   spot_check: the coverage estimator trusts the ccz_sigma_index side store.  Recompute
#     sigma_hash for random members of the three large n = 8 corpora and confirm that the
#     index lists each member at its own (source, member_idx).
#   properties: for a coefficient string, report differential uniformity, the distribution
#     of component ranks (rank of the bilinear form of b.F, b != 0; values 8, 6, 4, 2), the
#     sigma hash and the absolute Walsh spectrum; optionally |Aut| (ortho-derivative
#     method) and whether F is CCZ-equivalent to a permutation (slow).
#
# Pseudocode:
#   spot_check(per_corpus, seed): for each corpus, draw per_corpus member indices,
#     recompute sigma_hash, query the index, count matches.
#   properties(coeffs; aut): decode, compute the listed invariants, print.
# VBF API used: SBox, differential_uniformity, absolute_walsh_spectrum, sorted_pairs,
#   automorphisms_from_ortho_derivative, is_ccz_equivalent_to_permutation
# VBFCatalog API used: load_catalog, corpus_function, sigma_hash, _open_sigma_index

isdefined(@__MODULE__, :encode_coeffs) || include(joinpath(@__DIR__, "helpers.jl"))

using Random
using VBFCatalog

const SPOT_CORPORA = ["beierle2025_n8", "beierleleander2022_n8", "yuperrin2022_qam_n8"]

"Recompute sigma hashes of random corpus members and check them against the index."
function spot_check(; per_corpus::Int = 20, seed::Int = 2024, io::IO = stdout)
    db = VBFCatalog.load_catalog()
    idx = VBFCatalog._open_sigma_index()
    rng = Xoshiro(seed)
    ok = 0
    tot = 0
    for name in SPOT_CORPORA, i in rand(rng, 1:VBFCatalog.corpus_length(db,name), per_corpus)
        F = VBFCatalog.corpus_function(db, name, i)
        h = VBFCatalog.sigma_hash(F)
        rows = [(String(r.source), Int(r.member_idx)) for r in VBFCatalog.DBInterface.execute(idx,
                "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash='$h'")]
        tot += 1
        ok += any(==((name, i)), rows)
    end
    println(io, "spot-check: $ok / $tot recomputed hashes found at their own (source, idx)")
    (found = ok, total = tot)
end

"Print invariants of the (8,8) function with coefficient string `coeffs`."
function properties(coeffs::AbstractString; aut::Bool = false, io::IO = stdout)
    C = decode_coeffs(coeffs, 8)
    F = sbox_from_coeffs(coeffs, 8)
    println(io, "coeffs = ", coeffs)
    @printf(io, "  du=%d  rank distribution (8,6,4,2,0) = %s\n", differential_uniformity(F),
            string(VBF.QuadraticRestrictions.rank_hist(C,8,8)))
    println(io, "  sigma = ", VBFCatalog.sigma_hash(F))
    println(io, "  |abs Walsh spectrum| = ", VBF.sorted_pairs(absolute_walsh_spectrum(F)))
    flush(io)
    aut || return nothing
    t = @elapsed auts = automorphisms_from_ortho_derivative(F)
    @printf(io, "  |Aut| from ortho-derivative = %d  (|Stab| = %d)  [%.1fs]\n", length(auts),
            length(auts) ÷ 256, t)
    flush(io)
    t = @elapsed p = is_ccz_equivalent_to_permutation(F)
    @printf(io, "  CCZ-equivalent to a permutation: %s   [%.1fs]\n", p, t)
    nothing
end
