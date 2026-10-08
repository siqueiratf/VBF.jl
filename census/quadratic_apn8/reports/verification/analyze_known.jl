# Usage: julia --project=/home/ts/VBF.jl analyze.jl OUTPREFIX files...
# Mass estimate of quadratic (8,8)-APN EA-classes, weighted coverage by the known
# sigma index, and the list of sampled functions whose sigma is absent from the index.
using VBF, VBFCatalog, Printf, Statistics
include(joinpath(@__DIR__, "..", "qknuth.jl")); using .QK  # verification copy: path made relative to the original folder
const KNOWN = 3_808_491
const KNOWN_MASS = 3_799_974.1228   # sum 2^8/|Aut| over Table 5.2 (a)+(b)
const DELTA_KNOWN = KNOWN - KNOWN_MASS  # classes minus mass for the known classes
const DBI = VBFCatalog.DBInterface

outpre = ARGS[1]
lgl = 2 * Float64(log(QK.gl_order(8)))
lw = Float64[]; hits = Tuple{Int,String}[]   # (sample index, coeffs)
for f in ARGS[2:end], line in eachline(f)
    p = split(line, '\t'); e = parse(Int, p[3])
    if e == 0
        push!(lw, -Inf)
    else
        push!(lw, parse(Float64, p[2]) + log(e)); push!(hits, (length(lw), String(p[4])))
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
knownhits = Tuple{Int,String,String,String,Int,Int}[]   # verification addition: (sample idx, coeffs, sigma, source, member_idx, n index rows)
for (i, coeffs) in hits
    F = sbox_from(coeffs)
    differential_uniformity(F) == 2 || error("sample $i is not APN")
    h = VBFCatalog.sigma_hash(F)
    rows = [String(r.source) for r in DBI.execute(idx, "SELECT source FROM ccz_sigma_index WHERE sigma_hash='$h' LIMIT 1")]
    # verification addition: the same first matching row, with member_idx, and the total row count
    if !isempty(rows)
        r1 = first(DBI.execute(idx, "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash='$h' LIMIT 1"))
        nr = first(DBI.execute(idx, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE sigma_hash='$h'")).c
        push!(knownhits, (i, coeffs, h, String(r1.source), Int(r1.member_idx), Int(nr)))
    end
    if isempty(rows)
        push!(get!(newsig, h, String[]), coeffs)
    else
        known[i] = true; src[rows[1]] = get(src, rows[1], 0) + 1
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

# verification addition: write the known hits
open(outpre * "_known.tsv", "w") do io
    println(io, "sample_idx\tcoeffs\tsigma_hash\tsource\tmember_idx\tindex_rows_with_sigma")
    for (i, co, h, s_, mi, nr) in knownhits
        println(io, i, '\t', co, '\t', h, '\t', s_, '\t', mi, '\t', nr)
    end
end
