# Implements the exhaustive hyperplane scan: e(F|_H) for all 255 hyperplanes H of F
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8/theory)
# Source: Beierle et al. (2025, v2), Theorem 4.1 and Lemma 4.5; ../UNIQUENESS.md
#
# Math:
#   F is a quadratic APN (8,8)-function, H = ker(u) (u = 1..255) a hyperplane, and
#   G = F|_H, a pure quadratic APN (7,8)-function with coefficients
#     c_ij = F(a_i + a_j) + F(a_i) + F(a_j) + F(0)  (a_1..a_7 a basis of H).
#   e(G) = number of linear L : H -> F_2^8 with G + s*L APN on H + F_2 (METHOD.md, Th. 3.1).
#   Lambda (|Lambda| = 2^7) acts freely on the valid L, and the extensions of one
#   Lambda-coset are EA-equivalent. So k = e / 128 counts the canonical completions, and
#   F itself gives one of them (k >= 1). For k > 1 we build one extension F' per coset,
#   check that F' is APN (differential uniformity 2) and classify F' by its sigma hash.
#
# Pseudocode:
#   1. Inputs (in this order): catalog functions table (n = 8, quadratic APN), the
#      corpora edelpott2009, wengtangong2013, taniguchi2019, beierleleanderperrin2022,
#      yuwangli2014_qam, yuperrin2022_qam, beierleleander2022, the new classes
#      census553 + extra + search773, then a random sample of beierle2025_n8.
#   2. Skip every (source, member) that results/functions.tsv already lists (resume).
#   3. Workers (threads) take the next function from one shared counter:
#        sigma(F), status(F), component ranks, then for u = 1..255:
#          C = coefficients of F|_ker(u); e = FL3.count_completions(C, 7, 8); k = e/128.
#          k > 1: list the canonical completions L_1..L_k; for each one build F_j,
#                 du(F_j) must be 2; sigma(F_j); status(sigma).
#      Write the coset rows (pairs.tsv) and then the function row (functions.tsv) under
#      one lock and flush: a function row marks a complete function (checkpoint).
#   4. Stop taking new functions after `timeout_seconds`.
#
# Status of a sigma: known (VBFCatalog sigma index, n = 8) / census553 / extra /
#   search773 / raw546 / NEW (in this order of precedence).
# VBF API used: SBox, differential_uniformity, is_quadratic_apn
# VBFCatalog API used: load_catalog, corpus_function, corpus_length, sigma_hash, DBInterface

const HS_DIR = @__DIR__
const HS_CENSUS = normpath(joinpath(@__DIR__, "..", ".."))
const HS_RESULTS = joinpath(@__DIR__, "results")

isdefined(@__MODULE__, :FL3) || include(joinpath(HS_CENSUS, "theory", "check_uniqueness.jl"))
isdefined(@__MODULE__, :Profiles) ||
    include(joinpath(HS_CENSUS, "reports", "properties", "profiles_lib.jl"))
if !isdefined(@__MODULE__, :B52)
    # The novelty oracle of the B6 = 52 search (index_set, sigma_bits), in its own module.
    @eval module B52
    include(joinpath($HS_CENSUS, "search_b52", "common.jl"))
    end
end

using VBF, VBFCatalog, Random, Printf, Dates, Base.Threads

const SOURCES = ["catalog", "edelpott2009_n8", "wengtangong2013_n8", "taniguchi2019_n8",
                 "beierleleanderperrin2022_n8", "yuwangli2014_qam_n8", "yuperrin2022_qam_n8",
                 "beierleleander2022_n8", "census553", "extra", "search773",
                 "beierle2025_sample"]

const LIST_553 = joinpath(HS_CENSUS, "new_classes_553.tsv")              # sigma, coeffs
const LIST_EXTRA = joinpath(HS_CENSUS, "new_classes_extra.tsv")          # header; sigma, coeffs, origin
const LIST_773 = joinpath(HS_CENSUS, "search_b52", "new_classes_trial_773.tsv")  # header; sigma .. coeffs (col 5)
const LIST_546 = joinpath(HS_CENSUS, "crosscheck_raw", "raw_only_546.tsv")      # header; sigma, record, lut

# ---------------------------------------------------------------- inputs

"Data rows of a TSV file (split on tabs); `header = true` drops the first line."
function tsv_rows(path::AbstractString; header::Bool)
    rows = [split(l, '\t') for l in eachline(path) if !isempty(strip(l))]
    header ? rows[2:end] : rows
end

"Symmetric 8x8 coefficient matrix from 56 hex digits (c_ab, a < b, row order)."
decode8(coeffs::AbstractString) = Profiles.coeff_matrix(coeffs)

lut_from_coeffs8(coeffs::AbstractString) = UInt8.(QK.lut(decode8(coeffs), 8))

"Coefficient column of a coefficient-based list source."
function coeff_list(src::AbstractString)
    src == "census553" && return [String(r[2]) for r in tsv_rows(LIST_553; header = false)]
    src == "extra" && return [String(r[2]) for r in tsv_rows(LIST_EXTRA; header = true)]
    src == "search773" && return [String(r[5]) for r in tsv_rows(LIST_773; header = true)]
    error("not a coefficient list: $src")
end

"""
    members(src; sample, seed) -> Vector{Int}

Member ids of a source, in scan order: catalog = functions.id; corpora = corpus index in
a random order (fixed by `seed`; so `limit` takes a random subset); lists = data row
number; beierle2025_sample = `sample` distinct random corpus indices.
"""
function members(src::AbstractString; sample::Int = 20_000, seed::Int = 1)
    db = VBFCatalog.load_catalog()
    if src == "catalog"
        q = "SELECT id FROM functions WHERE n = 8 AND m = 8 AND is_apn = 1 AND is_quadratic = 1 ORDER BY id"
        return [Int(r.id) for r in VBFCatalog.DBInterface.execute(db, q)]
    elseif src in ("census553", "extra", "search773")
        return collect(1:length(coeff_list(src)))
    elseif src == "beierle2025_sample"
        cnt = VBFCatalog.corpus_length(db, "beierle2025_n8")
        return randperm(Xoshiro(seed), cnt)[1:min(sample, cnt)]
    else
        cnt = VBFCatalog.corpus_length(db, src)
        return cnt <= 100 ? collect(1:cnt) : randperm(Xoshiro(seed), cnt)
    end
end

const DB_LOCK = ReentrantLock()
const COEFF_CACHE = Dict{String,Vector{String}}()

"LUT (UInt8, 256 entries) of member `mem` of source `src` (thread-safe)."
function member_lut(src::AbstractString, mem::Int)
    lock(DB_LOCK) do
        db = VBFCatalog.load_catalog()
        if src == "catalog"
            q = "SELECT lut_blob FROM functions WHERE id = $mem"
            for r in VBFCatalog.DBInterface.execute(db, q)
                return collect(Vector{UInt8}(r.lut_blob))
            end
            error("catalog id $mem not found")
        elseif src in ("census553", "extra", "search773")
            lst = get!(() -> coeff_list(src), COEFF_CACHE, src)
            return lut_from_coeffs8(lst[mem])
        else
            corpus = src == "beierle2025_sample" ? "beierle2025_n8" : src
            return collect(UInt8.(VBFCatalog.corpus_function(db, corpus, mem).lut))
        end
    end
end

# ---------------------------------------------------------------- novelty oracle

struct Oracle
    index::B52.SortedSigma
    lists::Vector{Tuple{String,Set{String}}}
end

function load_oracle(; io::IO = stdout)
    idx = B52.index_set(; io = io)
    lists = [("census553", Set(String(r[1]) for r in tsv_rows(LIST_553; header = false))),
             ("extra", Set(String(r[1]) for r in tsv_rows(LIST_EXTRA; header = true))),
             ("search773", Set(String(r[1]) for r in tsv_rows(LIST_773; header = true))),
             ("raw546", Set(String(r[1]) for r in tsv_rows(LIST_546; header = true)))]
    for (name, s) in lists
        println(io, "status list ", name, ": ", length(s), " sigma")
    end
    Oracle(idx, lists)
end

function status(o::Oracle, sigma::AbstractString)
    B52.sigma_bits(sigma) in o.index && return "known"
    for (name, s) in o.lists
        sigma in s && return name
    end
    "NEW"
end

# ---------------------------------------------------------------- one function

"One character per hyperplane: k in 0..35 as a base-36 digit, larger k as '#'."
kchar(k::Int) = k < 36 ? string(k, base = 36)[1] : '#'

"Coefficient matrix (8 vars) of the extension G + x_8 L."
function extension_matrix(C::Matrix{UInt16}, L::Vector{UInt16})
    D = zeros(UInt16, 8, 8)
    D[1:7, 1:7] = C
    for t in 1:7
        D[t, 8] = D[8, t] = L[t]
    end
    D
end

"""
    scan_function(src, mem, lut8, oracle) -> (function_row, coset_rows, npairs_k, nnew)

All 255 hyperplanes of one function. Throws when F is not quadratic APN, when e < 128,
when the number of canonical solutions differs from k, or when an extension is not APN.
"""
function scan_function(src::AbstractString, mem::Int, lut8::Vector{UInt8}, o::Oracle)
    t0 = time()
    F = SBox{8}(lut8)
    is_quadratic_apn(F) || error("$src[$mem] is not quadratic APN")
    lut = Int.(lut8)
    sF = VBFCatalog.sigma_hash(F)
    stF = status(o, sF)
    C8 = Profiles.coeff_matrix_from_lut(lut)
    rc = Profiles.rank_counts(Profiles.component_ranks(C8))   # (r8, r6, r4, r2, r0)
    ks = Vector{Char}(undef, 255)
    rows = String[]
    nk = 0; nnew = 0
    for u in 1:255
        C = restrict_coeffs(lut, hyperplane_basis(u, 8))
        e, _ = FL3.count_completions(C, 7, 8)
        e >= 128 || error("$src[$mem] u=$u: e = $e < 128, but F extends F|_H")
        k = e >> 7
        ks[u] = kchar(k)
        k > 1 || continue
        nk += 1
        _, sols = FL3.count_completions(C, 7, 8; want_solution = true)
        length(sols) == k || error("$src[$mem] u=$u: $(length(sols)) canonical solutions, k = $k")
        for (j, L) in enumerate(sols)
            D = extension_matrix(C, L)
            S = SBox{8}(UInt8.(QK.lut(D, 8)))
            du = differential_uniformity(S)
            du == 2 || error("$src[$mem] u=$u coset $j: extension has du = $du")
            h = VBFCatalog.sigma_hash(S)
            st = status(o, h)
            st == "NEW" && (nnew += 1)
            push!(rows, join((src, mem, u, k, j, du, h, st, h == sF ? 1 : 0,
                              coeff_string(D, 8)), '\t'))
        end
    end
    secs = time() - t0
    frow = join((src, mem, sF, stF, join(rc[1:4], ","), nk, String(ks),
                 @sprintf("%.2f", secs)), '\t')
    frow, rows, nk, nnew
end

# ---------------------------------------------------------------- driver

const FUNCTIONS_HEADER = "source\tmember\tsigma_F\tstatus_F\tranks_8_6_4_2\tn_hyperplanes_k_gt1\tk_by_u\tseconds"
const PAIRS_HEADER = "source\tmember\tu\tk\tcoset\tdu\tsigma\tstatus\tsame_as_F\tcoeffs"

"True for a well-formed function row (8 fields, known source, 255 k digits)."
function good_function_row(l::AbstractString)
    p = split(l, '\t')
    length(p) == 8 && p[1] in SOURCES && tryparse(Int, p[2]) !== nothing &&
        length(p[7]) == 255 && tryparse(Float64, p[8]) !== nothing
end

"Expected number of coset rows of a function row: the sum of k over the pairs with k > 1."
expected_cosets(kstr::AbstractString) = sum((k = c == '#' ? 36 : parse(Int, c; base = 36); k > 1 ? k : 0)
                                            for c in kstr)

"""
    repair!(fpath, ppath) -> (done keys, number of dropped functions, dropped coset rows)

Resume check. A function is complete when it has one well-formed function row and
exactly `expected_cosets` distinct coset rows (keyed by u and coset). Rewrite both files
with the complete functions only (first copy of each row). The other functions are
scanned again.
"""
function repair!(fpath::AbstractString, ppath::AbstractString)
    flines = collect(eachline(fpath)); plines = collect(eachline(ppath))
    frow = Dict{Tuple{String,Int},String}()
    forder = Tuple{String,Int}[]
    for l in flines[2:end]
        good_function_row(l) || continue
        p = split(l, '\t'); key = (String(p[1]), parse(Int, p[2]))
        haskey(frow, key) && continue
        frow[key] = l; push!(forder, key)
    end
    prow = Dict{Tuple{String,Int},Vector{String}}()
    seen = Set{Tuple{String,Int,Int,Int}}()
    for l in plines[2:end]
        p = split(l, '\t')
        length(p) == 10 || continue
        pk = (String(p[1]), parse(Int, p[2]), parse(Int, p[3]), parse(Int, p[5]))
        pk in seen && continue
        push!(seen, pk)
        push!(get!(prow, (pk[1], pk[2]), String[]), l)
    end
    done = Set(key for key in forder
               if expected_cosets(split(frow[key], '\t')[7]) == length(get(prow, key, String[])))
    keepf = [flines[1]; [frow[k] for k in forder if k in done]]
    keepp = [plines[1]; reduce(vcat, [prow[k] for k in forder if k in done && haskey(prow, k)]; init = String[])]
    nf = length(flines) - length(keepf); np = length(plines) - length(keepp)
    for (path, keep, n) in ((fpath, keepf, nf), (ppath, keepp, np))
        n > 0 || continue
        tmp = path * ".tmp"
        open(f -> foreach(l -> println(f, l), keep), tmp, "w")
        mv(tmp, path; force = true)
    end
    done, nf, np
end

"Create `out/scan.lock` with our pid; refuse when a live process holds it."
function take_lock(out::AbstractString)
    lk = joinpath(out, "scan.lock")
    if isfile(lk)
        pid = tryparse(Int, strip(read(lk, String)))
        if pid !== nothing && pid != getpid() && isdir("/proc/$pid")
            error("another scan (pid $pid) holds $lk; stop it first or remove the lock")
        end
    end
    write(lk, string(getpid()))
    lk
end

"""
    scan(; sources = SOURCES, limit = 0, threads = nthreads(), timeout_seconds = Inf,
         sample = 20_000, seed = 1, out = HS_RESULTS, io = stdout)

Scan all 255 hyperplanes of every function of `sources` (in order). `limit > 0` takes at
most `limit` members per source. `threads` caps the number of worker tasks (start Julia
with `-t`). Resumes from `out/functions.tsv`. Stops taking new functions after
`timeout_seconds`.
"""
function scan(; sources = SOURCES, limit::Int = 0, threads::Int = nthreads(),
              timeout_seconds::Real = Inf, sample::Int = 20_000, seed::Int = 1,
              out::AbstractString = HS_RESULTS, io::IO = stdout)
    mkpath(out)
    fpath = joinpath(out, "functions.tsv")
    ppath = joinpath(out, "pairs.tsv")
    isfile(fpath) || open(f -> println(f, FUNCTIONS_HEADER), fpath, "w")
    isfile(ppath) || open(f -> println(f, PAIRS_HEADER), ppath, "w")
    lk = take_lock(out)
    done, nf, np = repair!(fpath, ppath)
    (nf > 0 || np > 0) && println(io, "resume check: dropped $nf function rows and $np coset rows (incomplete or duplicate)")
    oracle = load_oracle(; io = io)
    todo = Tuple{String,Int}[]
    for src in sources
        src in SOURCES || error("unknown source $src; sources: $(join(SOURCES, ", "))")
        ms = members(src; sample = sample, seed = seed)
        limit > 0 && (ms = ms[1:min(limit, length(ms))])
        nnew = 0
        for m in ms
            (src, m) in done && continue
            push!(todo, (src, m)); nnew += 1
        end
        @printf(io, "  %-28s members %6d  to do %6d\n", src, length(ms), nnew)
    end
    ntask = max(1, min(threads, nthreads()))
    @printf(io, "%s  scan: %d functions to do, %d already done, %d worker tasks, timeout %s s\n",
            Dates.format(now(), "yyyy-mm-dd HH:MM:SS"), length(todo), length(done), ntask,
            string(timeout_seconds))
    flush(io)
    isempty(todo) && return 0
    wlock = ReentrantLock()
    next = Atomic{Int}(0)
    ndone = Atomic{Int}(0); npk = Atomic{Int}(0); nnewc = Atomic{Int}(0)
    nfail = Atomic{Int}(0)
    t0 = time()
    fF = open(fpath, "a"); fP = open(ppath, "a")
    worker() = while true
        time() - t0 > timeout_seconds && break
        i = atomic_add!(next, 1) + 1
        i > length(todo) && break
        src, mem = todo[i]
        local res
        try
            res = scan_function(src, mem, member_lut(src, mem), oracle)
        catch err
            atomic_add!(nfail, 1)
            lock(wlock) do
                println(io, "ERROR ", src, "[", mem, "]: ", sprint(showerror, err)); flush(io)
            end
            continue
        end
        frow, rows, nk, nn = res
        lock(wlock) do
            foreach(r -> println(fP, r), rows); flush(fP)
            println(fF, frow); flush(fF)
            d = atomic_add!(ndone, 1) + 1
            atomic_add!(npk, nk); atomic_add!(nnewc, nn)
            if d % 50 == 0 || d == length(todo) || nk > 0 && src != "beierle2025_sample" && d % 10 == 0
                el = time() - t0
                @printf(io, "%s  %d / %d functions  [%s %d]  %.0fs  %.3f fn/s  ETA %.1f h  pairs k>1: %d  NEW cosets: %d\n",
                        Dates.format(now(), "HH:MM:SS"), d, length(todo), src, mem, el, d / el,
                        (length(todo) - d) / (d / el) / 3600, npk[], nnewc[])
                flush(io)
            end
        end
    end
    tasks = [Threads.@spawn worker() for _ in 1:ntask]
    foreach(wait, tasks)
    close(fF); close(fP)
    rm(lk; force = true)
    el = time() - t0
    @printf(io, "%s  finished: %d functions in %.0fs (%.2f thread-hours), %d errors, pairs k>1: %d, NEW cosets: %d%s\n",
            Dates.format(now(), "yyyy-mm-dd HH:MM:SS"), ndone[], el, el * ntask / 3600, nfail[],
            npk[], nnewc[], ndone[] < length(todo) ? " (stopped by timeout)" : "")
    flush(io)
    ndone[]
end

"Parse `make` style arguments: sources (comma list or all), limit, threads, timeout."
function main(args = ARGS)
    kv = Dict(split(a, '='; limit = 2) for a in args if occursin('=', a))
    src = get(kv, "source", "all")
    sources = src == "all" ? SOURCES : String.(split(src, ','))
    to = get(kv, "timeout_seconds", "")
    scan(; sources = sources, limit = parse(Int, get(kv, "limit", "0")),
         threads = parse(Int, get(kv, "threads", string(nthreads()))),
         timeout_seconds = isempty(to) ? Inf : parse(Float64, to),
         sample = parse(Int, get(kv, "sample", "20000")),
         seed = parse(Int, get(kv, "seed", "1")))
end

abspath(PROGRAM_FILE) == @__FILE__() && main()
