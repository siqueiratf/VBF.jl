#!/usr/bin/env julia
# CCZ-to-permutation test (VBF.ccz_permutation_search) over quadratic APN classes
# of dimension 8. Two modes share the per-class test and the result format.
#
# Batch mode: a class list in an SQLite database with a table
# `classes(class_id, sigma_hash, lut_sha256, lut BLOB(256))` (the freeze and
# earlier-discoveries layouts).
#
#   julia -t 4 --project=P ccz_permutation_batch.jl --classes classes.sqlite \
#       [--comparisons comparisons.sqlite] --out results.sqlite \
#       [--shard 0/4] [--limit N] [--batch 500] [--timeout 600]
#
#   --comparisons restricts to the view novel_class_ids of that database.
#   --shard i/k keeps class_id mod k == i (independent processes, own --out).
#
# Watch mode: follow a running closure (RUN/closure.sqlite, opened read-only
# with short read transactions; never written). Admitted classes are the rows
# of `parents` (the roots included) joined to `closure_candidates`; they are
# tested in id order. Results go to RUN/reports/ccz_permutation.sqlite and a
# summary to RUN/reports/ccz_permutation.json (atomic rename).
#
#   julia -t 2 --project=P ccz_permutation_batch.jl --watch RUN [--every 60]
#
#   Stops after the class in progress when RUN/reports/ccz_permutation.STOP
#   exists (run.sh ccz-stop, or SIGTERM to the run.sh wrapper, writes it).
#
# Common behaviour: one row per class; a restart skips the classes that are
# already stored (resume). A budget hit (--timeout s per class, default 600) is
# stored as 'inconclusive', never as 'none'; --retry-inconclusive deletes those
# rows (and 'error' rows) first. A failing class is stored as 'error' with its
# message. A witness is stored in the `witnesses` table, printed on stderr, and
# replayed at once by an independent path: Walsh-zero membership of both spans,
# the permutation built from the definition, its APN property, and
# are_ccz_equivalent(G, F) (native partition refinement). The batch process
# exits with status 3 after any witness; `--replay-witnesses` repeats the
# replay of stored witnesses.
#
# The test source is VBF/src/equivalence/ccz/permutation_witness.jl of this
# checkout. With an older pinned VBF (the rerun workspace) it is included into
# that VBF module; its SHA-256 is stored in every row.
using VBF, SQLite, DBInterface, SHA, Dates, JSON3

const TEST_SOURCE = normpath(joinpath(@__DIR__, "..", "..", "VBF", "src", "equivalence", "ccz",
                                      "permutation_witness.jl"))
if !isdefined(VBF, :ccz_permutation_search)
    Base.include(VBF, TEST_SOURCE)
end
const SEARCH = VBF.ccz_permutation_search
const FROM_WITNESS = VBF.ccz_permutation_from_witness
const SOURCE_SHA = bytes2hex(sha256(read(TEST_SOURCE)))

function parse_args(argv)
    a = Dict{String,String}("batch" => "500", "shard" => "0/1", "limit" => "0",
                            "timeout" => "600", "every" => "60")
    i = 1
    while i <= length(argv)
        k = argv[i]
        startswith(k, "--") || error("unexpected argument $k")
        if k in ("--replay-witnesses", "--retry-inconclusive")
            a[k[3:end]] = "1"; i += 1; continue
        end
        a[k[3:end]] = argv[i+1]; i += 2
    end
    a
end

function code_version()
    rev = try
        strip(read(`git -C $(dirname(TEST_SOURCE)) rev-parse --short=12 HEAD`, String))
    catch
        "nogit"
    end
    "VBF@$rev"
end

utc() = string(Dates.now(Dates.UTC)) * "Z"

function open_out(path)
    db = SQLite.DB(path)
    SQLite.execute(db, "PRAGMA journal_mode=WAL")
    SQLite.execute(db, "PRAGMA busy_timeout=10000")
    SQLite.execute(db, """CREATE TABLE IF NOT EXISTS results(
        lut_sha256 TEXT PRIMARY KEY, class_id INTEGER NOT NULL, sigma_hash TEXT NOT NULL,
        result TEXT NOT NULL, certificate TEXT NOT NULL, nonbent INTEGER NOT NULL,
        max_nonbent_dim INTEGER NOT NULL, candidates INTEGER NOT NULL,
        witness TEXT, error TEXT, seconds REAL NOT NULL, code_version TEXT NOT NULL,
        test_source_sha256 TEXT NOT NULL, finished_utc TEXT NOT NULL) WITHOUT ROWID""")
    SQLite.execute(db, "CREATE INDEX IF NOT EXISTS results_class ON results(class_id)")
    SQLite.execute(db, """CREATE TABLE IF NOT EXISTS witnesses(
        lut_sha256 TEXT PRIMARY KEY, class_id INTEGER, V TEXT NOT NULL, W TEXT NOT NULL,
        perm_lut BLOB NOT NULL, is_permutation INTEGER NOT NULL, is_apn INTEGER NOT NULL,
        replay TEXT, replay_ok INTEGER) WITHOUT ROWID""")
    SQLite.execute(db, "CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    db
end

# A byte LUT of length 2^n (n = 8 for the campaign; small n for tests).
function sbox(lut)
    n = trailing_zeros(length(lut))
    (ispow2(length(lut)) && 2 <= n <= 8) || error("LUT has $(length(lut)) bytes")
    SBox{n}(UInt8.(lut))
end

# SQLite rows are cursors: copy each one while iterating.
sqlrows(db, sql, params = ()) = [NamedTuple{Tuple(propertynames(r))}(Tuple(getproperty(r, k) for k in propertynames(r)))
                               for r in DBInterface.execute(db, sql, params)]

hexbasis(B) = join(string.(B; base = 16, pad = 4), ",")
parsebasis(s) = parse.(UInt32, split(s, ","); base = 16)

# One class: (id, sigma, sha, lut bytes). Never throws.
function run_one(row, timeout)
    cid, sig, sha, lut = row
    t0 = time()
    try
        bytes2hex(sha256(lut)) == sha || error("LUT SHA-256 differs from the class id")
        F = sbox(lut)
        differential_uniformity(F) == 2 || error("not APN")
        r = SEARCH(F; timeout_seconds = timeout)
        w = nothing
        if r.witness !== nothing
            V, W = r.witness
            G = FROM_WITNESS(F, V, W)
            w = (V = hexbasis(V), W = hexbasis(W), G = Vector{UInt8}(G.lut),
                 perm = is_permutation(G), apn = differential_uniformity(G) == 2)
        end
        (cid = cid, sig = sig, sha = sha, status = String(r.status),
         cert = String(r.certificate), nb = r.nonbent_count, d = r.max_nonbent_subspace_dim,
         cands = r.candidate_subspaces, w = w, err = missing, secs = r.elapsed_seconds)
    catch e
        (cid = cid, sig = sig, sha = sha, status = "error", cert = "error", nb = -1, d = -1,
         cands = -1, w = nothing, err = sprint(showerror, e), secs = time() - t0)
    end
end

function store!(out, res, ver)
    now = utc()
    SQLite.transaction(out) do
        for x in res
            wtxt = x.w === nothing ? missing : "V=$(x.w.V);W=$(x.w.W)"
            DBInterface.execute(out, "INSERT OR REPLACE INTO results VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (x.sha, x.cid, x.sig, x.status, x.cert, x.nb, x.d, x.cands, wtxt, x.err,
                 x.secs, ver, SOURCE_SHA, now))
            if x.w !== nothing
                DBInterface.execute(out, "INSERT OR REPLACE INTO witnesses VALUES (?,?,?,?,?,?,?,?,?)",
                    (x.sha, x.cid, x.w.V, x.w.W, x.w.G, Int(x.w.perm), Int(x.w.apn), missing, missing))
                println(stderr, "!!!!! WITNESS class=$(x.cid) lut_sha256=$(x.sha) perm=$(x.w.perm) ",
                        "apn=$(x.w.apn): a CCZ-equivalent permutation candidate; replaying")
            end
        end
    end
end

# Independent replay of one stored witness against the LUT of F.
function replay_one!(out, sha, lut)
    w = only(sqlrows(out, "SELECT V, W FROM witnesses WHERE lut_sha256=?", (sha,)))
    F = sbox(lut)
    V, W = parsebasis(String(w.V)), parsebasis(String(w.W))
    Z = Set(walsh_zeroes(F))
    inZ = all(v -> v == 0 || v in Z, [span_from_basis(V); span_from_basis(W)])
    G = FROM_WITNESS(F, V, W)
    perm, apn = is_permutation(G), differential_uniformity(G) == 2
    eq = try
        are_ccz_equivalent(G, F; on_inconclusive = :missing, timeout_seconds = 3600.0,
                           max_nodes = 10^9)
    catch e
        sprint(showerror, e)
    end
    ok = inZ && perm && apn && eq === true
    verdict = "inZ=$inZ perm=$perm apn=$apn ccz(G,F)=$eq at $(utc())"
    println(stderr, "!!!!! REPLAY $sha: $verdict")
    DBInterface.execute(out, "UPDATE witnesses SET replay=?, replay_ok=? WHERE lut_sha256=?",
                        (verdict, Int(ok), sha))
    ok
end

# ---------------------------------------------------------------- batch mode

function load_classes(a)
    src = SQLite.DB("file:" * abspath(a["classes"]) * "?mode=ro")
    sql = "SELECT class_id, sigma_hash, lut_sha256, lut FROM classes"
    if haskey(a, "comparisons")
        SQLite.execute(src, "ATTACH DATABASE 'file:$(abspath(a["comparisons"]))?mode=ro' AS cmp")
        sql *= " WHERE class_id IN (SELECT class_id FROM cmp.novel_class_ids)"
    end
    sql *= " ORDER BY class_id"
    lim = parse(Int, a["limit"])
    lim > 0 && (sql *= " LIMIT $lim")
    si, sk = parse.(Int, split(a["shard"], "/"))
    rows = [(Int(r.class_id), String(r.sigma_hash), String(r.lut_sha256), Vector{UInt8}(r.lut))
            for r in DBInterface.execute(src, sql) if Int(r.class_id) % sk == si]
    close(src)
    rows
end

function replay_batch(a, out)
    src = SQLite.DB("file:" * abspath(a["classes"]) * "?mode=ro")
    for w in sqlrows(out, "SELECT lut_sha256 FROM witnesses")
        sha = String(w.lut_sha256)
        lut = only(sqlrows(src, "SELECT lut FROM classes WHERE lut_sha256=?", (sha,))).lut
        replay_one!(out, sha, Vector{UInt8}(lut))
    end
    close(src)
end

function batch_main(a)
    out = open_out(a["out"])
    haskey(a, "replay-witnesses") && return replay_batch(a, out)
    haskey(a, "retry-inconclusive") &&
        SQLite.execute(out, "DELETE FROM results WHERE result IN ('inconclusive','error')")
    ver = code_version()
    done = Set(String(r.lut_sha256) for r in DBInterface.execute(out, "SELECT lut_sha256 FROM results"))
    rows = filter(r -> !(r[3] in done), load_classes(a))
    batch, timeout = parse(Int, a["batch"]), parse(Float64, a["timeout"])
    @info "ccz_permutation_batch" code_version = ver test_source_sha256 = SOURCE_SHA pending = length(rows) done = length(done) threads = Threads.nthreads()
    t0 = time(); nd = 0; nw = 0; nbad = 0
    for chunk in Iterators.partition(rows, batch)
        res = Vector{Any}(undef, length(chunk))
        Threads.@threads :dynamic for i in eachindex(chunk)
            res[i] = run_one(chunk[i], timeout)
        end
        store!(out, res, ver)
        for (i, x) in pairs(res)
            x.w === nothing || (nw += 1; replay_one!(out, x.sha, chunk[i][4]))
            x.status in ("inconclusive", "error") && (nbad += 1)
        end
        nd += length(chunk)
        @info "progress" done = nd of = length(rows) rate = round(nd / (time() - t0); digits = 1) witnesses = nw inconclusive_or_error = nbad
    end
    close(out)
    nw > 0 && exit(3)
end

# ---------------------------------------------------------------- watch mode

# One short read transaction on the controller's ledger: the next parents
# after `cursor` with their LUTs, and the current parent count.
function ledger_fetch(run, cursor, limit)
    db = SQLite.DB("file:" * abspath(joinpath(run, "closure.sqlite")) * "?mode=ro")
    try
        SQLite.execute(db, "PRAGMA query_only=ON")
        SQLite.execute(db, "PRAGMA busy_timeout=30000")
        SQLite.execute(db, "BEGIN")
        rows = [(Int(r.id), String(r.sigma), String(r.candidate_id),
                 r.lut === missing ? hex2bytes(String(r.lut_text)) : Vector{UInt8}(r.lut))
                for r in DBInterface.execute(db, """SELECT p.id, p.sigma, p.candidate_id, c.lut, c.lut_text
                    FROM parents p JOIN closure_candidates c ON c.id = p.candidate_id
                    WHERE p.id > ? ORDER BY p.id LIMIT ?""", (cursor, limit))]
        total = only(sqlrows(db, "SELECT count(*) AS n, coalesce(max(id),0) AS m FROM parents"))
        SQLite.execute(db, "COMMIT")
        return rows, Int(total.n), Int(total.m)
    finally
        close(db)
    end
end

function write_json(path, d)
    tmp = path * ".tmp-$(getpid())"
    open(tmp, "w") do io
        JSON3.write(io, d); println(io)
    end
    mv(tmp, path; force = true)
end

function meta_get(out, k, default)
    r = sqlrows(out, "SELECT value FROM meta WHERE key=?", (k,))
    isempty(r) ? default : String(only(r).value)
end
meta_set!(out, k, v) = DBInterface.execute(out, "INSERT OR REPLACE INTO meta VALUES (?,?)", (k, string(v)))

function summary(out, run, total, maxid, ver, state)
    c = Dict(String(r.result) => Int(r.n) for r in DBInterface.execute(out,
        "SELECT result, count(*) AS n FROM results GROUP BY result"))
    ws = [Dict("lut_sha256" => String(r.lut_sha256), "parent_id" => r.class_id,
               "replay" => coalesce(r.replay, "pending"),
               "replay_ok" => r.replay_ok === missing ? nothing : Bool(r.replay_ok))
          for r in DBInterface.execute(out, "SELECT lut_sha256, class_id, replay, replay_ok FROM witnesses")]
    secs = only(sqlrows(out, "SELECT coalesce(sum(seconds),0) AS s FROM results")).s
    Dict("schema" => "vbfsearch-ccz-permutation-v1",
         "test" => "Canteaut-Perrin: the CCZ class of F has a permutation iff Z_F has two n-dim subspaces with trivial intersection",
         "run" => abspath(run), "code_version" => ver, "test_source_sha256" => SOURCE_SHA,
         "tested" => sum(values(c); init = 0), "total" => total, "max_parent_id" => maxid,
         "none" => get(c, "none", 0), "witnesses" => get(c, "witness", 0),
         "errors" => get(c, "error", 0), "inconclusive" => get(c, "inconclusive", 0),
         "witness_sha256" => [w["lut_sha256"] for w in ws], "witness_list" => ws,
         "cutoff_parent_id" => parse(Int, meta_get(out, "cursor", "0")),
         "search_seconds" => Float64(secs), "state" => state, "updated_utc" => utc())
end

function watch_main(a)
    run = a["watch"]
    isfile(joinpath(run, "closure.sqlite")) || error("no closure.sqlite in $run")
    reports = mkpath(joinpath(run, "reports"))
    stopfile = joinpath(reports, "ccz_permutation.STOP")
    jsonpath = joinpath(reports, "ccz_permutation.json")
    out = open_out(joinpath(reports, "ccz_permutation.sqlite"))
    # In watch mode the class_id column holds the parent id.
    haskey(a, "retry-inconclusive") &&
        SQLite.execute(out, "DELETE FROM results WHERE result IN ('inconclusive','error')")
    ver = code_version()
    every, timeout, batch = parse(Float64, a["every"]), parse(Float64, a["timeout"]), parse(Int, a["batch"])
    stop = Threads.Atomic{Bool}(false)
    @info "ccz watcher" run code_version = ver test_source_sha256 = SOURCE_SHA threads = Threads.nthreads()
    total, maxid = 0, 0
    while !isfile(stopfile)
        cursor = parse(Int, meta_get(out, "cursor", "0"))
        rows, total, maxid = ledger_fetch(run, cursor, batch)
        if isempty(rows)
            write_json(jsonpath, summary(out, run, total, maxid, ver, "idle"))
            t = time()
            while time() - t < every && !isfile(stopfile)
                sleep(1)
            end
            continue
        end
        # Classes stored by an interrupted chunk are skipped (resume inside a chunk).
        done = Set(Int(r.class_id) for r in DBInterface.execute(out,
            "SELECT class_id FROM results WHERE class_id > ?", (cursor,)))
        todo = filter(r -> !(r[1] in done), rows)
        res = Vector{Any}(nothing, length(todo))
        Threads.@threads :dynamic for i in eachindex(todo)
            (stop[] || isfile(stopfile)) && (stop[] = true; continue)
            res[i] = run_one(todo[i], timeout)
        end
        store!(out, [x for x in res if x !== nothing], ver)
        for (i, x) in pairs(res)
            (x === nothing || x.w === nothing) && continue
            replay_one!(out, x.sha, todo[i][4])
        end
        # The cursor advances only over a completely stored chunk.
        all(!isnothing, res) && meta_set!(out, "cursor", rows[end][1])
        write_json(jsonpath, summary(out, run, total, maxid, ver, "running"))
        stop[] && break
    end
    write_json(jsonpath, summary(out, run, total, maxid, ver, "stopped"))
    close(out)
    @info "ccz watcher stopped"
end

function main(argv)
    a = parse_args(argv)
    haskey(a, "watch") ? watch_main(a) : batch_main(a)
end

main(ARGS)
