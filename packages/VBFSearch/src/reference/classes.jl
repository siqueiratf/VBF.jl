"""Derived equivalence classes for curated catalog functions."""
const _SIGMA_STRATEGY = "ortho-derivative-sigma"
const _SIGMA_STRATEGY_CONFIRMED = "ortho-derivative-sigma-confirmed"

const _CURATED_CLASSES_DDL = (
    "CREATE TABLE IF NOT EXISTS equivalence_classes(id INTEGER PRIMARY KEY,kind TEXT NOT NULL,n INTEGER NOT NULL,canonical_id INTEGER NOT NULL,discriminator TEXT)",
    "CREATE TABLE IF NOT EXISTS class_members(class_id INTEGER NOT NULL,function_id INTEGER NOT NULL,strategy TEXT NOT NULL,PRIMARY KEY(class_id,function_id,strategy))",
    "CREATE TABLE IF NOT EXISTS curated_class_meta(inputs_sha256 TEXT NOT NULL,solver_sha256 TEXT NOT NULL)")

function _curated_inputs_digest(db)
    bytes2hex(SHA.sha256(join([string(row.id,':',row.n,':',row.lut_sha256) for row in
        DBInterface.execute(db,"SELECT id,n,lut_sha256 FROM functions WHERE is_apn=1 AND is_quadratic=1 ORDER BY id")],"\n")))
end

"""Path to regenerable curated class evidence."""
curated_classes_path() = joinpath(search_data_dir(),"curated_classes.sqlite")

"""Populate derived curated classes: EA-confirm n <= 7; label larger sigma buckets unconfirmed."""
function populate_ccz_equivalence_classes!(db::SQLite.DB;path=curated_classes_path())
    mkpath(dirname(path))
    idx=SQLite.DB(path)
    try
        for sql in _CURATED_CLASSES_DDL
            SQLite.execute(idx,sql)
        end

    buckets = Dict{Tuple{Int,String},Vector{Int}}()
    sboxes = Dict{Int,Any}()
    for r in DBInterface.execute(
        db, "SELECT id, n, lut_blob FROM functions WHERE is_apn = 1 AND is_quadratic = 1")
        id = Int(r.id); n = Int(r.n)
        s = load_sbox(db, id)
        sboxes[id] = s
        push!(get!(buckets, (n, sigma_hash(s)), Int[]), id)
    end

    CONFIRM_MAX = 7
    bkeys = sort!(collect(keys(buckets)))
    confirm_idx = [bi for (bi, (n, _)) in enumerate(bkeys) if n <= CONFIRM_MAX]
    sigmagroup_idx = [bi for (bi, (n, _)) in enumerate(bkeys) if n > CONFIRM_MAX]
    classes_of = [Vector{Vector{Int}}() for _ in bkeys]   # finalized classes per bucket
    strat_of = fill(_SIGMA_STRATEGY_CONFIRMED, length(bkeys))
    for bi in sigmagroup_idx
        classes_of[bi] = [sort(buckets[bkeys[bi]])]
        strat_of[bi] = _SIGMA_STRATEGY
    end
    pending = [bi in confirm_idx ? sort(buckets[bkeys[bi]]) : Int[] for bi in eachindex(bkeys)]
    while any(!isempty, pending)
        jobs = Tuple{Int,Int}[]
        for bi in eachindex(pending)
            p = pending[bi]
            if length(p) == 1
                push!(classes_of[bi], [p[1]]); empty!(pending[bi])
            elseif length(p) >= 2
                for m in @view p[2:end]; push!(jobs, (bi, m)); end
            end
        end
        isempty(jobs) && break
        reps = [pending[bi][1] for (bi, _) in jobs]          # snapshot reps before any mutation
        res = Vector{Bool}(undef, length(jobs))
        sem = Base.Semaphore(max(1, min(Threads.nthreads(), 6)))
        let tasks = map(eachindex(jobs)) do t
                m = jobs[t][2]; rep = reps[t]
                Threads.@spawn begin
                    sboxes[m].lut == sboxes[rep].lut && return true      # identical ⇒ equivalent
                    Base.acquire(sem)
                    try
                        !isempty(ea_mappings_from_ortho_derivative(sboxes[m], sboxes[rep]))
                    finally
                        Base.release(sem)
                    end
                end
            end
            for t in eachindex(tasks); res[t] = fetch(tasks[t]); end
        end
        matched = Dict{Int,Vector{Int}}(); unmatched = Dict{Int,Vector{Int}}()
        for (t, (bi, m)) in enumerate(jobs)
            push!(get!(res[t] ? matched : unmatched, bi, Int[]), m)
        end
        for bi in eachindex(pending)
            length(pending[bi]) >= 2 || continue
            rep = pending[bi][1]
            push!(classes_of[bi], sort(vcat([rep], get(matched, bi, Int[]))))
            pending[bi] = sort(get(unmatched, bi, Int[]))
        end
    end
    splits = classes_of

    nclasses = 0
    SQLite.transaction(idx) do
    SQLite.execute(idx, "DELETE FROM class_members WHERE strategy IN (" *
        _sql_quote(_SIGMA_STRATEGY) * ", " * _sql_quote(_SIGMA_STRATEGY_CONFIRMED) * ")")
    SQLite.execute(idx, "DELETE FROM equivalence_classes WHERE kind = 'CCZ'")

    for (bi, (n, h)) in enumerate(bkeys)
        for cls in splits[bi]
            canon = cls[1]
            SQLite.execute(idx, string(
                "INSERT INTO equivalence_classes (kind, n, canonical_id, discriminator) VALUES (",
                "'CCZ', ", n, ", ", canon, ", ", _sql_quote(h), ")"))
            cid = 0
            for rr in DBInterface.execute(idx, "SELECT last_insert_rowid() id"); cid = Int(rr.id); end
            for fid in cls
                SQLite.execute(idx, string(
                    "INSERT INTO class_members (class_id, function_id, strategy) VALUES (",
                    cid, ", ", fid, ", ", _sql_quote(strat_of[bi]), ")"))
            end
            nclasses += 1
        end
    end
    SQLite.execute(idx,"DELETE FROM curated_class_meta")
    SQLite.execute(idx,"INSERT INTO curated_class_meta VALUES(?,?)",(_curated_inputs_digest(db),equivalence_solver_fingerprint()))
    end
    nclasses
    finally
        close(idx)
    end
end

"""Read confirmed curated class representatives, refusing absent or stale evidence."""
function ccz_class_representatives(db::SQLite.DB;n::Integer,path=curated_classes_path())
    isfile(path) || error("missing class evidence; run make -C packages/VBFSearch/tools classes")
    idx=SQLite.DB("file:"*abspath(path)*"?mode=ro")
    try
        exists=only(Int(row.c) for row in DBInterface.execute(idx,"SELECT COUNT(*) c FROM sqlite_master WHERE name='curated_class_meta'"))
        exists==1 || error("missing class evidence; run the catalog classes command")
        rows=[NamedTuple(row) for row in DBInterface.execute(idx,"SELECT * FROM curated_class_meta")]
        length(rows)==1 || error("incomplete class evidence")
        meta=only(rows)
        meta.inputs_sha256==_curated_inputs_digest(db) && meta.solver_sha256==equivalence_solver_fingerprint() || error("stale class evidence; rebuild catalog classes")
        ids=[Int(row.canonical_id) for row in DBInterface.execute(idx,
            "SELECT e.canonical_id FROM equivalence_classes e WHERE e.n=? AND NOT EXISTS(SELECT 1 FROM class_members m WHERE m.class_id=e.id AND m.strategy!=?) ORDER BY e.canonical_id",
            (n,_SIGMA_STRATEGY_CONFIRMED))]
        n>7 && any(row->true,DBInterface.execute(db,"SELECT 1 FROM functions WHERE n=? AND is_apn=1 AND is_quadratic=1 LIMIT 1",(n,))) && error("large-dimension signature buckets are not confirmed classes")
        [(id=id,sbox=load_sbox(db,id)) for id in ids]
    finally
        close(idx)
    end
end
