using VBF
# Implements admissible selections versus realizable restrictions pi|_H (HYPERPLANE.md, Sec. 3)
# Study: census of quadratic APN functions on F_2^8 (packages/VBFSearch/data/research/archive/census/theory)
# Source: HYPERPLANE.md; UNIQUENESS.md (Phi, ker Phi, pi|_H); Beierle et al. (2025, v2) Thm 4.1
#
# Math:
#   G quadratic APN on H = F_2^(n-1), outputs W = F_2^n. Rad_b = Rad(G_b); T_alpha = {b != 0 :
#   alpha in Rad_b} has 3 elements. A selection pi(alpha) in T_alpha is ADMISSIBLE when every
#   R_b = pi^{-1}(b) + {0} is Rad_b or a hyperplane of Rad_b. Admissible selections are exact
#   covers of H\0 by one option per b (option = Rad_b\0 or (hyperplane of Rad_b)\0), where every
#   b with dim Rad_b >= 2 must take a nonempty option and b with dim Rad_b = 1 may take nothing.
#   Realizable selections (pi_F|_H of an APN extension) number e / |ker Phi| <= #admissible.
#   Linear view: P = {(alpha,b): alpha in Rad_b \ 0}; eps: F_2^P -> H (x) W, (alpha,b) -> alpha (x) b.
#   Realizable <=> lambda_pi orthogonal to ker eps; admissible <=> lambda_pi orthogonal to K_loc
#   (row relations at each alpha and line relations inside each Rad_b). K_loc <= ker eps.
#
# Pseudocode:
#   For each (F, u) pair: G = F|_H; radicals; options; count exact covers by backtracking over
#   the b with dim Rad_b >= 2 (each must choose a nonempty option, pairwise disjoint), times
#   the product over uncovered points of the number of b with Rad_b = {0, p} (0 if none).
#   Node cap: report a lower bound when the cap is hit. Also dim ker eps, dim K_loc.
# VBF API used: via ../check_uniqueness.jl (SBox, is_quadratic_apn); VBFCatalog: load_catalog,
#   corpus_function

isdefined(@__MODULE__, :check_uniqueness) || include(joinpath(@__DIR__, "check_uniqueness.jl"))

using Random, Printf

using VBF.QuadraticRestrictions
using VBF.QuadraticRestrictions: radicals, options

"""
    admissible_report(; ns = 4:8, n7_per_class = 3, n8_sample = 100, cap, seed, io)

Compare admissible counts with e/|ker Phi| on the pairs of check_uniqueness:
n <= 6 all pairs, n = 7 `n7_per_class` random hyperplanes per class, n = 8 all pairs of
theory/results/uniq_n8.tsv with e > 128 plus `n8_sample` pairs with e = 128.
Writes hyperplane_theory/results/admissible.tsv.
"""
function admissible_report(; ns = 4:8, n7_per_class::Int = 3, n8_sample::Int = 100,
                           cap::Int = 2_000_000, seed::Int = 1, io::IO = stdout)
    rng = Xoshiro(seed)
    out = joinpath(@__DIR__, "../../../../packages/VBFPaper/doc/generated/hyperplanes/admissible.tsv")
    mkpath(dirname(out))
    db = VBFCatalog.load_catalog()
    rows = String[]
    for n in ns
        pairs = Tuple{String,Int,Vector{Int},Int}[]
        if n <= 7
            for (src, id, lut) in catalog_reps(n)
                us = n <= 6 ? collect(1:(1 << n) - 1) : randperm(rng, (1 << n) - 1)[1:n7_per_class]
                append!(pairs, [(src, id, lut, u) for u in us])
            end
        else
            tsv = readlines(joinpath(@__DIR__, "../../../../packages/VBFSearch/data/research/archive/census/theory/results/uniq_n8.tsv"))[2:end]
            recs = [split(l, '\t') for l in tsv]
            big_e = [r for r in recs if parse(Int, r[4]) > 128]
            small = [r for r in recs if parse(Int, r[4]) == 128]
            sel = vcat(big_e, small[randperm(rng, length(small))[1:min(n8_sample, length(small))]])
            for r in sel
                src = String(r[1]); i = parse(Int, r[2]); u = parse(Int, r[3])
                F = src == "gold_x3" ? gold_apn(8, 1) : src == "gold_x9" ? gold_apn(8, 3) :
                    VBFCatalog.corpus_function(db, src, i)
                push!(pairs, (src, i, lut_of(F), u))
            end
        end
        res = Vector{Any}(undef, length(pairs))
        Threads.@threads :dynamic for k in eachindex(pairs)
            src, id, lut, u = pairs[k]
            C = restrict_coeffs(lut, hyperplane_basis(u, n))
            e, _ = VBF.QuadraticAPNTree.count_completions(C, n - 1, n)
            W = annihilators(C, n - 1, n)
            kd = ker_phi_dim(W, n - 1, n)
            cnt, exact, info = count_admissible(C, n - 1, n; cap)
            np, ke, kl = relation_dims(C, n - 1, n)
            res[k] = (src, id, u, e, kd, e ÷ (1 << kd), cnt, exact, info, np, ke, kl)
        end
        for r in res
            push!(rows, join((n, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8],
                              string(r[9].rad_dims), r[10], r[11], r[12]), '\t'))
        end
        nreal = [r[6] for r in res]
        eq = count(r -> r[8] && r[7] == r[6], res)
        lt = count(r -> r[7] > r[6], res)
        @printf(io, "n=%d pairs=%d  realizable(e/|kerPhi|) range %d..%d  admissible exact in %d pairs\n",
                n, length(res), minimum(nreal), maximum(nreal), count(r -> r[8], res))
        @printf(io, "   admissible == realizable: %d   admissible > realizable: %d\n", eq, lt)
        adm = [r[7] for r in res if r[8]]
        isempty(adm) || @printf(io, "   admissible (exact) range %s .. %s\n", string(minimum(adm)), string(maximum(adm)))
        println(io, "   (|P|, dim ker eps, dim K_loc) histogram: ", hist((r[10], r[11], r[12]) for r in res))
        println(io, "   radical-dimension types: ", hist(string(r[9].rad_dims) for r in res))
        flush(io)
    end
    open(out, "w") do f
        println(f, "n\tsource\tidx\tu\te\tdim_ker_phi\trealizable\tadmissible\tadmissible_exact\trad_dims\tP\tdim_ker_eps\tdim_K_loc")
        foreach(r -> println(f, r), rows)
    end
    println(io, "wrote ", out)
end

"Knuth estimates of the admissible count for the n = 7 and n = 8 pairs of admissible.tsv."
function admissible_estimates(; probes::Int = 2000, seed::Int = 2, io::IO = stdout)
    rng = Xoshiro(seed)
    recs = [split(l, '\t') for l in readlines(joinpath(@__DIR__, "../../../../packages/VBFSearch/data/research/archive/census/theory/hyperplane_theory/results/admissible.tsv"))[2:end]]
    db = VBFCatalog.load_catalog()
    reps7 = Dict(id => lut for (_, id, lut) in catalog_reps(7))
    for n in (7, 8)
        est = Float64[]; real = Int[]
        for r in recs
            parse(Int, r[1]) == n || continue
            src = String(r[2]); i = parse(Int, r[3]); u = parse(Int, r[4])
            lut = n == 7 ? reps7[i] :
                  lut_of(src == "gold_x3" ? gold_apn(8, 1) : src == "gold_x9" ? gold_apn(8, 3) :
                         VBFCatalog.corpus_function(db, src, i))
            C = restrict_coeffs(lut, hyperplane_basis(u, n))
            μ, _ = estimate_admissible(C, n - 1, n; probes, rng, drop_whole = n == 7)
            push!(est, μ); push!(real, parse(Int, r[7]))
        end
        lg = log10.(est)
        @printf(io, "n=%d pairs=%d  Knuth estimate of #admissible: log10 min %.2f median %.2f max %.2f; realizable max %d\n",
                n, length(est), minimum(lg), sort(lg)[cld(length(lg), 2)], maximum(lg), maximum(real))
    end
end
