"""Open the derived corpus classification cache inside the signature index."""
function _classification_index(path)
    isfile(path) || throw(ArgumentError("signature index not found: $path"))
    idx=SQLite.DB(path)
    SQLite.execute(idx,"PRAGMA busy_timeout=10000")
    SQLite.execute(idx,"PRAGMA journal_mode=WAL")
    for sql in (
        "CREATE TABLE IF NOT EXISTS ccz_classification_meta(n INTEGER PRIMARY KEY,input_sha256 TEXT NOT NULL,records INTEGER NOT NULL,signatures INTEGER NOT NULL,singletons INTEGER NOT NULL)",
        "CREATE TABLE IF NOT EXISTS ccz_bucket_members(n INTEGER NOT NULL,source TEXT NOT NULL,member_idx INTEGER NOT NULL,sigma_hash TEXT NOT NULL,lut_sha256 TEXT NOT NULL,PRIMARY KEY(n,source,member_idx)) WITHOUT ROWID",
        "CREATE TABLE IF NOT EXISTS ccz_bucket_luts(n INTEGER NOT NULL,lut_sha256 TEXT NOT NULL,sigma_hash TEXT NOT NULL,lut BLOB NOT NULL,component TEXT,PRIMARY KEY(n,lut_sha256)) WITHOUT ROWID",
        "CREATE INDEX IF NOT EXISTS ix_bucket_luts_sigma ON ccz_bucket_luts(n,sigma_hash)",
        "CREATE TABLE IF NOT EXISTS ccz_bucket_results(n INTEGER NOT NULL,sigma_hash TEXT NOT NULL,records INTEGER NOT NULL,distinct_luts INTEGER NOT NULL,components INTEGER NOT NULL,unresolved_pairs INTEGER NOT NULL,status TEXT NOT NULL,updated_utc TEXT NOT NULL,PRIMARY KEY(n,sigma_hash)) WITHOUT ROWID",
        "CREATE VIEW IF NOT EXISTS ccz_classification_summary AS "*_CLASSIFICATION_SUMMARY_SQL,
    )
        SQLite.execute(idx,sql)
    end
    idx
end

const _CLASSIFICATION_SUMMARY_SQL="""
    SELECT m.n,m.input_sha256,m.records,m.signatures,m.singletons,
        COUNT(b.sigma_hash) prepared_buckets,
        COALESCE(SUM(b.records),0) shared_records,
        COALESCE(SUM(b.distinct_luts),0) shared_distinct_luts,
        COALESCE(SUM(b.records-b.distinct_luts),0) duplicate_records_removed,
        COALESCE(SUM(b.components),0) shared_components,
        COALESCE(SUM(b.unresolved_pairs),0) unresolved_component_pairs,
        m.signatures+COALESCE(SUM(CASE WHEN b.unresolved_pairs=0 THEN b.components-1 ELSE 0 END),0) class_count_lower_bound,
        m.records-COALESCE(SUM(b.records-b.components),0) component_count_upper_bound,
        CASE WHEN m.signatures=m.singletons+COUNT(b.sigma_hash)
            AND COALESCE(SUM(b.unresolved_pairs),0)=0
            THEN m.singletons+COALESCE(SUM(b.components),0) END exact_class_count
    FROM ccz_classification_meta m LEFT JOIN ccz_bucket_results b ON b.n=m.n
    GROUP BY m.n
    """

"""Bind an index snapshot to its exact rows and current catalog representations."""
function _classification_inputs(db,idx,n;sources=nothing)
    sources===nothing && _assert_sigma_coverage(idx,n;db)
    filter="n=?"*(sources===nothing ? "" : " AND source IN ("*join(fill("?",length(sources)),',')*")")
    args=sources===nothing ? (n,) : (n,sources...)
    if sources!==nothing
        actual=Set(String(r.source) for r in DBInterface.execute(idx,"SELECT DISTINCT source FROM ccz_sigma_index WHERE $filter",args))
        actual==Set(sources) || error("frozen catalog sources are missing")
        for source in sources
            coverage=[Int(r.indexed) for r in DBInterface.execute(idx,"SELECT indexed FROM sigma_coverage WHERE source=? AND n IN (?,-1)",(source,n))]
            coverage==[1] || error("incomplete frozen source coverage: $source")
        end
    end
    ctx=SHA.SHA2_256_CTX()
    for row in DBInterface.execute(idx,"SELECT source,COUNT(*) c,COUNT(DISTINCT member_idx) d,MIN(member_idx) lo,MAX(member_idx) hi FROM ccz_sigma_index WHERE $filter GROUP BY source",args)
        source=String(row.source)
        if source=="functions"
            actual=Set(Int(r.id) for r in DBInterface.execute(db,"SELECT id FROM functions WHERE n=? AND is_apn=1 AND is_quadratic=1",(n,)))
            indexed=Set(Int(r.member_idx) for r in DBInterface.execute(idx,"SELECT member_idx FROM ccz_sigma_index WHERE n=? AND source='functions'",(n,)))
            actual==indexed && row.c==length(actual) || error("curated index coverage changed")
        else
            info=corpus_info(db,source)
            info!==nothing && info.n==info.m==n && info.encoding=="quadratic-coeffs-v1" &&
                row.c==row.d==row.hi==info.member_count && row.lo==1 ||
                error("incomplete or duplicate index records for $source")
            corpus_digest(db,source)==info.store_sha256 || error("corpus bytes changed for $source")
            SHA.update!(ctx,codeunits(string(source,':',info.n,':',info.modulus,':',info.encoding,':',info.store_sha256,'\n')))
        end
    end
    for row in DBInterface.execute(db,"SELECT id,lut_sha256 FROM functions WHERE n=? AND is_apn=1 AND is_quadratic=1 ORDER BY id",(n,))
        F=load_sbox(db,Int(row.id))
        lut_sha256_hex(F)==row.lut_sha256 || error("curated LUT hash mismatch")
        SHA.update!(ctx,codeunits(string(row.id,':',row.lut_sha256,'\n')))
    end
    for row in DBInterface.execute(idx,"SELECT source,member_idx,sigma_hash FROM ccz_sigma_index WHERE $filter ORDER BY source,member_idx,sigma_hash",args)
        SHA.update!(ctx,codeunits(string(row.source,':',row.member_idx,':',row.sigma_hash,'\n')))
    end
    summary=only(NamedTuple(r) for r in DBInterface.execute(idx,
        "SELECT COUNT(*) signatures,SUM(k) records,SUM(k=1) singletons FROM (SELECT COUNT(*) k FROM ccz_sigma_index WHERE $filter GROUP BY sigma_hash)",args))
    (;input_sha256=bytes2hex(SHA.digest!(ctx)),summary...)
end

"""
    deduplicate_signature_buckets!(db; n=8, path=sigma_index_path(), rebuild=false)

Reconstruct and verify LUTs in every repeated-signature bucket. Store one LUT
per exact content address and preserve every source/member alias in the derived
index. Singleton signatures already imply distinct LUTs. Checkpoint one bucket
per transaction; unchanged inputs resume, changed inputs require `rebuild=true`.
Original corpora and curated entries retain their published member identities.
"""
function deduplicate_signature_buckets!(db::SQLite.DB;n::Int=8,path=sigma_index_path(),rebuild::Bool=false)
    idx=_classification_index(path)
    try
        inputs=_classification_inputs(db,idx,n)
        prior=[NamedTuple(r) for r in DBInterface.execute(idx,"SELECT * FROM ccz_classification_meta WHERE n=?",(n,))]
        !isempty(prior) && only(prior).input_sha256!=inputs.input_sha256 && !rebuild &&
            error("classification inputs changed; rebuild the derived classification explicitly")
        if rebuild || isempty(prior)
            SQLite.transaction(idx) do
                for table in ("ccz_bucket_members","ccz_bucket_luts","ccz_bucket_results","ccz_classification_meta")
                    SQLite.execute(idx,"DELETE FROM $table WHERE n=?",(n,))
                end
                SQLite.execute(idx,"INSERT INTO ccz_classification_meta VALUES(?,?,?,?,?)",
                    (n,inputs.input_sha256,inputs.records,inputs.signatures,inputs.singletons))
            end
        end
        buckets=[NamedTuple(r) for r in DBInterface.execute(idx,
            "SELECT sigma_hash,COUNT(*) c FROM ccz_sigma_index WHERE n=? GROUP BY sigma_hash HAVING COUNT(*)>1 ORDER BY sigma_hash",(n,))]
        tables=Dict{Int,Vector{Vector{Int}}}()
        for (bi,bucket) in enumerate(buckets)
            hash=String(bucket.sigma_hash)
            done=only(Int(r.c) for r in DBInterface.execute(idx,"SELECT COUNT(*) c FROM ccz_bucket_results WHERE n=? AND sigma_hash=?",(n,hash)))
            done>0 && continue
            members=[NamedTuple(r) for r in DBInterface.execute(idx,
                "SELECT source,member_idx FROM ccz_sigma_index WHERE n=? AND sigma_hash=? ORDER BY source,member_idx",(n,hash))]
            luts=Dict{String,Vector{UInt8}}()
            aliases=Tuple{String,Int,String}[]
            for member in members
                source=String(member.source);id=Int(member.member_idx)
                F=if source=="functions"
                    load_sbox(db,id)
                else
                    info=corpus_info(db,source);mod=Int(info.modulus)
                    tab=get!(()->monomial_power_table(n,mod),tables,mod)
                    SBox{n}(decode_quadratic_lut(corpus_coefficients(db,source,id),n,mod;powtab=tab))
                end
                bytes=canonical_lut_bytes(F);sha=lut_sha256_hex(F)
                if haskey(luts,sha)
                    luts[sha]==bytes || error("LUT hash collision")
                else
                    sigma_hash(F)==hash || error("invalid APN or stale signature at $source:$id")
                    luts[sha]=bytes
                end
                push!(aliases,(source,id,sha))
            end
            SQLite.transaction(idx) do
                for (sha,bytes) in luts
                    SQLite.execute(idx,"INSERT INTO ccz_bucket_luts VALUES(?,?,?,?,?)",(n,sha,hash,bytes,sha))
                end
                for (source,id,sha) in aliases
                    SQLite.execute(idx,"INSERT INTO ccz_bucket_members VALUES(?,?,?,?,?)",(n,source,id,hash,sha))
                end
                k=length(luts)
                SQLite.execute(idx,"INSERT INTO ccz_bucket_results VALUES(?,?,?,?,?,?,?,?)",
                    (n,hash,length(members),k,k,k*(k-1)÷2,k==1 ? "complete" : "deduplicated",_utc_now_iso()))
            end
            println("deduplicated bucket $bi/$(length(buckets)): $(length(members)) records -> $(length(luts)) LUTs")
            flush(stdout)
        end
        classification_summary(;n,path)
    finally
        close(idx)
    end
end

"""
    classification_summary(; n=8, path=sigma_index_path())

Stored snapshot counts. An exact class count is returned only if all repeated
buckets have complete separation evidence. Derived results depend on the VBF
solver and the frozen indexed reference, not a classification of every APN.
"""
function classification_summary(;n::Int=8,path=sigma_index_path())
    idx=SQLite.DB(path)
    try
        only(NamedTuple(r) for r in DBInterface.execute(idx,
            "SELECT * FROM ccz_classification_summary WHERE n=?",(n,)))
    finally
        close(idx)
    end
end

"""Read positive components and current-implementation negative evidence."""
function _classification_state(db,idx,n,solver)
    luts=Dict(String(r.lut_sha256)=>_sbox_from_blob(Vector{UInt8}(r.lut),n) for r in
        DBInterface.execute(idx,"SELECT lut_sha256,lut FROM ccz_bucket_luts WHERE n=?",(n,)))
    parent=Dict(id=>id for id in keys(luts))
    function root(id)
        if parent[id]!=id
            parent[id]=root(parent[id])
        end
        parent[id]
    end
    negative=Set{Tuple{String,String}}()
    function accept(row;replay=true)
        a,b=String(row.left_sha256),String(row.right_sha256)
        haskey(luts,a) && haskey(luts,b) || return
        if row.status=="equivalent"
            (!replay || verify_equivalence_check(row,luts[a],luts[b])) || error("invalid stored positive check")
            ra,rb=root(a),root(b);parent[max(ra,rb)]=min(ra,rb)
        elseif row.status=="inequivalent" && row.solver_sha256==solver && row.julia_version==string(VERSION)
            proof=TOML.parse(row.evidence)
            proof["status"]=="exhaustive_$(row.relation)_inequivalent" && push!(negative,minmax(a,b))
        end
    end
    store=_open_equivalence_checks(db)
    if store!==nothing
        try
            for row in DBInterface.execute(store,"SELECT * FROM equivalence_checks WHERE n=? AND relation IN ('ea','ccz') ORDER BY id",(n,))
                accept(NamedTuple(row))
            end
        finally
            close(store)
        end
    end
    (;luts,parent,root,negative,accept)
end

"""Checkpoint components and unresolved pairs from the actual saved evidence."""
function _save_classification!(idx,n,state;hash=nothing)
    groups=Dict{String,Vector{String}}()
    sql="SELECT lut_sha256,sigma_hash FROM ccz_bucket_luts WHERE n=?"*(hash===nothing ? "" : " AND sigma_hash=?")
    args=hash===nothing ? (n,) : (n,hash)
    for row in DBInterface.execute(idx,sql,args)
        push!(get!(groups,String(row.sigma_hash),String[]),String(row.lut_sha256))
    end
    separated=Set(minmax(state.root(a),state.root(b)) for (a,b) in state.negative)
    any(a==b for (a,b) in separated) && error("contradictory equivalence evidence")
    SQLite.transaction(idx) do
        for (hash,ids) in groups
            for id in ids
                SQLite.execute(idx,"UPDATE ccz_bucket_luts SET component=? WHERE n=? AND lut_sha256=?",(state.root(id),n,id))
            end
            reps=Set(state.root.(ids));k=length(reps)
            proved=count(p->p[1] in reps && p[2] in reps,separated)
            unresolved=k*(k-1)÷2-proved
            SQLite.execute(idx,"UPDATE ccz_bucket_results SET components=?,unresolved_pairs=?,status=?,updated_utc=? WHERE n=? AND sigma_hash=?",
                (k,unresolved,unresolved==0 ? "complete" : "partial",_utc_now_iso(),n,hash))
        end
    end
end

"""
    classify_signature_buckets!(db; n=8, path=sigma_index_path(),
        timeout_seconds=1, max_nodes=1_000_000, workers=Threads.nthreads(),
        max_pairs=typemax(Int), algorithm=:optimized)

Deduplicate, then compare exact LUTs with running class representatives. Only
replayed positive witnesses join components. A new class representative requires
negative evidence against existing representatives; budget stops stay unresolved.
EA is used for the verified quadratic APNs (Yoshiara 2012: EA equals CCZ).
Workers compute VBF outcomes, while a single writer checkpoints bounded batches.
Rerunning reuses saved conclusive checks and retries remaining comparisons.
"""
function classify_signature_buckets!(db::SQLite.DB;n::Int=8,path=sigma_index_path(),
    timeout_seconds::Real=1,max_nodes::Int=1_000_000,max_memory_bytes::Int=512*1024^2,
    workers::Int=Threads.nthreads(),max_pairs::Int=typemax(Int),algorithm::Symbol=:optimized)
    timeout_seconds>=0 && max_nodes>=0 && max_memory_bytes>=0 && workers>0 && max_pairs>=0 ||
        throw(ArgumentError("invalid classification budget"))
    algorithm in (:paper,:optimized) || throw(ArgumentError("unknown native algorithm"))
    deduplicate_signature_buckets!(db;n,path)
    idx=_classification_index(path)
    store=nothing
    try
        store=_open_equivalence_checks(db;create=true)
        solver=equivalence_solver_fingerprint()
        state=_classification_state(db,idx,n,solver)
        groups=Dict{String,Vector{String}}()
        for row in DBInterface.execute(idx,"SELECT lut_sha256,sigma_hash FROM ccz_bucket_luts WHERE n=? ORDER BY lut_sha256",(n,))
            push!(get!(groups,String(row.sigma_hash),String[]),String(row.lut_sha256))
        end
        attempted=0;attempted_pairs=Set{Tuple{String,String}}()
        width=max(1,min(workers,Threads.nthreads()))
        _save_classification!(idx,n,state)
        for (bi,hash) in enumerate(sort!(collect(keys(groups))))
            anchors=String[]
            while attempted<max_pairs
                reps=sort!(unique(state.root.(groups[hash])))
                separated=Set(minmax(state.root(a),state.root(b)) for (a,b) in state.negative)
                any(a==b for (a,b) in separated) && error("contradictory equivalence evidence")
                anchors=unique(state.root.(anchors))
                eligible=[r for r in reps if !(r in anchors) && all(a->minmax(a,r) in separated,anchors)]
                isempty(eligible) && break
                anchor=first(eligible);push!(anchors,anchor)
                targets=[r for r in reps if r!=anchor && !(minmax(anchor,r) in separated) && !(minmax(anchor,r) in attempted_pairs)]
                for start in 1:(4width):length(targets)
                    attempted>=max_pairs && break
                    count=min(4width,length(targets)-start+1,max_pairs-attempted)
                    batch=targets[start:start+count-1]
                    pairs=[minmax(state.root(anchor),state.root(target)) for target in batch if state.root(anchor)!=state.root(target)]
                    proofs=Vector{Any}(undef,length(pairs))
                    next=Threads.Atomic{Int}(1)
                    @sync for _ in 1:min(width,length(pairs))
                        Threads.@spawn begin
                            while true
                                i=Threads.atomic_add!(next,1);i>length(pairs) && break
                                a,b=pairs[i]
                                proofs[i]=equivalence_evidence(state.luts[a],state.luts[b];relation=:ea,
                                    timeout_seconds,max_nodes,max_memory_bytes,algorithm)
                            end
                        end
                    end
                    SQLite.transaction(store) do
                        for (i,(a,b)) in enumerate(pairs)
                            row=_store_equivalence_check!(db,state.luts[a],state.luts[b],proofs[i];relation=:ea,
                                timeout_seconds,max_nodes,max_memory_bytes,solver,algorithm,store)
                            state.accept(row;replay=false)
                            push!(attempted_pairs,minmax(a,b));attempted+=1
                        end
                    end
                    println("classified bucket $bi/$(length(groups)): $attempted checks; $(length(unique(state.root.(groups[hash])))) components remain")
                    flush(stdout)
                end
            end
            _save_classification!(idx,n,state;hash)
        end
        _save_classification!(idx,n,state)
        (;classification_summary(;n,path)...,checks_this_session=attempted,solver_sha256=solver)
    finally
        store===nothing || close(store)
        close(idx)
    end
end
