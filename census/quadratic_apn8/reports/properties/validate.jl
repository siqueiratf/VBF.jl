# Validation of profiles_lib.jl.
# Usage: julia --project=/home/ts/VBF.jl validate.jl [nbeierle=300] [nbl=100]
using VBF, VBFCatalog, Random, Printf
include(joinpath(@__DIR__, "profiles_lib.jl")); using .Profiles
include(joinpath(@__DIR__, "..", "qknuth.jl")); using .QK
include(joinpath(@__DIR__, "..", "..", "..", "component_profiles.jl"))   # reference ranks

nbeierle = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 300
nbl = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 100
cat = VBFCatalog.load_catalog()
analyse(F) = (C = coeff_matrix_from_lut(F.lut); r = Profiles.component_ranks(C); a = component_alphas(r); (C, r, a))

println("== 1. decoding / rank cross-checks ==")
for line in Iterators.take(eachline(joinpath(@__DIR__, "..", "all40_new.tsv")), 5)
    cs = split(line, '\t')[2]; C = coeff_matrix(cs)
    F = SBox{8}(UInt8.(QK.lut(C, 8)))
    @assert Profiles.lut_from_matrix(C) == F.lut
    @assert coeff_matrix_from_lut(F.lut) == C
    r = Profiles.component_ranks(C)
    @assert all(r[b+1] == component_quadratic_rank(F, b) for b in 1:255)
    @assert sort([b for b in 1:255 if r[b+1] == 8]) == sort(filter(!=(0), bent_components(F)))
    @assert sum(component_alphas(r)) == 2^9 - 2          # Theorem 2.3 (APN, quadratic)
end
println("  5 new functions: QK.lut == own LUT, C recovered from LUT, ranks == component_quadratic_rank, bent set == VBF.bent_components, sum alpha = 510: OK")

println("== 2. README reference profiles (edelpott2009_n8) ==")
for (i, want) in [(1, "[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(50,102)]"),
                  (3, "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(50,102)]")]
    F = VBFCatalog.corpus_function(cat, "edelpott2009_n8", i)
    _, r, a = analyse(F)
    pl, _ = profile_pk(a, 6; order = :lex); pm, _ = profile_pk(a, 6; order = :bminK)
    @printf("  #%d ranks(8,6,4,2)=%s  lex=%s  bminK=%s  expected=%s  [%s/%s]\n", i, rank_counts(r)[1:4],
        fmt_profile(pl), fmt_profile(pm), want, fmt_profile(pl) == want ? "lex OK" : "lex differs",
        fmt_profile(pm) == want ? "bminK OK" : "bminK differs")
end

println("== 3. README outliers beierleleander2022_n8 #9172, #9624, #10320 ==")
for i in (9172, 9624, 10320)
    F = VBFCatalog.corpus_function(cat, "beierleleander2022_n8", i)
    _, r, a = analyse(F)
    pl, _ = profile_pk(a, 6; order = :lex); pm, _ = profile_pk(a, 6; order = :bminK)
    @printf("  #%d ranks=%s lex=%s bminK=%s\n", i, rank_counts(r)[1:4], fmt_profile(pl), fmt_profile(pm))
end

function tally(name, cnt, nsamp, rng)
    dl = Dict{String,Int}(); dm = Dict{String,Int}(); hyp = 0
    t = @elapsed for i in rand(rng, 1:cnt, nsamp)
        F = VBFCatalog.corpus_function(cat, name, i)
        _, r, a = analyse(F)
        pl, _ = profile_pk(a, 6; order = :lex); pm, _ = profile_pk(a, 6; order = :bminK)
        dl[fmt_profile(pl)] = get(dl, fmt_profile(pl), 0) + 1
        dm[fmt_profile(pm)] = get(dm, fmt_profile(pm), 0) + 1
    end
    @printf("  %s: %d random members, %.1f s\n", name, nsamp, t)
    for (lab, d) in (("lex", dl), ("bminK", dm))
        println("   order $lab:")
        for (p, c) in sort(collect(d), by = x -> -x[2]); println("     ", lpad(c, 5), "  ", p); end
    end
    dl, dm
end

println("== 4. random beierle2025_n8 members (expected: profile (3.7) with B6 >= 54) ==")
rng = Xoshiro(20250808)
dl, dm = tally("beierle2025_n8", 3_775_599, nbeierle, rng)
pref = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),"
ok37(p) = startswith(p, pref) && parse(Int, split(p[length(pref)+2:end], ',')[1]) >= 54
@printf("  satisfy (3.7) with B6>=54: lex %d/%d, bminK %d/%d\n",
    sum(c for (p, c) in dl if ok37(p); init = 0), nbeierle, sum(c for (p, c) in dm if ok37(p); init = 0), nbeierle)

println("== 5. random beierleleander2022_n8 members (Table 3.1 rows) ==")
tally("beierleleander2022_n8", 12_923, nbl, rng)
