# Export the distinct σ of the May 2025 raw file that are absent from the σ index.
#   julia --project=$ROOT export_raw_only.jl
# Input:  not_in_index_apn-11888039-may-2025-8.out.tsv (and the .txt.gz file as a control)
# Output: raw_only_546.tsv (sigma_hash, first record number, LUT hex; one line per σ)
# Checks: σ recomputed with VBFCatalog.sigma_hash; differential uniformity 2; degree 2;
#         σ pairwise distinct; no σ in the index (direct SQL, any n); disjoint from the 553.
using VBF, VBFCatalog
const DBInterface = VBFCatalog.DBInterface
const D = @__DIR__
const ROOT = normpath(joinpath(D, "..", "..", ".."))

function read_misses(f)
    rows = Tuple{Int,String,String}[]
    for (k, l) in enumerate(eachline(f))
        k == 1 && continue
        a = split(l, '\t'); push!(rows, (parse(Int, a[1]), String(a[2]), String(a[3])))
    end
    rows
end

out = read_misses(joinpath(D, "not_in_index_apn-11888039-may-2025-8.out.tsv"))
txt = read_misses(joinpath(D, "not_in_index_apn-11888039-may-2025-8.txt.gz.tsv"))
first_rec = Dict{String,Tuple{Int,String}}()
for (r, h, lut) in sort(out)
    haskey(first_rec, h) || (first_rec[h] = (r, lut))
end
println("records not in index: .out ", length(out), ", .txt.gz ", length(txt))
println("distinct σ: .out ", length(first_rec), ", .txt.gz ", length(unique(x[2] for x in txt)))
println("same σ set in both files: ", Set(keys(first_rec)) == Set(x[2] for x in txt))
println(".txt.gz line = .out record + 1 for every miss: ",
        sort([x[1] for x in txt]) == sort([x[1] + 1 for x in out]))

new553 = Set(split(l, '\t')[1] for l in eachline(joinpath(ROOT, "census", "quadratic_apn8", "new_classes_553.tsv")) if !isempty(strip(l)))
idx = VBFCatalog._open_sigma_index()
bad = 0; insql = 0; recomputed = String[]
for (h, (r, lut)) in first_rec
    F = SBox{8,UInt8}(hex2bytes(lut))
    h2 = VBFCatalog.sigma_hash(F)
    push!(recomputed, h2)
    (h2 == h && differential_uniformity(F) == 2 && algebraic_degree(F) == 2) || (global bad += 1)
    n = length(collect(DBInterface.execute(idx, "SELECT n FROM ccz_sigma_index WHERE sigma_hash = ?", (h,))))
    global insql += n
end
println("recomputed σ = stored σ, APN, degree 2: ", length(first_rec) - bad, " / ", length(first_rec))
println("pairwise distinct recomputed σ: ", length(unique(recomputed)) == length(recomputed))
println("index rows (any n) for these σ: ", insql)
println("intersection with the 553: ", length(intersect(Set(keys(first_rec)), new553)))

ord = sort(collect(first_rec); by = x -> x[2][1])
open(joinpath(D, "raw_only_$(length(ord)).tsv"), "w") do io
    println(io, "sigma_hash\tfirst_record\tlut_hex")
    for (h, (r, lut)) in ord
        println(io, h, '\t', r, '\t', lut)
    end
end
println("wrote raw_only_$(length(ord)).tsv")
