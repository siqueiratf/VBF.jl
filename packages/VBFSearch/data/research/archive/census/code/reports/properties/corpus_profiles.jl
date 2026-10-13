# P6 (order bminK and lex) of random members of a catalog corpus.
# Usage: julia --project=/home/ts/VBF.jl corpus_profiles.jl CORPUS COUNT NSAMPLE SEED
using VBF, VBFCatalog, Random, Printf
include(joinpath(@__DIR__, "profiles_lib.jl")); using .Profiles
name = ARGS[1]; cnt = parse(Int, ARGS[2]); ns = parse(Int, ARGS[3]); seed = parse(Int, ARGS[4])
cat = VBFCatalog.load_catalog(); rng = Xoshiro(seed)
dm = Dict{String,Int}(); dl = Dict{String,Int}()
t = @elapsed for i in rand(rng, 1:cnt, ns)
    F = VBFCatalog.corpus_function(cat, name, i)
    a = component_alphas(Profiles.component_ranks(coeff_matrix_from_lut(F.lut)))
    pm = fmt_profile(profile_pk(a, 6; order = :bminK)[1]); dm[pm] = get(dm, pm, 0) + 1
    pl = fmt_profile(profile_pk(a, 6; order = :lex)[1]); dl[pl] = get(dl, pl, 0) + 1
end
@printf("%s: %d random members (seed %d), %.1f s\n", name, ns, seed, t)
for (lab, d) in (("bminK", dm), ("lex", dl))
    println(" order $lab:")
    for (p, c) in sort(collect(d), by = x -> -x[2]); @printf("   %6d  %.4f  %s\n", c, c / ns, p); end
end
