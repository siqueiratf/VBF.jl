# Write the control LUTs and decoder reference LUTs to data/controls.tsv (name, n, hex LUT).
#   kim_apn (n = 6, quadratic, CCZ-equivalent to the Dillon permutation): expect true
#   dillon_apn_permutation (n = 6): expect true
#   Gold x^3 (catalog id 41, n = 8): expect false
#   decoder_<k>: the first 3 functions of new_classes_553.tsv, decoded with
#   sbox_from_coeffs (helpers.jl), to check the Python decoder.
using VBF, VBFCatalog
const DBI = VBFCatalog.DBInterface
include(joinpath(@__DIR__, "../census/helpers.jl"))

hexlut(F) = join(string(Int(F.lut[x + 1]), base = 16, pad = 2) for x in 0:length(F.lut) - 1)
cat = VBFCatalog.load_catalog()
r = first(DBI.execute(cat, "SELECT lut_blob FROM functions WHERE id = 41"))
gold = VBFCatalog._sbox_from_blob(Vector{UInt8}(r.lut_blob), 8)
rows = [("control_true_kim_apn", 6, hexlut(kim_apn())),
        ("control_true_dillon_apn_permutation", 6, hexlut(dillon_apn_permutation())),
        ("control_false_gold_x3_n8", 8, hexlut(gold))]
for (k, line) in enumerate(Iterators.take(eachline(joinpath(@__DIR__, "../../../../data/apn/archive/census/new_classes_553.tsv")), 3))
    h, coeffs = split(line, '\t')
    push!(rows, ("decoder_$(h)", 8, hexlut(sbox_from_coeffs(coeffs, 8))))
end
mkpath(joinpath(@__DIR__, "../../../../data/apn/runs/controls"))
open(joinpath(@__DIR__, "../../../../data/apn/runs/controls/controls.tsv"), "w") do io
    for (name, n, h) in rows
        println(io, name, '\t', n, '\t', h)
    end
end
println("wrote $(length(rows)) rows")
