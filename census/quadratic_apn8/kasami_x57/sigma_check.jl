# Read degree-2 representatives (name, n, thickness, hex LUT) written by
# ccz_ea_classes.py --out, and check each against the σ index (classify_ccz)
# and against new_classes_553.tsv.
# Usage: julia --project=$ROOT sigma_check.jl QUAD.tsv
using VBF, VBFCatalog

path = ARGS[1]
new553 = Set(first(split(l, '\t')) for l in eachline(joinpath(@__DIR__, "..", "new_classes_553.tsv")))
rows = [split(l, '\t') for l in eachline(path) if !isempty(strip(l))]
isempty(rows) && println("no degree-2 representative in $path: nothing to check")
for r in rows
    name, n, th, h = r[1], parse(Int, r[2]), r[3], r[4]
    F = SBox{n}([parse(UInt8, h[2k-1:2k], base = 16) for k in 1:2^n])
    @assert algebraic_degree(F) == 2 && differential_uniformity(F) == 2
    s = VBFCatalog.sigma_hash(F)
    c = try
        VBFCatalog.classify_ccz(F)
    catch e
        "no index coverage for n = $n ($(sprint(showerror, e)[1:min(end, 80)]))"
    end
    println(name, "\tthickness=", th, "\tsigma=", s[1:16], "…\tclassify_ccz=", c,
            "\tin new_classes_553=", s in new553)
end
