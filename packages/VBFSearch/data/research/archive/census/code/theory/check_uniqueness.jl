# Implements the hyperplane-restriction experiment for the e ∈ {0, 2^(n-1)} conjecture
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8/theory)
# Source: Beierle et al. (2025, v2), Theorem 4.1 and Lemma 4.5; UNIQUENESS.md
#
# Math:
#   Let F be a quadratic APN (n,n)-function and H = ker(u) a hyperplane of F_2^n. Choose a
#   basis a_1..a_{n-1} of H. The restriction G = F|_H has the pure quadratic coefficients
#     c_ij = F(a_i + a_j) + F(a_i) + F(a_j) + F(0)   (i < j <= n-1).
#   F is an APN extension of G, so e(G) = #{valid L} >= |Lambda| = 2^(n-1).
#   Phi(L) = (L(alpha) mod I_alpha)_alpha; ker Phi = {L : L(alpha) in I_alpha for all alpha};
#   e(G) = |ker Phi| * (number of distinct pi_F|_H over the APN extensions F).
#   Conjecture (n = 8): e(G) = 128 for every such G.
#
# Pseudocode:
#   1. Build the list of functions (n = 8: corpus members and Gold; n = 6, 7: catalog CCZ
#      class representatives that are quadratic APN).
#   2. Build the (F, u) pairs: n = 8: `hpf` random nonzero u per function (distinct);
#      n = 6, 7 with exhaustive = true: every nonzero u.
#   3. For each pair (threaded): basis of H, coefficients C of G, e = FL3 count,
#      dim ker Phi by Gaussian elimination, rank distributions of F and G.
#      If crosscheck (or e > 2^(n-1)): list the canonical solutions and count the distinct
#      restrictions pi|_H; compare with e / |ker Phi|.
#   4. Print histograms; write theory/results/uniq_n<n>.tsv.
# VBF API used: SBox (field lut), gold_apn, is_quadratic_apn, differential_uniformity
# VBFCatalog API used: load_catalog, corpus_function, corpus_length, sigma_hash, DBInterface

isdefined(@__MODULE__, :QK) || include(joinpath(@__DIR__, "..", "qknuth.jl"))
isdefined(@__MODULE__, :FL3) || include(joinpath(@__DIR__, "..", "fastlast.jl"))

using VBF
using VBFCatalog
using Random
using Printf
using Base.Threads

# ---------------------------------------------------------------- linear algebra

"Insert `r` into an F_2 echelon basis with distinct leading bits; return true if independent."
function insert_row!(piv::Vector{UInt64}, r0::UInt64)
    r = r0
    for p in piv
        r = min(r, r ⊻ p)
    end
    r == 0 && return false
    push!(piv, r)
    sort!(piv; rev = true)
    true
end

f2rank(rows) = (piv = UInt64[]; count(r -> insert_row!(piv, UInt64(r)), rows))

"Basis of H = ker(u): e_j + u_j e_p for j != p, where p is the lowest set bit of u."
function hyperplane_basis(u::Int, n::Int)
    p = trailing_zeros(u)
    [(1 << j) ⊻ (((u >> j) & 1) << p) for j in 0:n - 1 if j != p]
end

d2(lut, a, b) = UInt16(lut[(a ⊻ b) + 1] ⊻ lut[a + 1] ⊻ lut[b + 1] ⊻ lut[1])

"Pure quadratic coefficients of F restricted to span(basis), in the coordinates of basis."
function restrict_coeffs(lut::AbstractVector, basis::Vector{Int})
    k = length(basis)
    C = zeros(UInt16, k, k)
    for i in 1:k, j in i + 1:k
        C[i, j] = C[j, i] = d2(lut, basis[i], basis[j])
    end
    C
end

"Component rank histogram of the pure quadratic function C (nv inputs, m outputs): ranks nv..0."
function rank_hist(C::Matrix{UInt16}, nv::Int, m::Int)
    h = zeros(Int, nv + 1)               # h[r+1] = number of b with rank r
    for b in 1:(1 << m) - 1
        rows = UInt64[]
        for i in 1:nv
            r = UInt64(0)
            for j in 1:nv
                isodd(count_ones(UInt16(b) & C[i, j])) && (r |= UInt64(1) << (j - 1))
            end
            push!(rows, r)
        end
        h[f2rank(rows) + 1] += 1
    end
    # report even ranks from the top: (nv_even, nv_even-2, ..., 0)
    top = iseven(nv) ? nv : nv - 1
    Tuple(h[r + 1] for r in top:-2:0)
end

"Nonzero annihilator W_alpha \\ 0 of I_alpha for every alpha (sorted)."
function annihilators(C::Matrix{UInt16}, nv::Int, m::Int)
    I = QK.images(C, nv, m)
    I === nothing && return nothing
    W = Vector{Vector{UInt16}}(undef, (1 << nv) - 1)
    for α in 1:(1 << nv) - 1
        bas = [I[α][(1 << t) + 1] for t in 0:nv - 2]      # basis of I_alpha (dim nv-1)
        W[α] = [UInt16(w) for w in 1:(1 << m) - 1 if all(y -> iseven(count_ones(w & y)), bas)]
    end
    W
end

"dim ker Phi = dim { L : w . L(alpha) = 0 for all alpha != 0, w in I_alpha^perp }."
function ker_phi_dim(W, nv::Int, m::Int)
    nv * m <= 64 || error("nv*m > 64")
    piv = UInt64[]
    for α in 1:(1 << nv) - 1, w in W[α]
        row = UInt64(0)
        for i in 1:nv
            (α >> (i - 1)) & 1 == 1 || continue
            for k in 1:m
                (w >> (k - 1)) & 1 == 1 && (row |= UInt64(1) << ((i - 1) * m + k - 1))
            end
        end
        insert_row!(piv, row)
    end
    nv * m - length(piv)
end

"""
Number of distinct restrictions pi|_H over the canonical solutions `sols`
(pi(alpha) = the unique w in W_alpha with w . L(alpha) = 0).
"""
function distinct_pi(W, sols, nv::Int)
    keys = Set{Vector{UInt16}}()
    for L in sols
        key = Vector{UInt16}(undef, (1 << nv) - 1)
        for α in 1:(1 << nv) - 1
            v = UInt16(0)
            for i in 1:nv
                (α >> (i - 1)) & 1 == 1 && (v ⊻= L[i])
            end
            ann = [w for w in W[α] if iseven(count_ones(w & v))]
            length(ann) == 1 || error("solution is not valid at alpha=$α")
            key[α] = ann[1]
        end
        push!(keys, key)
    end
    length(keys)
end

# ---------------------------------------------------------------- function sources

lut_of(F) = Int.(F.lut)

"Catalog CCZ class representatives of dimension n that are quadratic APN."
function catalog_reps(n::Int)
    db = VBFCatalog.load_catalog()
    q = "SELECT f.id, f.lut_blob FROM equivalence_classes e JOIN functions f " *
        "ON f.id = e.canonical_id WHERE e.kind='CCZ' AND e.n=$n"
    out = Tuple{String,Int,Vector{Int}}[]
    for r in VBFCatalog.DBInterface.execute(db, q)
        F = SBox{n}(collect(Vector{UInt8}(r.lut_blob)))
        is_quadratic_apn(F) || continue
        push!(out, ("catalog_ccz_n$n", Int(r.id), lut_of(F)))
    end
    out
end

# Share of the n = 8 functions per corpus (the remainder goes to beierle2025_n8);
# small corpora are taken completely.
const N8_SHARES = [("beierleleander2022_n8", 0.10), ("beierleleanderperrin2022_n8", 0.08),
                   ("yuperrin2022_qam_n8", 0.08), ("yuwangli2014_qam_n8", 0.08)]
const N8_SMALL = ["edelpott2009_n8", "taniguchi2019_n8", "wengtangong2013_n8"]

function n8_functions(nfun::Int, rng)
    db = VBFCatalog.load_catalog()
    out = Tuple{String,Int,Vector{Int}}[]
    push!(out, ("gold_x3", 1, lut_of(gold_apn(8, 1))))
    push!(out, ("gold_x9", 3, lut_of(gold_apn(8, 3))))
    for name in N8_SMALL, i in 1:VBFCatalog.corpus_length(db, name)
        push!(out, (name, i, lut_of(VBFCatalog.corpus_function(db, name, i))))
    end
    rest = max(nfun - length(out), 0)
    used = 0
    for (name, share) in N8_SHARES
        k = round(Int, share * rest)
        cnt = VBFCatalog.corpus_length(db, name)
        for i in randperm(rng, cnt)[1:min(k, cnt)]
            push!(out, (name, i, lut_of(VBFCatalog.corpus_function(db, name, i))))
        end
        used += min(k, cnt)
    end
    cnt = VBFCatalog.corpus_length(db, "beierle2025_n8")
    for i in rand(rng, 1:cnt, rest - used)
        push!(out, ("beierle2025_n8", i, lut_of(VBFCatalog.corpus_function(db, "beierle2025_n8", i))))
    end
    out
end

# ---------------------------------------------------------------- main experiment

struct PairResult
    src::String
    idx::Int
    u::Int
    e::Int
    kdim::Int
    npi::Int          # distinct pi|_H from the solution list; -1 = not computed
    nsig::Int         # distinct sigma among the canonical extensions; -1 = not computed
    nsame::Int        # canonical extensions with sigma(extension) == sigma(F); -1 = not computed
    frank::Tuple
    grank::Tuple
    secs::Float64
end

"""
Sigma hashes of the APN extensions G + x_n L for the canonical solutions `sols`.
"""
function extension_sigmas(C::Matrix{UInt16}, sols, n::Int)
    nv = n - 1
    out = String[]
    for L in sols
        D = zeros(UInt16, n, n)
        D[1:nv, 1:nv] = C
        for k in 1:nv
            D[k, n] = D[n, k] = L[k]
        end
        S = SBox{n}(UInt8.(QK.lut(D, n)))
        differential_uniformity(S) == 2 || error("extension is not APN")
        push!(out, VBFCatalog.sigma_hash(S))
    end
    out
end

function run_pair(fun, u::Int, n::Int, crosscheck::Bool, classify::Bool)
    src, idx, lut = fun
    t = @elapsed begin
        basis = hyperplane_basis(u, n)
        nv = n - 1
        C = restrict_coeffs(lut, basis)
        W = annihilators(C, nv, n)
        W === nothing && error("restriction of $src[$idx] to u=$u is not APN")
        e, _ = FL3.count_completions(C, nv, n)
        e >= (1 << nv) || error("e < 2^(n-1) for $src[$idx], u=$u: F is an extension")
        kd = ker_phi_dim(W, nv, n)
        npi = nsig = nsame = -1
        if crosscheck || e > (1 << nv)
            _, sols = FL3.count_completions(C, nv, n; want_solution = true)
            npi = distinct_pi(W, sols, nv)
            if classify && e > (1 << nv)
                sF = VBFCatalog.sigma_hash(SBox{n}(UInt8.(lut)))
                sg = extension_sigmas(C, sols, n)
                nsig = length(unique(sg))
                nsame = count(==(sF), sg)
            end
        end
        Cf = restrict_coeffs(lut, [1 << j for j in 0:n - 1])
        fr = rank_hist(Cf, n, n)
        gr = rank_hist(C, nv, n)
    end
    PairResult(src, idx, u, e, kd, npi, nsig, nsame, fr, gr, t)
end

"""
    check_uniqueness(; n = 8, samples = 5000, hpf = 5, seed = 1, exhaustive = true,
                     crosscheck = n <= 7, classify = n == 8, io = stdout) -> Vector{PairResult}

n = 8: about `samples` (F, H) pairs, `hpf` random hyperplanes per function.
n = 6, 7: all catalog classes; every hyperplane when `exhaustive`, else `hpf` random ones.
`classify`: for pairs with e > 2^(n-1), compare the sigma of every canonical extension with
the sigma of F (sigma differs => the extension is CCZ-inequivalent to F).
"""
function check_uniqueness(; n::Int = 8, samples::Int = 5000, hpf::Int = 5, seed::Int = 1,
                          exhaustive::Bool = true, crosscheck::Bool = n <= 7,
                          classify::Bool = n == 8, io::IO = stdout)
    rng = Xoshiro(seed)
    funs = n == 8 ? n8_functions(cld(samples, hpf), rng) : catalog_reps(n)
    pairs = Tuple{Int,Int}[]
    for (fi, _) in enumerate(funs)
        us = (n < 8 && exhaustive) ? collect(1:(1 << n) - 1) :
             randperm(rng, (1 << n) - 1)[1:hpf]
        append!(pairs, [(fi, u) for u in us])
    end
    @printf(io, "n=%d functions=%d pairs=%d threads=%d crosscheck=%s seed=%d\n",
            n, length(funs), length(pairs), nthreads(), crosscheck, seed)
    flush(io)
    res = Vector{PairResult}(undef, length(pairs))
    done = Atomic{Int}(0)
    t0 = time()
    @threads :dynamic for k in eachindex(pairs)
        fi, u = pairs[k]
        res[k] = run_pair(funs[fi], u, n, crosscheck, classify)
        d = atomic_add!(done, 1) + 1
        if d % 500 == 0
            @printf(io, "  %d / %d pairs [%.0fs]\n", d, length(pairs), time() - t0)
            flush(io)
        end
    end
    summarize(res, n, io)
    outdir = joinpath(@__DIR__, "results")
    mkpath(outdir)
    path = joinpath(outdir, "uniq_n$(n).tsv")
    open(path, "w") do f
        println(f, "source\tidx\tu\te\tdim_ker_phi\tdistinct_pi\tdistinct_sigma\tsame_sigma_as_F\tF_ranks\tG_ranks\tseconds")
        for r in res
            @printf(f, "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%.4f\n", r.src, r.idx, r.u, r.e,
                    r.kdim, r.npi, r.nsig, r.nsame, join(r.frank, ","), join(r.grank, ","), r.secs)
        end
    end
    println(io, "wrote ", path, @sprintf("  [%.1fs]", time() - t0))
    res
end

function hist(v)
    d = Dict{Any,Int}()
    for x in v
        d[x] = get(d, x, 0) + 1
    end
    sort(collect(d); by = first)
end

function summarize(res::Vector{PairResult}, n::Int, io::IO)
    lam = 1 << (n - 1)
    println(io, "\n## Results n=$n  (|Lambda| = $lam)")
    println(io, "pairs                     ", length(res))
    println(io, "distinct functions        ", length(unique((r.src, r.idx) for r in res)))
    println(io, "e histogram               ", hist(r.e for r in res))
    println(io, "e / 2^(n-1) histogram     ", hist(r.e ÷ lam for r in res))
    println(io, "dim ker Phi histogram     ", hist(r.kdim for r in res))
    println(io, "e / |ker Phi| histogram   ", hist(r.e ÷ (1 << r.kdim) for r in res))
    cc = [r for r in res if r.npi >= 0]
    if !isempty(cc)
        ok = count(r -> r.npi == r.e ÷ (1 << r.kdim), cc)
        println(io, "crosscheck distinct pi|_H == e/|ker Phi|:  $ok / $(length(cc))")
    end
    println(io, "pairs with e > 2^(n-1)    ", count(r -> r.e > lam, res))
    cl = [r for r in res if r.nsig >= 0]
    if !isempty(cl)
        println(io, "classified pairs (e > 2^(n-1)): (canonical extensions, distinct sigma, sigma == sigma(F)) histogram")
        println(io, "                          ", hist((r.e ÷ lam, r.nsig, r.nsame) for r in cl))
        println(io, "functions with some e > 2^(n-1): ",
                hist(r.src for r in unique(r -> (r.src, r.idx), cl)))
    end
    println(io, "by source                 ",
            [(s, length(v), maximum(r.e for r in v)) for (s, v) in
             sort(collect(Dict(s => [r for r in res if r.src == s] for s in unique(r.src for r in res))); by = first)])
    println(io, "F rank types (count)      ", hist(r.frank for r in res))
    println(io, "G rank types (count)      ", hist(r.grank for r in res))
    println(io, "(F type, G type) -> e/|ker Phi| histogram:")
    groups = Dict{Any,Vector{Int}}()
    for r in res
        push!(get!(groups, (r.frank, r.grank), Int[]), r.e ÷ (1 << r.kdim))
    end
    for (key, v) in sort(collect(groups); by = first)
        println(io, "  F=", key[1], "  G=", key[2], "  pairs=", length(v), "  ", hist(v))
    end
    @printf(io, "time per pair: mean %.3fs, max %.3fs\n",
            sum(r.secs for r in res) / length(res), maximum(r.secs for r in res))
    flush(io)
end

# ---------------------------------------------------------------- single-pair inspection

"Coefficient string of a pure quadratic function (c_ij, i < j, row order, 2 hex digits)."
coeff_string(C::Matrix{UInt16}, k::Int) =
    join([string(C[a, b], base = 16, pad = 2) for a in 1:k for b in a + 1:k])

"""
    inspect_pair(src, idx, u; aut = true, io = stdout)

Details of one (F, H = ker u) pair at n = 8: the coefficients of G = F|_H, every canonical
extension L, its sigma, whether the sigma is in the VBFCatalog index (and its source),
and |Aut| of F and of every extension (`aut = true`, ortho-derivative method).
`src` is a corpus name or "gold_x3" / "gold_x9".
"""
function inspect_pair(src::AbstractString, idx::Int, u::Int; aut::Bool = true, io::IO = stdout)
    n = 8
    db = VBFCatalog.load_catalog()
    F = src == "gold_x3" ? gold_apn(8, 1) : src == "gold_x9" ? gold_apn(8, 3) :
        VBFCatalog.corpus_function(db, src, idx)
    lut = lut_of(F)
    basis = hyperplane_basis(u, n)
    C = restrict_coeffs(lut, basis)
    e, sols = FL3.count_completions(C, n - 1, n; want_solution = true)
    W = annihilators(C, n - 1, n)
    println(io, "pair ", src, "[", idx, "]  u = ", u, "  H basis = ", basis)
    println(io, "  G coefficients (7 vars)  ", coeff_string(C, n - 1))
    println(io, "  e = ", e, "  dim ker Phi = ", ker_phi_dim(W, n - 1, n),
            "  distinct pi|_H = ", distinct_pi(W, sols, n - 1))
    idxdb = VBFCatalog._open_sigma_index()
    sF = VBFCatalog.sigma_hash(F)
    if aut
        t = @elapsed a = length(automorphisms_from_ortho_derivative(F))
        @printf(io, "  F: sigma %s  |Aut| = %d  [%.1fs]\n", sF, a, t)
    else
        println(io, "  F: sigma ", sF)
    end
    for (s, L) in enumerate(sols)
        D = zeros(UInt16, n, n)
        D[1:n - 1, 1:n - 1] = C
        for k in 1:n - 1
            D[k, n] = D[n, k] = L[k]
        end
        S = SBox{n}(UInt8.(QK.lut(D, n)))
        h = VBFCatalog.sigma_hash(S)
        rows = [String(r.source) for r in VBFCatalog.DBInterface.execute(idxdb,
                "SELECT source FROM ccz_sigma_index WHERE sigma_hash='$h' LIMIT 1")]
        a = aut ? length(automorphisms_from_ortho_derivative(S)) : -1
        println(io, "  extension ", s, ": L = ", string.(L, base = 16, pad = 2),
                "  du = ", differential_uniformity(S), "  sigma ", h,
                h == sF ? " (= sigma(F))" : "", "  index: ",
                isempty(rows) ? "absent" : rows[1], aut ? "  |Aut| = $a" : "")
        println(io, "     coeffs (8 vars) ", coeff_string(D, n))
    end
    flush(io)
    nothing
end
