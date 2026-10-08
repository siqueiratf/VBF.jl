# Task 1 — FULL integrity check of the n=8 part of the sigma index.
#
# For every member of every n=8 bulk corpus (VBFCatalog.list_corpora) and every
# quadratic APN n=8 row of the catalog `functions` table, recompute sigma_hash
# from the STORED function and require that the index holds exactly the row
# (hash, source, member_idx). Also: store row counts == bulk_corpora.member_count
# == index row count per source, store idx contiguity, store-file sha256 vs the
# catalog descriptor, no duplicate / out-of-range index rows, no n=8 index rows
# from unknown sources, and an independent recount of the distinct n=8 sigma
# from the RECOMPUTED hashes. The 553 claimed-new hashes (all40_new.tsv) are
# then checked against the recomputed set — independent of the index file.
#
# Usage:
#   julia -t 8 --project=/home/ts/VBF.jl verify_index.jl bench [N] [du]
#       -> first N (default 10000) members of beierle2025_n8 only, timing only
#   julia -t 8 --project=/home/ts/VBF.jl verify_index.jl full [du]
#       -> everything; writes verify_index_summary.toml, verify_index_problems.tsv
#   julia -t 8 --project=/home/ts/VBF.jl verify_index.jl sample K SEED [du]
#       -> all small sources fully + a uniform random K-member sample of beierle2025_n8
# Passing `du` additionally recomputes VBF.differential_uniformity == 2 for every member.

using VBF, VBFCatalog, SHA, Random, Printf, TOML
const SQLite = VBFCatalog.SQLite
const DBI = VBFCatalog.DBInterface
const HERE = @__DIR__
const NEWTSV = normpath(joinpath(HERE, "..", "all40_new.tsv"))

mode = isempty(ARGS) ? "bench" : ARGS[1]
check_du = "du" in ARGS
bench_n = mode == "bench" && length(ARGS) >= 2 && ARGS[2] != "du" ? parse(Int, ARGS[2]) : 10_000
sample_k = mode == "sample" ? parse(Int, ARGS[2]) : 0
sample_seed = mode == "sample" ? parse(Int, ARGS[3]) : 0

println("mode=$mode threads=$(Threads.nthreads()) check_du=$check_du")
cat = VBFCatalog.load_catalog()
idx = VBFCatalog._open_sigma_index()

problems = IOBuffer()          # source, member_idx, kind, detail
problem(src, i, kind, detail) = println(problems, src, '\t', i, '\t', kind, '\t', detail)

computed_all = Set{String}()   # recomputed n=8 hashes (all sources)
summary = Dict{String,Any}()

# index rows for one source at n=8 -> (hash-by-member_idx, n_rows, dup count, out-of-range rows)
function index_rows(src::String, maxidx::Int)
    hs = Vector{Union{Nothing,String}}(nothing, maxidx)
    nrows = 0; ndup = 0; noor = 0
    for r in DBI.execute(idx, "SELECT sigma_hash, member_idx FROM ccz_sigma_index WHERE n = 8 AND source = '$src'")
        nrows += 1
        mi = Int(r.member_idx)
        if mi < 1 || mi > maxidx
            noor += 1; problem(src, mi, "index_row_out_of_range", r.sigma_hash); continue
        end
        if hs[mi] !== nothing
            ndup += 1; problem(src, mi, "duplicate_index_row", "$(hs[mi]) / $(r.sigma_hash)")
        end
        hs[mi] = String(r.sigma_hash)
    end
    hs, nrows, ndup, noor
end

# compute hashes for a batch of (idx, coeffs) in parallel
function hash_batch(cos::Vector{Vector{UInt8}}, n, mod, powtab)
    hs = Vector{String}(undef, length(cos))
    dus = fill(-1, length(cos))
    Threads.@threads for j in eachindex(cos)
        try
            F = SBox{n}(decode_quadratic_lut(cos[j], n, mod; powtab = powtab))
            hs[j] = VBFCatalog.sigma_hash(F)
            check_du && (dus[j] = differential_uniformity(F))
        catch e
            hs[j] = "ERROR:" * sprint(showerror, e)[1:min(end, 80)]
        end
    end
    hs, dus
end

function check_corpus(name::String; limit::Int = typemax(Int), sample = nothing)
    t0 = time()
    info = VBFCatalog.corpus_info(cat, name)
    n = Int(info.n); mod = Int(info.modulus); mc = Int(info.member_count)
    path = VBFCatalog.corpus_store_path(name)
    res = Dict{String,Any}("member_count_catalog" => mc, "n" => n)
    if !isfile(path)
        res["store_present"] = false; problem(name, 0, "store_absent", path); return res
    end
    res["store_present"] = true
    sha = bytes2hex(open(SHA.sha256, path))
    res["store_sha256_matches_catalog"] = sha == info.store_sha256
    sha == info.store_sha256 || problem(name, 0, "store_sha256_mismatch", "$sha vs $(info.store_sha256)")
    store = SQLite.DB(path)
    cnt, mn, mx = 0, 0, 0
    for r in DBI.execute(store, "SELECT COUNT(*) c, MIN(idx) a, MAX(idx) b FROM members")
        cnt, mn, mx = Int(r.c), Int(r.a), Int(r.b)
    end
    res["store_rows"] = cnt
    res["store_idx_contiguous"] = (mn == 1 && mx == cnt)
    hs_idx, nrows, ndup, noor = index_rows(name, max(mx, mc))
    res["index_rows"] = nrows; res["index_duplicate_rows"] = ndup; res["index_out_of_range_rows"] = noor
    res["counts_equal"] = (cnt == mc == nrows)
    cnt == mc == nrows || problem(name, 0, "count_mismatch", "store=$cnt catalog=$mc index=$nrows")
    powtab = monomial_power_table(n, mod)
    sql = sample === nothing ?
        "SELECT idx, coeffs FROM members ORDER BY idx" * (limit < typemax(Int) ? " LIMIT $limit" : "") :
        "SELECT idx, coeffs FROM members WHERE idx IN (" * join(sample, ",") * ") ORDER BY idx"
    seen = falses(max(mx, mc))
    checked = 0; ok = 0; mism = 0; missing_ = 0; errs = 0; dubad = 0
    bi = Int[]; bc = Vector{UInt8}[]
    function flushb()
        isempty(bi) && return
        hs, dus = hash_batch(bc, n, mod, powtab)
        for j in eachindex(bi)
            i = bi[j]; h = hs[j]; checked += 1; seen[i] = true
            if startswith(h, "ERROR:")
                errs += 1; problem(name, i, "decode_or_sigma_error", h); continue
            end
            push!(computed_all, h)
            check_du && dus[j] != 2 && (dubad += 1; problem(name, i, "du_not_2", dus[j]))
            ih = hs_idx[i]
            if ih === nothing
                missing_ += 1; problem(name, i, "missing_index_row", h)
            elseif ih != h
                mism += 1; problem(name, i, "hash_mismatch", "recomputed=$h index=$ih")
            else
                ok += 1
            end
        end
        empty!(bi); empty!(bc); GC.gc(false)
    end
    for r in DBI.execute(store, sql)
        push!(bi, Int(r.idx)); push!(bc, Vector{UInt8}(r.coeffs))
        length(bi) >= 20_000 && flushb()
    end
    flushb()
    close(store)
    # index rows whose member_idx does not exist in the store (only meaningful for a full pass)
    orphan = 0
    if sample === nothing && limit == typemax(Int)
        for i in eachindex(hs_idx)
            hs_idx[i] !== nothing && !seen[i] && (orphan += 1; problem(name, i, "index_row_without_store_member", hs_idx[i]))
        end
    end
    dt = time() - t0
    merge!(res, Dict("checked" => checked, "exact_row_present" => ok, "hash_mismatch" => mism,
        "missing_index_row" => missing_, "decode_or_sigma_errors" => errs, "orphan_index_rows" => orphan,
        "du_not_2" => check_du ? dubad : -1, "seconds" => round(dt, digits = 1),
        "full" => sample === nothing && limit == typemax(Int)))
    @printf("%-30s checked=%8d ok=%8d mism=%d missing=%d err=%d orphan=%d dup=%d du!=2=%s  counts(store/cat/index)=%d/%d/%d sha_ok=%s  %.1fs (%.0f/s)\n",
        name, checked, ok, mism, missing_, errs, orphan, ndup, check_du ? string(dubad) : "-", cnt, mc, nrows,
        res["store_sha256_matches_catalog"], dt, checked / dt)
    flush(stdout)
    res
end

function check_functions()
    t0 = time()
    rows = [(Int(r.id), Vector{UInt8}(r.lut_blob), Int(r.is_apn), Int(r.is_quadratic))
            for r in DBI.execute(cat, "SELECT id, lut_blob, is_apn, is_quadratic FROM functions WHERE n = 8")]
    qrows = filter(r -> r[3] == 1 && r[4] == 1, rows)
    ixh = Dict{Int,Vector{String}}()
    nrows = 0
    for r in DBI.execute(idx, "SELECT sigma_hash, member_idx FROM ccz_sigma_index WHERE n = 8 AND source = 'functions'")
        nrows += 1; push!(get!(ixh, Int(r.member_idx), String[]), String(r.sigma_hash))
    end
    ok = 0; mism = 0; miss = 0; flagbad = 0
    for (id, blob, apn, quad) in rows
        F = VBFCatalog._sbox_from_blob(blob, 8)
        deg = algebraic_degree(F); du = differential_uniformity(F)
        # flags must agree with recomputation (a quadratic APN row mis-flagged would be silently unindexed)
        if (du == 2) != (apn == 1) || ((deg == 2) != (quad == 1) && du == 2)
            flagbad += 1; problem("functions", id, "flag_mismatch", "is_apn=$apn is_quadratic=$quad du=$du deg=$deg")
        end
        (apn == 1 && quad == 1) || continue
        h = VBFCatalog.sigma_hash(F); push!(computed_all, h)
        v = get(ixh, id, String[])
        if isempty(v); miss += 1; problem("functions", id, "missing_index_row", h)
        elseif h in v; ok += 1
        else mism += 1; problem("functions", id, "hash_mismatch", "recomputed=$h index=$(join(v, ","))")
        end
    end
    orphan = count(k -> !(k in Set(r[1] for r in qrows)), keys(ixh))
    orphan > 0 && problem("functions", 0, "index_rows_without_quadratic_apn_function", orphan)
    dt = time() - t0
    @printf("%-30s rows(n=8)=%d quadAPN=%d ok=%d mism=%d missing=%d orphan=%d flag_mismatch=%d index_rows=%d  %.1fs\n",
        "functions", length(rows), length(qrows), ok, mism, miss, orphan, flagbad, nrows, dt)
    Dict("n8_rows" => length(rows), "quadratic_apn_rows" => length(qrows), "index_rows" => nrows,
         "exact_row_present" => ok, "hash_mismatch" => mism, "missing_index_row" => miss,
         "orphan_index_rows" => orphan, "flag_mismatch" => flagbad, "counts_equal" => nrows == length(qrows),
         "seconds" => round(dt, digits = 1), "full" => true)
end

tstart = time()
if mode == "bench"
    summary["beierle2025_n8"] = check_corpus("beierle2025_n8"; limit = bench_n)
else
    corpora = VBFCatalog.list_corpora(cat)
    # sources in the index at n=8 that the catalog does not list
    srcs = [String(r.source) for r in DBI.execute(idx, "SELECT DISTINCT source FROM ccz_sigma_index WHERE n = 8")]
    unknown = setdiff(srcs, vcat(corpora, ["functions"]))
    isempty(unknown) || problem("-", 0, "unknown_index_source", join(unknown, ","))
    summary["_global"] = Dict{String,Any}("index_sources_n8" => sort(srcs), "unknown_index_sources" => unknown,
                                         "catalog_corpora" => corpora)
    summary["functions"] = check_functions()
    # small sources first, largest last
    for name in sort(corpora; by = c -> VBFCatalog.corpus_length(cat, c))
        if mode == "sample" && name == "beierle2025_n8"
            mc = VBFCatalog.corpus_length(cat, name)
            smp = sort(randperm(MersenneTwister(sample_seed), mc)[1:sample_k])
            summary[name] = check_corpus(name; sample = smp)
            summary[name]["sample_seed"] = sample_seed
        else
            summary[name] = check_corpus(name)
        end
    end
    # independent recount + the 553 claimed-new hashes against the RECOMPUTED set
    n8_rows_index = first(DBI.execute(idx, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE n = 8")).c
    n8_distinct_index = first(DBI.execute(idx, "SELECT COUNT(DISTINCT sigma_hash) c FROM ccz_sigma_index WHERE n = 8")).c
    newh = [String(split(l, '\t')[1]) for l in eachline(NEWTSV)]
    hits_new = count(h -> h in computed_all, newh)
    g = summary["_global"]
    g["index_n8_rows"] = n8_rows_index
    g["index_n8_distinct_sigma"] = n8_distinct_index
    g["recomputed_n8_distinct_sigma"] = length(computed_all)
    g["new553_present_in_recomputed_set"] = hits_new
    g["new553_count"] = length(newh)
    println("index n=8 rows $n8_rows_index, distinct $n8_distinct_index; recomputed distinct $(length(computed_all))")
    println("553 claimed-new hashes found in the RECOMPUTED sigma set: $hits_new / $(length(newh))")
end
summary["_wall_seconds"] = round(time() - tstart, digits = 1)
println("total wall: ", summary["_wall_seconds"], " s")

if mode != "bench"
    tag = mode == "full" ? "full" : "sample"
    open(joinpath(HERE, "verify_index_problems_$tag.tsv"), "w") do io
        println(io, "source\tmember_idx\tkind\tdetail"); write(io, take!(problems))
    end

    clean(x) = x isa Dict ? Dict(string(k) => clean(v) for (k, v) in x) : x
    open(io -> TOML.print(io, clean(summary)), joinpath(HERE, "verify_index_summary_$tag.toml"), "w")
else
    print(String(take!(problems)))
end
