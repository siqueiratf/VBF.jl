# generate_rows.jl <n> <class_idx>
# Generic basis-bin generator. Writes basis_n<n>_c<class>_rows.bin in bilinear-row
# form (n_free × n UInt64) — the encoding consumed by apn_search_ultra (n=8) and
# apn_search_n7 (n=7) and by fast_checker. dim(V_A) = n_free = search space 2^n_free.
include(joinpath(@__DIR__, "va_generic.jl"))
using .VAGeneric

if length(ARGS) < 2
    println("usage: julia generate_rows.jl <n> <class_idx>")
    exit(1)
end
n = parse(Int, ARGS[1])
class_idx = parse(Int, ARGS[2])
out = "basis_n$(n)_c$(class_idx)_rows.bin"
nf = write_rows_bin(out, n, class_idx)
println("wrote $out : n_free=$nf  (dim V_A=$nf, search space 2^$nf)")
