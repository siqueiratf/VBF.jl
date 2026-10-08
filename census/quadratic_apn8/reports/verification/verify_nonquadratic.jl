# Task 2 — non-quadratic n=8 APN rows of the catalog functions table.
# For each: recompute degree/du, then decide whether its CCZ class contains a
# quadratic function with VBF.ccz_equivalent_quadratic_function (scans every EA
# class of the CCZ class, i.e. every n-dim subspace of the Walsh-zero set).
# If a quadratic member exists, compute its sigma and test it against the 553
# claimed-new hashes and against the index.
# Usage: julia --project=/home/ts/VBF.jl verify_nonquadratic.jl
using VBF, VBFCatalog, Printf
const DBI = VBFCatalog.DBInterface
cat = VBFCatalog.load_catalog(); idx = VBFCatalog._open_sigma_index()
new553 = Set(String(split(l, '\t')[1]) for l in eachline(joinpath(@__DIR__, "..", "all40_new.tsv")))
rows = [(Int(r.id), String(r.canonical_name), Vector{UInt8}(r.lut_blob)) for r in DBI.execute(cat,
        "SELECT id, canonical_name, lut_blob FROM functions WHERE n = 8 AND is_apn = 1 AND is_quadratic = 0 ORDER BY id")]
println("non-quadratic n=8 APN rows in functions: ", length(rows))
for (id, nm, blob) in rows
    F = VBFCatalog._sbox_from_blob(blob, 8)
    @printf("\nid=%d %s  deg=%d du=%d perm=%s\n", id, nm, algebraic_degree(F), differential_uniformity(F), is_permutation(F))
    Z = walsh_zeroes(F)
    println("  walsh zeros (incl. 0?): ", length(Z))
    t = @elapsed cls = enumerate_ccz_class(F)
    degs = [algebraic_degree(f) for f in cls]
    @printf("  enumerate_ccz_class: %d EA-class representatives in %.1fs; degree histogram %s\n",
            length(cls), t, string(sort([(d, count(==(d), degs)) for d in unique(degs)])))
    q = findfirst(==(2), degs)
    if q === nothing
        println("  VERDICT: CCZ class contains NO quadratic function (ccz_equivalent_quadratic_function would return nothing)")
    else
        G = cls[q]; h = VBFCatalog.sigma_hash(G)
        inidx = first(DBI.execute(idx, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE sigma_hash = '$h'")).c
        println("  VERDICT: quadratic member found; sigma=$h in553=$(h in new553) index_rows=$inidx")
    end
    flush(stdout)
end
