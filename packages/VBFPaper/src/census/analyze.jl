# Implements the census analysis: mass, sigma-index coverage, N estimates and new sigma
# Study: census of quadratic APN functions on F_2^8 (packages/VBFSearch/data/research/archive/census)
#
# Math:
#   Sample t has weight W_t = exp(lw_t) (0 for -Inf rows); E[W] = T(8,8).
#   Mass:      M = T(8,8) / |GL(8,2)|^2 = sum_{classes} 1/|Stab|,  M_hat = mean(W) / |GL|^2.
#   A leaf of class K is reached with probability proportional to |orbit(K)|/W, so the
#   W-weighted share of leaves whose sigma is in the index estimates the mass share
#   of the known classes:
#     coverage c = sum(W_t * known_t) / sum(W_t)  (ratio estimator, delta-method SE),
#     M_cov = KNOWN_MASS / c,   N(cov) = M_cov + DELTA_KNOWN,   N(mass) = M_hat + DELTA_KNOWN.
#   N >= M + DELTA_KNOWN is the honest reading: unknown classes contribute at most 1 each.
#   sigma (ortho-derivative signature) is a CCZ invariant of quadratic APN functions; a
#   sigma absent from the index certifies a class absent from the indexed corpora.
#
# Pseudocode:
#   1. Read all lines; lw = logw + log e (or -Inf); keep every line in the denominator.
#      A compact manifest (data/legacy_chunks.tsv) gives the same lw and hits.
#   2. Mass estimate with standard error (helpers.jl: mass_estimate).
#   3. For each hit: decode, check differential uniformity 2, look up sigma_hash in the
#      ccz_sigma_index side store of VBFCatalog; mark known or collect as new.
#   4. Coverage, N estimates; write the distinct new sigma with one coefficient string.
# VBF API used: SBox, differential_uniformity
# VBFCatalog API used: sigma_hash, _open_sigma_index (ccz_sigma_index side store)

isdefined(@__MODULE__, :encode_coeffs) || include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog
const DBI = VBFCatalog.DBInterface

"""
    coverage_estimate(w, known) -> (c, se)

Weighted coverage `sum(w .* known) / sum(w)` with its delta-method standard error.
"""
function coverage_estimate(w::AbstractVector{Float64}, known::AbstractVector{Bool})
    N = length(w)
    x = w .* known
    c = sum(x) / sum(w)
    r = x .- c .* w
    sec = sqrt(sum(r .^ 2) / (N - 1) / N) / mean(w)
    c, sec
end

"""
    analyze_census(paths; new_path = nothing, io = stdout) -> NamedTuple

Analyze the (8,8) sample files `paths`. Writes the distinct new sigma
(`sigma_hash<TAB>coeffs`, sorted by hash) to `new_path` when given.
"""
function analyze_census(paths::AbstractVector{<:AbstractString};
                        new_path::Union{Nothing,AbstractString} = nothing, io::IO = stdout)
    t0 = time()
    labels = sample_labels(paths)
    lw, hits = read_samples(paths)
    N = length(lw)
    est = mass_estimate(lw, 8, 8)
    mx = maximum(lw)
    w = exp.(lw .- mx)

    idx = VBFCatalog._open_sigma_index()
    gaps = VBFCatalog._sigma_gaps(idx, 8)
    isempty(gaps) || @warn "sigma index has coverage gaps at n=8; 'new' is not certified" gaps
    known = falses(N)
    newsig = Dict{String,Vector{String}}()
    src = Dict{String,Int}()
    for (i, coeffs) in hits
        F = sbox_from_coeffs(coeffs, 8)
        differential_uniformity(F) == 2 || error("sample $i is not APN")
        h = VBFCatalog.sigma_hash(F)
        rows = [String(r.source) for r in DBI.execute(idx,
                "SELECT source FROM ccz_sigma_index WHERE sigma_hash='$h' LIMIT 1")]
        if isempty(rows)
            push!(get!(newsig, h, String[]), coeffs)
        else
            known[i] = true
            src[rows[1]] = get(src, rows[1], 0) + 1
        end
    end
    c, sec = coverage_estimate(w, known)
    Mcov = KNOWN_MASS / c
    seMcov = KNOWN_MASS * sec / c^2
    Ncov = Mcov + DELTA_KNOWN
    nh = length(hits)
    nk = count(known)
    nnew = length(newsig)

    print_section("Census analysis (8,8)", io)
    @printf(io, "files              %d (%s ... %s)\n", length(labels), first(labels), last(labels))
    length(labels) == length(paths) || println(io, "inputs             ", join(paths, ", "))
    @printf(io, "samples            %d\n", N)
    @printf(io, "APN hits           %d  (hit rate %.3e)\n", nh, nh / N)
    @printf(io, "mass estimate      %.4g ± %.3g  (%.1f%%)  batch-sd/sqrt(B)=%.3g  max-w/sum-w=%.2e\n",
            est.mass, est.se, 100est.se / est.mass, est.batch_se, est.max_share)
    @printf(io, "hits with known σ  %d / %d   by source: %s\n", nk, nh, string(sort(collect(src))))
    @printf(io, "weighted coverage  %.4f ± %.4f\n", c, sec)
    @printf(io, "mass from coverage %.4g ± %.3g ;  N >= mass + %.0f  ->  N(cov) = %.4g, N(mass) = %.4g\n",
            Mcov, seMcov, DELTA_KNOWN, Ncov, est.mass + DELTA_KNOWN)
    @printf(io, "distinct reference-absent σ     %d  (repeats among new: %d)  [σ absent from the index]\n",
            nnew, (nh - nk) - nnew)
    if new_path !== nothing
        mkpath(dirname(new_path))
        open(new_path, "w") do f
            for (h, cs) in sort(collect(newsig))
                println(f, h, '\t', cs[1])
            end
        end
        println(io, "reference-absent σ list         ", new_path)

    end
    @printf(io, "[%.1fs]\n", time() - t0)

    (files = length(labels), samples = N, hits = nh, hit_rate = nh / N,
     mass = est.mass, mass_se = est.se, mass_batch_se = est.batch_se,
     max_weight_share = est.max_share,
     known_hits = nk, known_by_source = src, coverage = c, coverage_se = sec,
     mass_from_coverage = Mcov, mass_from_coverage_se = seMcov,
     n_cov = Ncov, n_cov_se = seMcov, n_mass = est.mass + DELTA_KNOWN,
     n_mass_se = est.se, delta_known = DELTA_KNOWN, known_classes = KNOWN_CLASSES,
     known_mass = KNOWN_MASS, new_sigma = nnew, new_repeats = (nh - nk) - nnew,
     sigma_index_gaps = gaps)
end

"Print the mass estimate of arbitrary (n,m) sample files (no sigma lookup)."
function estimate_report(paths::AbstractVector{<:AbstractString}, n::Int, m::Int; io::IO = stdout)
    lw, _ = read_samples(paths)
    r = mass_estimate(lw, n, m)
    @printf(io, "(%d,%d) samples=%d hits=%d  mass=%.6g ± %.3g (%.2f%%)  batch-sd/sqrt(B)=%.3g  max-w/sum-w=%.2e\n",
            n, m, r.samples, r.hits, r.mass, r.se, 100r.se / r.mass, r.batch_se, r.max_share)
    if haskey(EXACT_MASS, (n, m))
        ex = Float64(EXACT_MASS[(n, m)])
        @printf(io, "  exact mass %.6f   z = %+.2f\n", ex, (r.mass - ex) / r.se)
    end
    r
end
