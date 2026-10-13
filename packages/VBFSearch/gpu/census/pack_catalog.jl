# pack_catalog.jl <in_text.txt> [out.anf]
# Convert a decimal-text quadratic-APN catalog (one JSON array of 256 ints per line)
# into the compact lossless .anf format (37 bytes/function; ~24× smaller). After
# packing you can delete the large text file — the .anf reconstructs every LUT.
include(joinpath(@__DIR__, "..", "..", "..", "VBFRepro", "src", "202606-kuznetsov-groebner-search", "anf.jl"))
using .ANF

if length(ARGS) < 1
    println("usage: julia pack_catalog.jl <in_text.txt> [out.anf]")
    exit(1)
end
in_path  = ARGS[1]
out_path = length(ARGS) >= 2 ? ARGS[2] : replace(in_path, r"\.[^.]*$" => "") * ".anf"

t = @elapsed (count, skipped) = ANF.pack_text_file(in_path, out_path)
insz = filesize(in_path); outsz = filesize(out_path)
println("packed $count functions ($skipped non-quadratic skipped) in $(round(t;digits=1))s")
println("  $in_path  $(round(insz/1e6;digits=1)) MB")
println("  $out_path  $(round(outsz/1e6;digits=1)) MB  ($(round(insz/outsz;digits=1))× smaller)")
