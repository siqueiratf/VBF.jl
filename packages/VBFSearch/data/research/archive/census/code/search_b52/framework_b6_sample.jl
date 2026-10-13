# B6 (P6 profile, bminK order) of a random sample of the classes in a search run.
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8/search_b52)
#
# The search records B6 only for search-new classes. This script calculates P6 for a random
# sample of the known classes of a run (and of the search-new classes, as a control: the
# calculated B6 must equal the recorded B6). It gives the B6 distribution of the known
# classes that the search reaches.
#
# Usage: julia --project=<root> -t <threads> framework_b6_sample.jl <found.tsv> <n_known> <n_new> <seed> <out.tsv>
# VBF API used: none (profiles_lib.jl works on the coefficient matrix)

using Random, Printf, Base.Threads
include(joinpath(@__DIR__, "..", "reports", "properties", "profiles_lib.jl")); using .Profiles

found, nk, nn, seed, outp = ARGS[1], parse(Int, ARGS[2]), parse(Int, ARGS[3]), parse(Int, ARGS[4]), ARGS[5]
rows = [split(l, '\t') for l in Iterators.drop(eachline(found), 1)]
known = [r for r in rows if r[2] == "known"]
new = [r for r in rows if r[2] == "search"]
rng = Xoshiro(seed)
sample = vcat(known[randperm(rng, length(known))[1:min(nk, end)]], new[randperm(rng, length(new))[1:min(nn, end)]])
res = Vector{String}(undef, length(sample))
@threads for i in eachindex(sample)
    r = sample[i]
    C = coeff_matrix(String(r[6]))
    a = component_alphas(Profiles.component_ranks(C))
    p, _ = profile_pk(a, 6; order = :bminK)
    res[i] = join([r[1], r[2], r[5], fmt_profile(p), string(p[end][1])], '\t')
end
open(outp, "w") do io
    println(io, "sigma\tstatus\tb6_recorded\tP6_bminK\tb6_calc")
    foreach(l -> println(io, l), res)
end
