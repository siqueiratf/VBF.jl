# Implements admissible selections versus realizable restrictions pi|_H (HYPERPLANE.md, Sec. 3)
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8/theory)
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

isdefined(@__MODULE__, :check_uniqueness) || include(joinpath(@__DIR__, "..", "check_uniqueness.jl"))

using Random, Printf

"Radicals: rad[b] = nonzero points alpha of H with b in W_alpha (Rad(G_b) minus 0)."
function radicals(W, nv::Int, m::Int)
    rad = [Int[] for _ in 1:(1 << m) - 1]
    for α in 1:(1 << nv) - 1, b in W[α]
        push!(rad[b], α)
    end
    rad
end

mask_of(pts) = (x = UInt128(0); for p in pts; x |= UInt128(1) << (p - 1); end; x)

"Options of b as point masks: the whole radical, then every hyperplane (minus 0)."
function options(pts::Vector{Int})
    isempty(pts) && return UInt128[]
    basis = Int[]
    piv = UInt64[]
    for p in pts
        insert_row!(piv, UInt64(p)) && push!(basis, p)
    end
    d = length(basis)
    # coordinates: element k of span (k in 1:2^d-1) = xor of basis[i] with bit i-1 of k
    el = zeros(Int, 1 << d)
    for k in 1:(1 << d) - 1
        t = trailing_zeros(k)
        el[k + 1] = el[(k ⊻ (1 << t)) + 1] ⊻ basis[t + 1]
    end
    opts = UInt128[mask_of(pts)]
    for λ in 1:(1 << d) - 1
        push!(opts, mask_of([el[k + 1] for k in 1:(1 << d) - 1 if iseven(count_ones(λ & k))]))
    end
    opts
end

"""
    count_admissible(C, nv, m; cap) -> (count::BigInt, exact::Bool, info)

Number of admissible selections. `exact = false` means the node cap was hit and `count`
is a lower bound.
"""
function count_admissible(C::Matrix{UInt16}, nv::Int, m::Int; cap::Int = 2_000_000)
    W = annihilators(C, nv, m)
    rad = radicals(W, nv, m)
    npts = (1 << nv) - 1
    big_b = [b for b in eachindex(rad) if length(rad[b]) >= 3]       # dim >= 2
    c1 = zeros(Int, npts)                                            # dim-1 radicals per point
    for b in eachindex(rad)
        length(rad[b]) == 1 && (c1[rad[b][1]] += 1)
    end
    opts = [filter(!iszero, options(rad[b])) for b in big_b]
    # order: fewest options first
    perm = sortperm(length.(opts))
    opts = opts[perm]
    full = (UInt128(1) << npts) - 1
    nodes = Ref(0)
    hit = Ref(false)
    function leafval(covered)
        v = big(1)
        rest = full & ~covered
        while rest != 0
            p = trailing_zeros(rest) + 1
            rest &= rest - 1
            c1[p] == 0 && return big(0)
            v *= c1[p]
        end
        v
    end
    function rec(i, covered)
        nodes[] += 1
        if nodes[] > cap
            hit[] = true
            return big(0)
        end
        i > length(opts) && return leafval(covered)
        tot = big(0)
        for o in opts[i]
            o & covered == 0 || continue
            tot += rec(i + 1, covered | o)
            hit[] && return tot
        end
        tot
    end
    cnt = rec(1, UInt128(0))
    hist = Dict{Int,Int}()
    for b in eachindex(rad)
        d = round(Int, log2(length(rad[b]) + 1))
        hist[d] = get(hist, d, 0) + 1
    end
    (cnt, !hit[], (big = length(big_b), rad_dims = sort(collect(hist)), nodes = nodes[]))
end

"GF(2) rank of BitVector rows."
function bv_rank(rows::Vector{BitVector})
    piv = Dict{Int,BitVector}()
    r = 0
    for v0 in rows
        v = copy(v0)
        while true
            l = findlast(v)
            l === nothing && break
            if haskey(piv, l)
                v .⊻= piv[l]
            else
                piv[l] = v
                r += 1
                break
            end
        end
    end
    r
end

"(|P|, dim ker eps, dim K_loc) for G."
function relation_dims(C::Matrix{UInt16}, nv::Int, m::Int)
    W = annihilators(C, nv, m)
    rad = radicals(W, nv, m)
    P = Tuple{Int,Int}[]
    for b in eachindex(rad), α in rad[b]
        push!(P, (α, b))
    end
    idx = Dict(p => i for (i, p) in enumerate(P))
    # rank of eps
    piv = UInt64[]
    for (α, b) in P
        row = UInt64(0)
        for i in 1:nv
            (α >> (i - 1)) & 1 == 1 || continue
            for k in 1:m
                (b >> (k - 1)) & 1 == 1 && (row |= UInt64(1) << ((i - 1) * m + k - 1))
            end
        end
        insert_row!(piv, row)
    end
    reps = length(piv)
    rels = BitVector[]
    for α in 1:(1 << nv) - 1                       # row relations
        v = falses(length(P))
        for b in W[α]
            v[idx[(α, b)]] = true
        end
        push!(rels, v)
    end
    for b in eachindex(rad)                         # line relations inside Rad_b
        s = Set(rad[b])
        for a1 in rad[b], a2 in rad[b]
            a1 < a2 && (a1 ⊻ a2) in s && a2 < (a1 ⊻ a2) || continue
            v = falses(length(P))
            v[idx[(a1, b)]] = v[idx[(a2, b)]] = v[idx[(a1 ⊻ a2, b)]] = true
            push!(rels, v)
        end
    end
    (length(P), length(P) - reps, bv_rank(rels))
end

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
    out = joinpath(@__DIR__, "results", "admissible.tsv")
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
            tsv = readlines(joinpath(@__DIR__, "..", "results", "uniq_n8.tsv"))[2:end]
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
            e, _ = FL3.count_completions(C, n - 1, n)
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

"""
    estimate_admissible(C, nv, m; probes, rng) -> (mean, se)

Knuth estimate (METHOD.md, Theorem 3.5) of the number of admissible selections, on the
same backtracking tree as `count_admissible` (levels = the b with dim Rad_b >= 2).
"""
function estimate_admissible(C::Matrix{UInt16}, nv::Int, m::Int; probes::Int = 2000,
                             rng = Xoshiro(1), drop_whole::Bool = false)
    W = annihilators(C, nv, m)
    rad = radicals(W, nv, m)
    npts = (1 << nv) - 1
    big_b = [b for b in eachindex(rad) if length(rad[b]) >= 3]
    c1 = zeros(Int, npts)
    for b in eachindex(rad)
        length(rad[b]) == 1 && (c1[rad[b][1]] += 1)
    end
    opts = [filter(!iszero, options(rad[b])) for b in big_b]
    # drop_whole: valid when sum of minimal option sizes = number of points (n = 7: every b
    # must take a single point, HYPERPLANE.md Lemma 3.5)
    drop_whole && (opts = [o[2:end] for o in opts])
    full = (UInt128(1) << npts) - 1
    ws = Float64[]
    for _ in 1:probes
        covered = UInt128(0)
        w = 1.0
        for i in eachindex(opts)
            ok = [o for o in opts[i] if o & covered == 0]
            if isempty(ok)
                w = 0.0
                break
            end
            w *= length(ok)
            covered |= ok[rand(rng, 1:length(ok))]
        end
        if w > 0
            rest = full & ~covered
            while rest != 0
                p = trailing_zeros(rest) + 1
                rest &= rest - 1
                w *= c1[p]
            end
        end
        push!(ws, w)
    end
    μ = sum(ws) / probes
    (μ, sqrt(sum((ws .- μ) .^ 2) / (probes - 1) / probes))
end

"Knuth estimates of the admissible count for the n = 7 and n = 8 pairs of admissible.tsv."
function admissible_estimates(; probes::Int = 2000, seed::Int = 2, io::IO = stdout)
    rng = Xoshiro(seed)
    recs = [split(l, '\t') for l in readlines(joinpath(@__DIR__, "results", "admissible.tsv"))[2:end]]
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
