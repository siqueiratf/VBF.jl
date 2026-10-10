# Write the LUTs of the test functions to data/luts.tsv (name, n, hex LUT).
# Catalog rows: 43, 581, 634 (x^57 class), 41 (Gold x^3), 40 (Calderini, quadratic).
# VBF constructions: Dillon APN permutation and Kim function (n = 6).
using VBF, VBFCatalog
const DBI = VBFCatalog.DBInterface

out = joinpath(@__DIR__, "../../../../data/apn/runs/power-ccz/luts.tsv")
mkpath(dirname(out))
hexlut(F) = join(string(Int(F.lut[x + 1]), base = 16, pad = 2) for x in 0:length(F.lut) - 1)
cat = VBFCatalog.load_catalog()
rows = Tuple{String,Int,String}[]
for r in DBI.execute(cat, "SELECT id, n, canonical_name, lut_blob FROM functions WHERE id IN (43, 581, 634, 41, 40) ORDER BY id")
    F = VBFCatalog._sbox_from_blob(Vector{UInt8}(r.lut_blob), Int(r.n))
    push!(rows, ("catalog_$(r.id)_$(r.canonical_name)", Int(r.n), hexlut(F)))
end
push!(rows, ("vbf_dillon_apn_permutation", 6, hexlut(dillon_apn_permutation())))
push!(rows, ("vbf_kim_apn", 6, hexlut(kim_apn())))
open(out, "w") do io
    for (name, n, h) in rows
        println(io, name, '\t', n, '\t', h)
    end
end
println("wrote $(length(rows)) rows to $out")
