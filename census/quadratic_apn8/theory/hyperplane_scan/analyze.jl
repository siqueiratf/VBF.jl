# Implements the analysis of the hyperplane scan (results/functions.tsv, results/pairs.tsv)
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8/theory)
# Source: ../UNIQUENESS.md (Proposition 2.1, orbit formula 6.1)
#
# Math:
#   k(F, H) = e(F|_H) / 2^7. n_gt1(F) = #{H : k(F, H) > 1}. For g in Aut(F) (an
#   affine equivalence F -> F), k(F, H) = k(F, gH), so n_gt1(F) is a union of
#   Aut(F)-orbits on hyperplanes.
#   Invariants of F that we compare with n_gt1: component rank counts (r8, r6, r4, r2),
#   the P6 profile (bminK order, Beierle et al. 2025 Def. 3.4) and the sigma family
#   (the set of indexed sources that contain sigma(F), or the census list of F).
#
# Pseudocode:
#   1. Read the function rows and the coset rows (only cosets of complete functions).
#   2. Per source: pair rate of k > 1, k histogram, functions with n_gt1 > 0,
#      histogram of n_gt1.
#   3. P6 (cached in results/p6.tsv, threaded) and sigma family (sigma index queries).
#      Group n_gt1 by rank type, by b6 (bent count of the best 6-dim subspace) and by
#      family; Spearman correlation of n_gt1 with r4, b6, K6 (r8 = 170 + 4 r4 and
#      r2 = 0 for every scanned function, so r4 carries the rank information).
#      Share of n_gt1 values divisible by 3 (a hint of an order-3 automorphism).
#   4. Cosets: status counts (sigma = sigma(F) or other); the indexed source of the
#      "other, known" extensions; pairs with exactly one coset of sigma(F).
#   5. NEW classes: deduplicate by sigma, verify (rebuild from coeffs, du = 2, same sigma,
#      absent from the index and from the lists), write ../new_classes_hyperplane.tsv.
#   6. Yield: distinct NEW classes per thread-hour (sum of per-function seconds).
#   7. Write results/analysis.md (markdown tables).
# VBF API used: SBox, differential_uniformity
# VBFCatalog API used: sigma_hash, _open_sigma_index, DBInterface

isdefined(@__MODULE__, :scan_function) || include(joinpath(@__DIR__, "scan.jl"))

using Statistics

kval(c::Char) = c == '#' ? 36 : parse(Int, c; base = 36)

struct FRow
    src::String
    mem::Int
    sigma::String
    status::String
    ranks::NTuple{4,Int}
    ngt1::Int
    ks::Vector{Int}
    secs::Float64
end

function read_functions(path)
    out = FRow[]
    seen = Set{Tuple{String,Int}}()
    for (i, l) in enumerate(eachline(path))
        i == 1 && continue
        good_function_row(l) || continue
        p = split(l, '\t')
        key = (String(p[1]), parse(Int, p[2]))
        key in seen && continue
        push!(seen, key)
        r = Tuple(parse.(Int, split(p[5], ',')))
        push!(out, FRow(p[1], parse(Int, p[2]), p[3], p[4], r, parse(Int, p[6]),
                        kval.(collect(p[7])), parse(Float64, p[8])))
    end
    out
end

function read_pairs(path, done)
    out = NamedTuple[]
    seen = Set{Tuple{String,Int,Int,Int}}()
    for (i, l) in enumerate(eachline(path))
        i == 1 && continue
        p = split(l, '\t')
        length(p) == 10 || continue
        key = (String(p[1]), parse(Int, p[2]))
        key in done || continue
        pk = (key[1], key[2], parse(Int, p[3]), parse(Int, p[5]))
        pk in seen && continue
        push!(seen, pk)
        push!(out, (src = key[1], mem = key[2], u = parse(Int, p[3]), k = parse(Int, p[4]),
                    coset = parse(Int, p[5]), du = parse(Int, p[6]), sigma = String(p[7]),
                    status = String(p[8]), same = p[9] == "1", coeffs = String(p[10])))
    end
    out
end

# ---------------------------------------------------------------- invariants

"P6 profile (bminK) of every function; cached in results/p6.tsv."
function p6_table(fr::Vector{FRow}; dir = HS_RESULTS, io = stdout)
    path = joinpath(dir, "p6.tsv")
    cache = Dict{Tuple{String,Int},String}()
    if isfile(path)
        for l in eachline(path)
            p = split(l, '\t'); length(p) == 3 || continue
            cache[(String(p[1]), parse(Int, p[2]))] = String(p[3])
        end
    end
    todo = [(r.src, r.mem) for r in fr if !haskey(cache, (r.src, r.mem))]
    if !isempty(todo)
        println(io, "computing P6 for ", length(todo), " functions (", nthreads(), " threads)")
        res = Vector{String}(undef, length(todo))
        t = @elapsed @threads :dynamic for i in eachindex(todo)
            src, mem = todo[i]
            lut = Int.(member_lut(src, mem))
            C = Profiles.coeff_matrix_from_lut(lut)
            a = Profiles.component_alphas(Profiles.component_ranks(C))
            res[i] = Profiles.fmt_profile(Profiles.profile_pk(a, 6; order = :bminK)[1])
        end
        open(path, "a") do f
            for (i, key) in enumerate(todo)
                println(f, key[1], '\t', key[2], '\t', res[i])
                cache[key] = res[i]
            end
        end
        @printf(io, "P6 done in %.0f s\n", t)
    end
    cache
end

"(b6, K6) = last pair of a P6 string."
function b6k6(p6::AbstractString)
    m = match(r"\((\d+),(\d+)\)\]$", p6)
    parse(Int, m[1]), parse(Int, m[2])
end

"Sigma family of F: the sorted indexed sources that contain sigma(F), else the census list."
function families(fr::Vector{FRow})
    idx = VBFCatalog._open_sigma_index()
    fam = Dict{String,String}()
    for r in fr
        haskey(fam, r.sigma) && continue
        srcs = sort(unique(String(x.source) for x in VBFCatalog.DBInterface.execute(idx,
                    "SELECT source FROM ccz_sigma_index WHERE sigma_hash = ? AND n = 8", (r.sigma,))))
        fam[r.sigma] = isempty(srcs) ? "list:" * r.status : join(srcs, "+")
    end
    close(idx)
    fam
end

"Spearman rank correlation (average ranks for ties)."
function spearman(x::AbstractVector, y::AbstractVector)
    rk(v) = (p = sortperm(v); r = zeros(Float64, length(v)); i = 1;
             while i <= length(v)
                 j = i
                 while j < length(v) && v[p[j + 1]] == v[p[i]]; j += 1; end
                 r[p[i:j]] .= (i + j) / 2; i = j + 1
             end; r)
    a = rk(x); b = rk(y)
    (std(a) == 0 || std(b) == 0) ? NaN : cor(a, b)
end

# ---------------------------------------------------------------- tables

fmt_hist(d::Dict) = join(["$(k):$(v)" for (k, v) in sort(collect(d); by = first)], " ")
pct(a, b) = b == 0 ? "-" : @sprintf("%.4f%%", 100 * a / b)

function group_table(io, title, keyname, fr, keyf)
    groups = Dict{Any,Vector{FRow}}()
    for r in fr
        push!(get!(groups, keyf(r), FRow[]), r)
    end
    println(io, "\n### ", title, "\n")
    println(io, "| ", keyname, " | functions | with n_gt1 > 0 | mean n_gt1 | pair rate k > 1 | n_gt1 values (value:count) |")
    println(io, "|---|---:|---:|---:|---:|---|")
    for (key, v) in sort(collect(groups); by = x -> (-length(x[2]), string(x[1])))
        h = Dict{Int,Int}()
        foreach(r -> (h[r.ngt1] = get(h, r.ngt1, 0) + 1), v)
        hs = length(h) > 12 ? fmt_hist(Dict(k => h[k] for k in sort(collect(keys(h)))[end - 11:end])) * " (top 12)" :
             fmt_hist(h)
        @printf(io, "| %s | %d | %d (%s) | %.3f | %s | %s |\n", string(key), length(v),
                count(r -> r.ngt1 > 0, v), pct(count(r -> r.ngt1 > 0, v), length(v)),
                mean(r.ngt1 for r in v), pct(sum(r.ngt1 for r in v), 255 * length(v)), hs)
    end
end

"""
    analyze(; p6 = true, dir = HS_RESULTS, io = stdout) -> NamedTuple

Read the scan results, print markdown tables to `io` and to results/analysis.md, and
write ../new_classes_hyperplane.tsv (verified NEW classes, one row per sigma).
"""
function analyze(; p6::Bool = true, dir::AbstractString = HS_RESULTS, io::IO = stdout)
    fr = read_functions(joinpath(dir, "functions.tsv"))
    done = Set((r.src, r.mem) for r in fr)
    pr = read_pairs(joinpath(dir, "pairs.tsv"), done)
    # keep only complete functions: coset rows = sum of k over the pairs with k > 1
    ncos = Dict{Tuple{String,Int},Int}()
    foreach(p -> (ncos[(p.src, p.mem)] = get(ncos, (p.src, p.mem), 0) + 1), pr)
    good = [r for r in fr if sum(k for k in r.ks if k > 1; init = 0) == get(ncos, (r.src, r.mem), 0)]
    if length(good) < length(fr)
        println(io, "skipping ", length(fr) - length(good), " incomplete functions (rescan with make scan)")
        fr = good
        done = Set((r.src, r.mem) for r in fr)
        pr = [p for p in pr if (p.src, p.mem) in done]
    end
    buf = IOBuffer()
    println(buf, "## Hyperplane scan: analysis\n")
    println(buf, "Functions: ", length(fr), ". Pairs (F, H): ", 255 * length(fr),
            ". Coset rows (k > 1): ", length(pr), ".")
    srcs = [s for s in SOURCES if any(r -> r.src == s, fr)]

    # per source
    println(buf, "\n### Rate of k > 1 per source\n")
    println(buf, "| source | functions | pairs | pairs k > 1 | rate | k histogram | functions with n_gt1 > 0 | max n_gt1 | seconds / function |")
    println(buf, "|---|---:|---:|---:|---:|---|---:|---:|---:|")
    for s in srcs
        v = [r for r in fr if r.src == s]
        kh = Dict{Int,Int}()
        for r in v, k in r.ks
            kh[k] = get(kh, k, 0) + 1
        end
        npk = sum(r.ngt1 for r in v)
        @printf(buf, "| %s | %d | %d | %d | %s | %s | %d (%s) | %d | %.1f |\n", s, length(v),
                255 * length(v), npk, pct(npk, 255 * length(v)), fmt_hist(kh),
                count(r -> r.ngt1 > 0, v), pct(count(r -> r.ngt1 > 0, v), length(v)),
                maximum(r.ngt1 for r in v), mean(r.secs for r in v))
    end
    println(buf, "\n### Number of hyperplanes with k > 1 per function (value:count)\n")
    println(buf, "| source | n_gt1 histogram |")
    println(buf, "|---|---|")
    for s in srcs
        h = Dict{Int,Int}()
        foreach(r -> (h[r.ngt1] = get(h, r.ngt1, 0) + 1), (r for r in fr if r.src == s))
        println(buf, "| ", s, " | ", fmt_hist(h), " |")
    end

    # invariants
    group_table(buf, "n_gt1 by component rank counts (r8, r6, r4, r2)", "ranks", fr, r -> r.ranks)
    fam = families(fr)
    group_table(buf, "n_gt1 by sigma family (indexed sources that contain sigma(F))", "family",
                fr, r -> fam[r.sigma])
    if p6
        P = p6_table(fr; dir = dir, io = io)
        group_table(buf, "n_gt1 by b6 (bent elements of the best 6-dim subspace, P6 bminK)", "b6",
                    fr, r -> b6k6(P[(r.src, r.mem)])[1])
        group_table(buf, "n_gt1 by (b6, K6)", "(b6, K6)", fr, r -> b6k6(P[(r.src, r.mem)]))
    end
    println(buf, "\n### Spearman correlation of n_gt1 with invariants\n")
    println(buf, "| set | functions | r4 | b6 | K6 | n_gt1 > 0 with 3 \\| n_gt1 |")
    println(buf, "|---|---:|---:|---:|---:|---:|")
    for (name, v) in [("all", fr); [(s, [r for r in fr if r.src == s]) for s in srcs]]
        length(v) < 20 && continue
        y = [r.ngt1 for r in v]
        cs = [spearman([r.ranks[3] for r in v], y)]
        if p6
            bk = [b6k6(P[(r.src, r.mem)]) for r in v]
            append!(cs, [spearman(first.(bk), y), spearman(last.(bk), y)])
        else
            append!(cs, [NaN, NaN])
        end
        pos = [r.ngt1 for r in v if r.ngt1 > 0]
        println(buf, "| ", name, " | ", length(v), " | ",
                join([isnan(c) ? "-" : @sprintf("%.3f", c) for c in cs], " | "), " | ",
                count(x -> x % 3 == 0, pos), " / ", length(pos), " |")
    end

    # cosets
    println(buf, "\n### Cosets of pairs with k > 1: status of the extension\n")
    println(buf, "| source | pairs k > 1 | pairs with one coset of sigma(F) | cosets | sigma = sigma(F) | other: known | census553 | extra | search773 | raw546 | NEW | distinct other sigma |")
    println(buf, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for s in srcs
        v = [p for p in pr if p.src == s]
        isempty(v) && continue
        oth = [p for p in v if !p.same]
        c(st) = count(p -> p.status == st, oth)
        bypair = Dict{Tuple{Int,Int},Int}()
        foreach(p -> (bypair[(p.mem, p.u)] = get(bypair, (p.mem, p.u), 0) + p.same), v)
        @printf(buf, "| %s | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d |\n", s,
                length(bypair), count(==(1), values(bypair)), length(v),
                count(p -> p.same, v), c("known"), c("census553"), c("extra"), c("search773"),
                c("raw546"), c("NEW"), length(unique(p.sigma for p in oth)))
    end
    # indexed source of the other known extensions
    idx = VBFCatalog._open_sigma_index()
    srcof = Dict{String,String}()
    for p in pr
        (!p.same && p.status == "known" && !haskey(srcof, p.sigma)) || continue
        ss = sort(unique(String(x.source) for x in VBFCatalog.DBInterface.execute(idx,
                  "SELECT source FROM ccz_sigma_index WHERE sigma_hash = ? AND n = 8", (p.sigma,))))
        srcof[p.sigma] = join(ss, "+")
    end
    close(idx)
    println(buf, "\n### Other known extensions: indexed sources of their sigma (distinct sigma per parent source)\n")
    println(buf, "| parent source | sigma family of the extension (count) |")
    println(buf, "|---|---|")
    for s in srcs
        h = Dict{String,Int}()
        for sg in unique(p.sigma for p in pr if p.src == s && !p.same && p.status == "known")
            h[srcof[sg]] = get(h, srcof[sg], 0) + 1
        end
        isempty(h) && continue
        println(buf, "| ", s, " | ", join(["$(k): $(v)" for (k, v) in sort(collect(h); by = x -> -x[2])], "; "), " |")
    end

    # new classes
    oracle = load_oracle(; io = io)
    first_new = Dict{String,Any}()
    for p in pr
        p.status == "NEW" || continue
        haskey(first_new, p.sigma) || (first_new[p.sigma] = p)
    end
    verified = Any[]
    for (h, p) in sort(collect(first_new); by = first)
        S = SBox{8}(UInt8.(QK.lut(decode8(p.coeffs), 8)))
        ok = differential_uniformity(S) == 2 && VBFCatalog.sigma_hash(S) == h &&
             status(oracle, h) == "NEW"
        ok ? push!(verified, p) : println(io, "WARNING: NEW sigma ", h, " failed verification")
    end
    newpath = dir == HS_RESULTS ? joinpath(HS_DIR, "new_classes_hyperplane.tsv") :
              joinpath(dir, "new_classes_hyperplane.tsv")
    open(newpath, "w") do f
        println(f, "sigma\tcoeffs\tparent_source\tparent_member\thyperplane_u")
        for p in verified
            println(f, join((p.sigma, p.coeffs, p.src, p.mem, p.u), '\t'))
        end
    end
    th = sum(r.secs for r in fr) / 3600
    println(buf, "\n### New classes and yield\n")
    println(buf, "| source | thread-hours | NEW cosets | distinct NEW sigma (first found here) | NEW per thread-hour |")
    println(buf, "|---|---:|---:|---:|---:|")
    for s in srcs
        ths = sum(r.secs for r in fr if r.src == s) / 3600
        nc = count(p -> p.src == s && p.status == "NEW", pr)
        nd = count(p -> p.src == s, verified)
        @printf(buf, "| %s | %.2f | %d | %d | %.2f |\n", s, ths, nc, nd, nd / ths)
    end
    @printf(buf, "| **total** | %.2f | %d | %d | %.2f |\n", th,
            count(p -> p.status == "NEW", pr), length(verified), length(verified) / th)
    println(buf, "\nThread-hours = sum of the per-function wall times (one function runs on one thread).")
    println(buf, "Verified NEW classes written to `new_classes_hyperplane.tsv`: ", length(verified), ".")
    s = String(take!(buf))
    print(io, s)
    write(joinpath(dir, "analysis.md"), s)
    (functions = length(fr), cosets = length(pr), new = length(verified), thread_hours = th)
end

abspath(PROGRAM_FILE) == @__FILE__() && analyze(; p6 = !("p6=false" in ARGS))
