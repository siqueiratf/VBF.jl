# Usage: julia --project=/home/ts/VBF.jl analyze_hits.jl OUTPREFIX files...
# (copy of ../analyze.jl; additionally writes OUTPREFIX_hits.tsv with every APN hit:
#  status (new/known), matched source, importance log-weight logw+log(e), coeffs)
# Mass estimate of quadratic (8,8)-APN EA-classes, weighted coverage by the known
# sigma index, and the list of sampled functions whose sigma is absent from the index.
using VBF, VBFCatalog, Printf, Statistics
include(joinpath(@__DIR__, "..", "qknuth.jl")); using .QK
const KNOWN = 3_808_491
const KNOWN_MASS = 3_799_974.1228   # sum 2^8/|Aut| over Table 5.2 (a)+(b)
const DELTA_KNOWN = KNOWN - KNOWN_MASS  # classes minus mass for the known classes
const DBI = VBFCatalog.DBInterface

outpre = ARGS[1]
lgl = 2 * Float64(log(QK.gl_order(8)))
lw = Float64[]; hits = Tuple{Int,String}[]   # (sample index, coeffs)
hitorig = Tuple{String,String}[]               # (file, sample id within file)
for f in ARGS[2:end], line in eachline(f)
    p = split(line, '\t'); e = parse(Int, p[3])
    if e == 0
        push!(lw, -Inf)
    else
        push!(lw, parse(Float64, p[2]) + log(e)); push!(hits, (length(lw), String(p[4]))); push!(hitorig, (basename(f), String(p[1])))
    end
end
N = length(lw); mx = maximum(lw); w = exp.(lw .- mx)
μ = mean(w); se = std(w) / sqrt(N); sc = exp(mx - lgl)
mass = sc * μ; semass = sc * se

function sbox_from(coeffs)
    c = [parse(UInt16, coeffs[2k-1:2k], base = 16) for k in 1:28]
    C = zeros(UInt16, 8, 8); t = 0
    for a in 1:8, b in a+1:8
        t += 1; C[a, b] = c[t]; C[b, a] = c[t]
    end
    SBox{8}(UInt8.(QK.lut(C, 8)))
end

idx = VBFCatalog._open_sigma_index()
known = falses(N); newsig = Dict{String,Vector{String}}(); src = Dict{String,Int}()
hitrows = Tuple{String,String,String,String}[]   # (status, source, sigma, coeffs) per hit
for (i, coeffs) in hits
    F = sbox_from(coeffs)
    differential_uniformity(F) == 2 || error("sample $i is not APN")
    h = VBFCatalog.sigma_hash(F)
    rows = [String(r.source) for r in DBI.execute(idx, "SELECT source FROM ccz_sigma_index WHERE sigma_hash='$h' LIMIT 1")]
    if isempty(rows)
        push!(get!(newsig, h, String[]), coeffs); push!(hitrows, ("new", "-", h, coeffs))
    else
        known[i] = true; src[rows[1]] = get(src, rows[1], 0) + 1; push!(hitrows, ("known", rows[1], h, coeffs))
    end
end
# weighted coverage c = sum(w*known)/sum(w) (ratio estimator, delta-method SE)
x = w .* known
c = sum(x) / sum(w)
r = x .- c .* w
sec = sqrt(sum(r .^ 2) / (N - 1) / N) / mean(w)
Mcov = KNOWN_MASS / c; seNcov = KNOWN_MASS * sec / c^2; Ncov = Mcov + DELTA_KNOWN
nh = length(hits); nk = count(known)
@printf("samples            %d\n", N)
@printf("APN hits           %d  (hit rate %.3e)\n", nh, nh / N)
@printf("mass estimate      %.4g ± %.3g  (%.1f%%)\n", mass, semass, 100semass / mass)
@printf("hits with known σ  %d / %d   by source: %s\n", nk, nh, string(src))
@printf("weighted coverage  %.4f ± %.4f\n", c, sec)
@printf("mass from coverage %.4g ± %.3g ;  N >= mass + %.0f  ->  N(cov) = %.4g, N(mass) = %.4g\n", Mcov, seNcov, DELTA_KNOWN, Ncov, mass + DELTA_KNOWN)
@printf("distinct new σ     %d  (repeats among new: %d)\n", length(newsig), (nh - nk) - length(newsig))
open(outpre * "_new.tsv", "w") do io
    for (h, cs) in sort(collect(newsig))
        println(io, h, '\t', cs[1])
    end
end
open(outpre * "_hits.tsv", "w") do io
    println(io, "global_idx\tfile\tsample_id\tstatus\tsource\tlogweight\tweight_rel\tsigma_hash\tcoeffs")
    for (k, (i, coeffs)) in enumerate(hits)
        st, so, h, cf = hitrows[k]
        @assert cf == coeffs
        @printf(io, "%d\t%s\t%s\t%s\t%s\t%.10f\t%.6e\t%s\t%s\n", i, hitorig[k][1], hitorig[k][2], st, so, lw[i], exp(lw[i] - mx), h, coeffs)
    end
end
