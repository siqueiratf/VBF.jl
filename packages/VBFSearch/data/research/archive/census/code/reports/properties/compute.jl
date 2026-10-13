# Per-hit component properties.
# Usage: julia --project=/home/ts/VBF.jl compute.jl   (reads all40_hits.tsv, writes hit_properties.tsv)
using VBF, Printf
include(joinpath(@__DIR__, "profiles_lib.jl")); using .Profiles
include(joinpath(@__DIR__, "..", "qknuth.jl")); using .QK

lines = collect(eachline(joinpath(@__DIR__, "all40_hits.tsv")))
hdr = split(lines[1], '\t'); col(n) = findfirst(==(n), hdr)
out = open(joinpath(@__DIR__, "hit_properties.tsv"), "w")
println(out, join(["global_idx", "status", "source", "logweight", "r8", "r6", "r4", "r2",
    "P6_lex", "P6_bminK", "nmax_lex", "nmax_bminK", "max_bent_dim", "n_bent_spaces_maxdim", "sigma_hash", "coeffs"], '\t'))
t0 = time()
for (k, line) in enumerate(lines[2:end])
    p = split(line, '\t')
    C = coeff_matrix(p[col("coeffs")])
    F = SBox{8}(UInt8.(QK.lut(C, 8)))
    differential_uniformity(F) == 2 || error("not APN")
    r = Profiles.component_ranks(C); a = component_alphas(r)
    rc = rank_counts(r); rc[5] == 0 || error("rank-0 component")
    sum(a) == 510 || error("Theorem 2.3 violated")
    pl, nl = profile_pk(a, 6; order = :lex)
    pm, nm = profile_pk(a, 6; order = :bminK)
    d, nd = max_bent_subspace_dim(a)
    println(out, join([p[col("global_idx")], p[col("status")], p[col("source")], p[col("logweight")],
        rc[1], rc[2], rc[3], rc[4], fmt_profile(pl), fmt_profile(pm), join(nl, ','), join(nm, ','),
        d, nd, p[col("sigma_hash")], p[col("coeffs")]], '\t'))
    k % 200 == 0 && (@printf(stderr, "%d done, %.1f s\n", k, time() - t0); flush(out))
end
close(out)
@printf(stderr, "all done, %.1f s\n", time() - t0)
