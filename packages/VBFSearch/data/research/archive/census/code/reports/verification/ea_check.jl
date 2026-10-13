# Task 4 — positive control for the "known" direction.
# Uniform random sample of 30 known hits (seed 20261008) from regen_known.tsv,
# plus (supplementary) every known hit whose match is NOT in beierle2025_n8.
# For each: rebuild F from coeffs, load the matched index member G
# (corpus_function or functions-table row), check sigma(F) == sigma(G) == stored,
# then decide EA-equivalence exactly: ea_mappings_from_ortho_derivative(F, G)
# non-empty <=> EA-equivalent (= CCZ for quadratic APN).
# Negative controls (shard 0 only): F vs a sigma-DIFFERENT member must give no mapping.
# Usage: julia --project=/home/ts/VBF.jl ea_check.jl SHARD NSHARDS
using VBF, VBFCatalog, Random, Printf
include(joinpath(@__DIR__, "..", "qknuth.jl")); using .QK
const DBI = VBFCatalog.DBInterface
shard, nshards = parse(Int, ARGS[1]), parse(Int, ARGS[2])
cat = VBFCatalog.load_catalog()
function sbox_from(coeffs)      # identical to analyze.jl
    c = [parse(UInt16, coeffs[2k-1:2k], base = 16) for k in 1:28]
    C = zeros(UInt16, 8, 8); t = 0
    for a in 1:8, b in a+1:8
        t += 1; C[a, b] = c[t]; C[b, a] = c[t]
    end
    SBox{8}(UInt8.(QK.lut(C, 8)))
end
rows = [split(l, '\t') for l in Iterators.drop(eachline(joinpath(@__DIR__, "regen_known.tsv")), 1)]
sel = sort(randperm(MersenneTwister(20261008), length(rows))[1:30])
supp = [i for i in eachindex(rows) if rows[i][4] != "beierle2025_n8" && !(i in sel)]
jobs = vcat([(i, "random30") for i in sel], [(i, "supplementary_nonB2025") for i in supp])
out = joinpath(@__DIR__, "ea_results_shard$(shard).tsv")
open(out, "w") do io
    println(io, "set\trow\tsample_idx\tsource\tmember_idx\tsigma_F_eq_stored\tsigma_G_eq_stored\tn_mappings\tequivalent\tseconds")
end
function getG(src, mi)
    src == "functions" || return VBFCatalog.corpus_function(cat, src, mi)
    blob = first(DBI.execute(cat, "SELECT lut_blob FROM functions WHERE id = $mi")).lut_blob
    VBFCatalog._sbox_from_blob(Vector{UInt8}(blob), 8)
end
for (k, (i, set)) in enumerate(jobs)
    (k - 1) % nshards == shard || continue
    r = rows[i]; F = sbox_from(String(r[2])); h = String(r[3]); src = String(r[4]); mi = parse(Int, r[5])
    G = getG(src, mi)
    sF = VBFCatalog.sigma_hash(F) == h; sG = VBFCatalog.sigma_hash(G) == h
    t = @elapsed maps = ea_mappings_from_ortho_derivative(F, G)
    line = join([set, i, r[1], src, mi, sF, sG, length(maps), !isempty(maps), round(t, digits = 1)], '\t')
    open(io -> println(io, line), out, "a"); println(line); flush(stdout)
end
if shard == 0
    # negative controls: pair F with a member of a DIFFERENT sigma; must return no mapping
    for (a, b) in ((sel[1], sel[2]), (sel[3], sel[4]))
        F = sbox_from(String(rows[a][2])); G = getG(String(rows[b][4]), parse(Int, rows[b][5]))
        t = @elapsed maps = ea_mappings_from_ortho_derivative(F, G)
        line = join(["negative_control", "$a-vs-$b", rows[a][1], rows[b][4], rows[b][5],
                     VBFCatalog.sigma_hash(F) == rows[a][3], VBFCatalog.sigma_hash(G) == rows[a][3], length(maps), !isempty(maps), round(t, digits = 1)], '\t')
        open(io -> println(io, line), out, "a"); println(line); flush(stdout)
    end
end
