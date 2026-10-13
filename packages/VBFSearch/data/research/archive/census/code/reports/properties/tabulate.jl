# Profile distribution of new vs known hits, raw and importance-weighted.
# Usage: julia --project=/home/ts/VBF.jl tabulate.jl > tables.txt
using Printf
const NSAMPLES = 4_012_000          # s1.tsv + chunks/c1*.tsv (all non-hits have weight 0)
const NTOTAL = 5.5e6                # assumed total number of classes (task statement)
const TABLE31 = Set([
    "[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(50,102)]", "[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(52,96)]",
    "[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(54,90)]", "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(50,102)]",
    "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(52,96)]", "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(54,102)]",
    "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(54,90)]", "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(56,108)]",
    "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(56,84)]", "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(56,96)]",
    "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(58,78)]", "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(58,90)]",
    "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(60,72)]", "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(60,84)]"])

rows = [split(l, '\t') for l in eachline(joinpath(@__DIR__, "hit_properties.tsv"))]
hdr = rows[1]; rows = rows[2:end]; c(n) = findfirst(==(n), hdr)
lw = [parse(Float64, r[c("logweight")]) for r in rows]
w = exp.(lw .- maximum(lw)); W = sum(w); mw = W / NSAMPLES
isnew = [r[c("status")] == "new" for r in rows]

# ratio estimators with delta-method SE over all NSAMPLES (non-hits contribute w = 0)
function ratio(x, y)   # sum(x)/sum(y), x,y over hits
    cc = sum(x) / sum(y); rr = x .- cc .* y
    cc, sqrt(sum(rr .^ 2) / (NSAMPLES - 1) / NSAMPLES) / (sum(y) / NSAMPLES)
end

short(p) = replace(p, "[(0,0),(1,1),(3,3),(7,7),(15,15)," => "[..,")
function lv(p, i)   # pair at level i (0-based)
    m = collect(eachmatch(r"\((\d+),(\d+)\)", p)); (parse(Int, m[i+1][1]), parse(Int, m[i+1][2]))
end
function category(p)
    l4 = lv(p, 4); l5 = lv(p, 5); B6 = lv(p, 6)[1]
    l4 != (15, 15) && return "no (15,15) at level 4"
    l5 != (30, 34) && return "level 5 = $(l5)  (not (3.7))"
    B6 < 54 && return "(3.7) with B6 <= 52"
    B6 == 54 && return "(3.7) with B6 = 54"
    return "(3.7) with B6 >= 56"
end

function table(keyf, title; tbl31 = false)
    keys = [keyf(r) for r in rows]
    ks = sort(unique(keys))
    println("\n### ", title)
    println("| key | new | known | wfrac all (±se) | est. classes | wfrac known within key (±se) | new share of all new (w) |", tbl31 ? " in Tab3.1 |" : "")
    println("|---|---:|---:|---:|---:|---:|---:|", tbl31 ? "---|" : "")
    Wn = sum(w[isnew])
    for k in ks
        m = keys .== k
        f, sf = ratio(w .* m, w)
        kn, skn = ratio(w .* m .* .!isnew, w .* m)
        @printf("| %s | %d | %d | %.4f ± %.4f | %.3g | %.3f ± %.3f | %.4f |%s\n", short(k), count(m .& isnew), count(m .& .!isnew),
            f, sf, f * NTOTAL, kn, skn, sum(w[m .& isnew]) / Wn, tbl31 ? (k in TABLE31 ? " yes |" : " no |") : "")
    end
    @printf("| total | %d | %d | 1 | %.3g | %.3f | 1 |%s\n", count(isnew), count(.!isnew), NTOTAL, sum(w[.!isnew]) / W, tbl31 ? " |" : "")
end

println("Hits: $(length(rows)) ($(count(isnew)) new, $(count(.!isnew)) known); samples $NSAMPLES; est. classes = wfrac x $(NTOTAL)")
println("Overall weighted known fraction: ", round(sum(w[.!isnew]) / W, digits = 4))
table(r -> "ranks(8,6,4,2)=($(r[c("r8")]),$(r[c("r6")]),$(r[c("r4")]),$(r[c("r2")]))", "Rank distribution of the 255 nonzero components")
for (o, col) in (("lex  (maximize b, then maximize K)", "P6_lex"), ("bminK (maximize b, then minimize K)", "P6_bminK"))
    table(r -> r[c(col)], "P6 under order $o"; tbl31 = true)
    table(r -> category(r[c(col)]), "Search-branch categories under order $o")
    table(r -> "level5=" * string(lv(r[c(col)], 5)), "Level-5 entry under order $o")
    table(r -> "B6=" * string(lv(r[c(col)], 6)[1]), "B6 under order $o")
end
table(r -> "lex " * short(r[c("P6_lex")]) * " / bminK " * short(r[c("P6_bminK")]), "Joint (lex, bminK) profile")
table(r -> "maxdim=$(r[c("max_bent_dim")])", "Maximum dimension of an all-bent subspace of Comp(F)")
println("\nNumber of 4-dim all-bent subspaces: new min/median/max = ",
    let v = sort([parse(Int, r[c("n_bent_spaces_maxdim")]) for r in rows[isnew]]); (v[1], v[(end+1)÷2], v[end]) end,
    "; known min/median/max = ",
    let v = sort([parse(Int, r[c("n_bent_spaces_maxdim")]) for r in rows[.!isnew]]); (v[1], v[(end+1)÷2], v[end]) end)
