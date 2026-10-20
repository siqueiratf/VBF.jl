# Pilot step 1 (local): write every maximal anchor of one seed for the GPU scan.
# File format, one anchor per line: need, then the 7 basis forms in hex.
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/pilot_export.jl n10_BeierleLeander2022_3
include(joinpath(@__DIR__, "anchors_n10.jl"))

name = ARGS[1]
db = load_catalog()
F = load_sbox(db, name)
C = comp_basis(Int.(F.lut))
M7, na, anchors, _ = all_best_anchors(C; keep = typemax(Int))
out = joinpath(@__DIR__, "results", "$name.anchors")
mkpath(dirname(out))
open(out, "w") do io
    for V in anchors
        need = target_b8(C, V) - count(is_bent, span(V))
        println(io, need, " ", join(string.(V; base = 16), " "))
    end
end
println("$name: M_7 = $M7, anchors = $na, written to $out")
