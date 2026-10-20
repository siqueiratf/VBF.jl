"""Immutable, bounded cold storage for completed V5 coverage payloads.

Only `chunks.evidence` moves: its indexed coverage envelope remains in SQLite.
Paths, candidate identities, admission decisions and coverage cursors never move.
Use `_closure_foreach_chunk` for logical reads, or `closure_rehydrate_segments!`
before handing a checkpoint to older code or a raw SQL consumer of evidence.
Cold storage needs a separate budget; sealing does not bound total evidence.
"""
const _CLOSURE_SEGMENT_MAGIC = collect(codeunits("VBFSEG01"))
const _CLOSURE_SEGMENT_PREFIX = "VBFSEG01:"
const _CLOSURE_SEGMENT_MAX_BYTES = 256*1024^2

mutable struct _ClosureSegmentCache
    digest::String
    rows::Vector{Dict{String,Any}}
end
_ClosureSegmentCache() = _ClosureSegmentCache("",Dict{String,Any}[])

function _closure_segment_schema!(db)
    _closure_exec(db,"CREATE TABLE IF NOT EXISTS closure_evidence_segments(digest TEXT PRIMARY KEY,logical_sha256 TEXT NOT NULL,raw_bytes INTEGER NOT NULL,compressed_bytes INTEGER NOT NULL,rows INTEGER NOT NULL,created_utc TEXT NOT NULL)")
    _closure_exec(db,"CREATE TABLE IF NOT EXISTS closure_segment_chunks(job_id INTEGER NOT NULL,first_x INTEGER NOT NULL,segment_digest TEXT NOT NULL REFERENCES closure_evidence_segments(digest),ordinal INTEGER NOT NULL,PRIMARY KEY(job_id,first_x),UNIQUE(segment_digest,ordinal),FOREIGN KEY(job_id,first_x) REFERENCES chunks(job_id,first_x))")
    # Sealing must not rescan every previously archived envelope for each batch.
    _closure_exec(db,"CREATE INDEX IF NOT EXISTS closure_chunks_hot ON chunks(job_id,first_x) WHERE NOT (typeof(evidence)='text' AND substr(evidence,1,9)='VBFSEG01:')")
end
_closure_has_segments(db) = _closure_count(db,"SELECT COUNT(*) n FROM sqlite_master WHERE type='table' AND name='closure_evidence_segments'")==1

function _closure_segment_reference(value)
    value isa AbstractString && startswith(value,_CLOSURE_SEGMENT_PREFIX) || return nothing
    matched=match(r"^VBFSEG01:([0-9a-f]{64}):([1-9][0-9]*)$",value)
    matched===nothing && error("invalid external coverage reference")
    ordinal=tryparse(Int,matched.captures[2])
    ordinal===nothing && error("external coverage ordinal overflow")
    (digest=String(matched.captures[1]),ordinal=ordinal)
end

function _closure_segment_directory(db,directory=nothing)
    directory===nothing || return abspath(directory)
    rows=_closure_rows(db,"PRAGMA database_list")
    main=only(filter(r->r["name"]=="main",rows))["file"]
    isempty(main) && error("external coverage requires a file-backed checkpoint")
    dirname(abspath(main))
end
function _closure_segment_root(db,directory=nothing)
    base=_closure_segment_directory(db,directory)
    rows=_closure_rows(db,"SELECT value FROM metadata WHERE key='closure_segment_root'")
    root=isempty(rows) ? "cold" : String(only(rows)["value"])
    isabspath(root) ? root : abspath(joinpath(base,root))
end

function _closure_segment_encode(rows)
    io=IOBuffer();write(io,_CLOSURE_SEGMENT_MAGIC);write(io,htol(UInt32(length(rows))))
    for row in rows
        for key in _CLOSURE_LEDGER_FIELDS
            value=row[key]
            value isa Integer && value>=0 || error("invalid external coverage envelope")
            write(io,htol(UInt64(value)))
        end
        evidence=row["evidence"]
        _closure_segment_reference(evidence)===nothing || error("coverage is already external")
        evidence isa Union{AbstractString,Vector{UInt8}} || error("invalid coverage storage type")
        write(io,UInt8(evidence isa AbstractString ? 0 : 1))
        bytes=evidence isa AbstractString ? codeunits(evidence) : evidence
        write(io,htol(UInt64(length(bytes))));write(io,bytes)
    end
    take!(io)
end
function _closure_segment_decode(raw,expected_rows)
    io=IOBuffer(raw)
    read(io,8)==_CLOSURE_SEGMENT_MAGIC || error("unknown external coverage schema")
    n=Int(ltoh(read(io,UInt32)))
    1<=n==expected_rows<=65536 || error("invalid external coverage row count")
    rows=Dict{String,Any}[]
    for _ in 1:n
        row=Dict{String,Any}()
        for key in _CLOSURE_LEDGER_FIELDS
            value=ltoh(read(io,UInt64));value<=typemax(Int) || error("external coverage envelope overflow")
            row[key]=Int(value)
        end
        kind=read(io,UInt8);kind in (0,1) || error("invalid external coverage storage type")
        nbytes=ltoh(read(io,UInt64));nbytes<=bytesavailable(io) || error("truncated external coverage payload")
        bytes=read(io,Int(nbytes));row["evidence"]=kind==0 ? String(bytes) : bytes
        _closure_segment_reference(row["evidence"])===nothing || error("nested external coverage reference")
        push!(rows,row)
    end
    eof(io) || error("trailing external coverage bytes")
    rows
end

function _closure_segment_validate_metadata(meta)
    raw=meta["raw_bytes"];compressed=meta["compressed_bytes"];rows=meta["rows"]
    raw isa Integer && 12<=raw<=_CLOSURE_SEGMENT_MAX_BYTES || error("external coverage exceeds decode budget")
    compressed isa Integer && 0<compressed<=_CLOSURE_SEGMENT_MAX_BYTES+1024^2 || error("external coverage exceeds compressed-byte budget")
    rows isa Integer && 1<=rows<=65536 || error("invalid external coverage row count")
    meta["logical_sha256"] isa AbstractString && occursin(r"^[0-9a-f]{64}$",meta["logical_sha256"]) || error("invalid external coverage logical digest")
    nothing
end

function _closure_segment_load(db,digest;directory=nothing)
    occursin(r"^[0-9a-f]{64}$",digest) || error("invalid external coverage digest")
    meta=only(_closure_rows(db,"SELECT * FROM closure_evidence_segments WHERE digest=?",(digest,)))
    _closure_segment_validate_metadata(meta)
    raw_bytes=Int(meta["raw_bytes"])
    12<=raw_bytes<=_CLOSURE_SEGMENT_MAX_BYTES || error("external coverage exceeds decode budget")
    path=joinpath(_closure_segment_root(db,directory),digest*".zst")
    islink(path) && error("external coverage artifacts must not be symlinks")
    isfile(path) || error("missing external coverage segment: $path")
    filesize(path)==meta["compressed_bytes"] || error("external coverage file length changed")
    compressed=open(io->read(io,Int(meta["compressed_bytes"])+1),path)
    length(compressed)==meta["compressed_bytes"] && bytes2hex(SHA.sha256(compressed))==digest || error("external coverage compressed digest mismatch")
    stream=CodecZstd.ZstdDecompressorStream(IOBuffer(compressed))
    raw=try read(stream,raw_bytes+1) finally close(stream) end
    length(raw)==raw_bytes && bytes2hex(SHA.sha256(raw))==meta["logical_sha256"] || error("external coverage logical digest mismatch")
    _closure_segment_decode(raw,Int(meta["rows"]))
end

function _closure_resolve_chunk(db,row,cache::_ClosureSegmentCache;directory=nothing)
    reference=_closure_segment_reference(row["evidence"])
    reference===nothing && return row
    binding=only(_closure_rows(db,"SELECT segment_digest,ordinal FROM closure_segment_chunks WHERE job_id=? AND first_x=?",(row["job_id"],row["first_x"])))
    binding["segment_digest"]==reference.digest && binding["ordinal"]==reference.ordinal || error("external coverage reference differs from its binding")
    if cache.digest!=reference.digest
        cache.rows=_closure_segment_load(db,reference.digest;directory)
        cache.digest=reference.digest
    end
    1<=reference.ordinal<=length(cache.rows) || error("external coverage ordinal is out of bounds")
    saved=cache.rows[reference.ordinal]
    all(saved[key]==row[key] for key in _CLOSURE_LEDGER_FIELDS) || error("external coverage envelope differs from sealed payload")
    saved
end
_closure_resolve_chunk(db,row::SQLite.Row,cache::_ClosureSegmentCache;kwargs...) =
    _closure_resolve_chunk(db,Dict{String,Any}(String(k)=>row[k] for k in propertynames(row)),cache;kwargs...)

function _closure_segment_fsync(io)
    flush(io)
    ccall(:fsync,Cint,(Cint,),fd(io))==0 || error("cannot synchronize external coverage file")
end
function _closure_segment_sync_directory(directory)
    descriptor=ccall(:open,Cint,(Cstring,Cint),directory,0)
    descriptor>=0 || error("cannot open external coverage directory")
    try
        ccall(:fsync,Cint,(Cint,),descriptor)==0 || error("cannot synchronize external coverage directory")
    finally
        ccall(:close,Cint,(Cint,),descriptor)
    end
end
function _closure_segment_publish(root,digest,compressed)
    mkpath(root);path=joinpath(root,digest*".zst")
    islink(path) && error("external coverage artifacts must not be symlinks")
    if isfile(path)
        filesize(path)==length(compressed) && open(io->read(io,length(compressed)+1),path)==compressed || error("existing external coverage artifact differs")
        _closure_segment_sync_directory(root)
        return path
    end
    temporary,io=mktemp(root)
    try
        write(io,compressed);_closure_segment_fsync(io);close(io)
        mv(temporary,path;force=false);chmod(path,0o444)
        _closure_segment_sync_directory(root)
        path
    finally
        isopen(io) && close(io)
        isfile(temporary) && rm(temporary)
    end
end

"""
    closure_seal_segments!(store; cold_directory=joinpath(store.directory,"cold"),
                           max_rows=256,max_bytes=16*1024^2)

Publish at most one bounded immutable segment of completed V5 coverage payloads,
then atomically replace their hot evidence with indexed references. Coverage
envelopes stay in `chunks`; scientific cursors and all paths remain unchanged.
Call on the sole coordinator between computation/application transactions.

Publication precedes the SQLite transaction. A crash before commit leaves a
harmless unreferenced content-addressed file; a retry reuses it. Sealing frees
SQLite pages for reuse, not necessarily filesystem bytes. Compact a stopped
checkpoint separately when physical shrinkage is needed. Preserve the entire
cold root when moving a checkpoint, or use `closure_export_checkpoint`.
"""
function closure_seal_segments!(s::ClosureStore;cold_directory=joinpath(s.directory,"cold"),max_rows=256,max_bytes=16*1024^2)
    max_rows isa Integer && 1<=max_rows<=65536 || throw(ArgumentError("max_rows must be 1..65536"))
    max_bytes isa Integer && 12<=max_bytes<=_CLOSURE_SEGMENT_MAX_BYTES || throw(ArgumentError("invalid segment byte budget"))
    SQLite.intransaction(s.db) && error("seal coverage between coordinator transactions")
    _closure_segment_schema!(s.db)
    root=abspath(cold_directory)
    prior=_closure_rows(s.db,"SELECT value FROM metadata WHERE key='closure_segment_root'")
    isempty(prior) || _closure_segment_root(s.db,s.directory)==root || error("cold root changed; relocate existing artifacts explicitly")
    rows=Dict{String,Any}[];size=12
    selected=DBInterface.execute(s.db,"SELECT c.* FROM chunks c INDEXED BY closure_chunks_hot JOIN jobs j ON j.id=c.job_id LEFT JOIN closure_segment_chunks e ON e.job_id=c.job_id AND e.first_x=c.first_x WHERE NOT (typeof(c.evidence)='text' AND substr(c.evidence,1,9)='VBFSEG01:') AND j.kind='v5' AND j.status='done' AND e.job_id IS NULL ORDER BY c.job_id,c.first_x LIMIT ?",(max_rows,))
    try
        for value in selected
            evidence=value.evidence
            bytes=sizeof(evidence)
            size+49+bytes<=max_bytes || (isempty(rows) ? error("one coverage payload exceeds the segment byte budget") : break)
            row=Dict{String,Any}(key=>(key=="evidence" && evidence isa Vector{UInt8} ? copy(evidence) : value[Symbol(key)]) for key in (_CLOSURE_LEDGER_FIELDS...,"evidence"))
            _closure_unpack_chunks(row)
            push!(rows,row);size+=49+bytes
        end
    finally
        DBInterface.close!(selected)
    end
    isempty(rows) && return Dict("segments"=>0,"rows"=>0,"evicted_bytes"=>0)
    raw=_closure_segment_encode(rows);length(raw)<=max_bytes || error("external coverage budget exceeded")
    compressed=transcode(CodecZstd.ZstdCompressor,raw)
    digest=bytes2hex(SHA.sha256(compressed));logical=bytes2hex(SHA.sha256(raw))
    _closure_segment_decode(raw,length(rows))==rows || error("external coverage roundtrip changed rows")
    path=_closure_segment_publish(root,digest,compressed)
    # Verify the published bytes before committing any reference to them.
    bytes2hex(open(SHA.sha256,path))==digest || error("published external coverage digest mismatch")
    _closure_transaction(s) do
        stored_root=relpath(root,s.directory)
        startswith(stored_root,"..") && (stored_root=root)
        _closure_exec(s.db,"INSERT OR IGNORE INTO metadata VALUES('closure_segment_root',?)",(stored_root,))
        _closure_exec(s.db,"INSERT OR IGNORE INTO closure_evidence_segments VALUES(?,?,?,?,?,?)",(digest,logical,length(raw),length(compressed),length(rows),_closure_now()))
        metadata=only(_closure_rows(s.db,"SELECT logical_sha256,raw_bytes,compressed_bytes,rows FROM closure_evidence_segments WHERE digest=?",(digest,)))
        (metadata["logical_sha256"],metadata["raw_bytes"],metadata["compressed_bytes"],metadata["rows"])==
            (logical,length(raw),length(compressed),length(rows)) || error("external coverage digest has conflicting metadata")
        for (ordinal,row) in enumerate(rows)
            current=only(_closure_rows(s.db,"SELECT c.*,j.status AS job_status FROM chunks c JOIN jobs j ON j.id=c.job_id WHERE c.job_id=? AND c.first_x=?",(row["job_id"],row["first_x"])))
            current["job_status"]=="done" && all(isequal(current[k],v) for (k,v) in row) || error("coverage changed during sealing")
            marker=_CLOSURE_SEGMENT_PREFIX*digest*":"*string(ordinal)
            _closure_exec(s.db,"INSERT INTO closure_segment_chunks VALUES(?,?,?,?)",(row["job_id"],row["first_x"],digest,ordinal))
            _closure_exec(s.db,"UPDATE chunks SET evidence=? WHERE job_id=? AND first_x=?",(marker,row["job_id"],row["first_x"]))
        end
    end
    Dict("segments"=>1,"rows"=>length(rows),"evicted_bytes"=>sum(sizeof(r["evidence"]) for r in rows),"digest"=>digest,"logical_sha256"=>logical,"path"=>path,"compressed_bytes"=>length(compressed))
end

"""Return indispensable portable artifact names and their current source paths.

Checkpoint exporters must include these files automatically and bind the copied
database's operational `closure_segment_root` metadata to `"cold"`.
"""
function closure_segment_artifacts(db,directory)
    _closure_has_segments(db) || return Dict{String,String}()
    root=_closure_segment_root(db,directory)
    artifacts=Dict{String,String}()
    for row in _closure_rows(db,"SELECT digest FROM closure_evidence_segments ORDER BY digest")
        digest=String(row["digest"])
        occursin(r"^[0-9a-f]{64}$",digest) || error("invalid external coverage digest")
        path=joinpath(root,digest*".zst")
        islink(path) && error("external coverage artifacts must not be symlinks")
        artifacts[joinpath("cold",digest*".zst")]=path
    end
    artifacts
end

"""Check cold artifacts/bindings; `full=true` verifies every content digest.

The inexpensive default detects missing/truncated files and broken SQL bindings.
Every streaming logical read independently verifies compressed and logical SHA-256.
`replay=true` additionally decodes every TEXT/V1/V2 logical coverage stream. Use
that expensive audit deliberately; routine exports need not replay all cosets.
"""
function closure_verify_segments(db,directory;full=false,replay=false)
    full isa Bool && replay isa Bool || throw(ArgumentError("full/replay must be Boolean"))
    full=full || replay
    _closure_has_segments(db) || return Dict("segments"=>0,"rows"=>0,"full"=>full,"replay"=>replay)
    root=_closure_segment_root(db,directory);total=0;segments=0
    for meta in _closure_rows(db,"SELECT * FROM closure_evidence_segments ORDER BY digest")
        _closure_segment_validate_metadata(meta)
        digest=String(meta["digest"]);occursin(r"^[0-9a-f]{64}$",digest) || error("invalid external coverage digest")
        path=joinpath(root,digest*".zst")
        islink(path) && error("external coverage artifacts must not be symlinks")
        isfile(path) && filesize(path)==meta["compressed_bytes"] || error("missing or truncated external coverage segment: $path")
        bindings=_closure_rows(db,"SELECT x.ordinal,c.* FROM closure_segment_chunks x JOIN chunks c ON c.job_id=x.job_id AND c.first_x=x.first_x WHERE x.segment_digest=? ORDER BY x.ordinal",(digest,))
        length(bindings)==meta["rows"] || error("external coverage binding count differs")
        rows=full ? _closure_segment_load(db,digest;directory) : nothing
        replay && foreach(_closure_unpack_chunks,rows)
        for (ordinal,row) in enumerate(bindings)
            reference=_closure_segment_reference(row["evidence"])
            reference!==nothing && reference.digest==digest && reference.ordinal==ordinal && row["ordinal"]==ordinal || error("external coverage binding differs")
            full && !all(rows[ordinal][key]==row[key] for key in _CLOSURE_LEDGER_FIELDS) && error("external coverage envelope differs")
        end
        total+=length(bindings);segments+=1
    end
    # Also reject dangling bindings/markers, even if SQLite foreign_keys was off.
    count=_closure_count(db,"SELECT COUNT(*) n FROM closure_segment_chunks")
    count==total || error("dangling external coverage binding")
    markers=_closure_count(db,"SELECT COUNT(*) n FROM chunks WHERE typeof(evidence)='text' AND substr(evidence,1,9)='VBFSEG01:'")
    markers==total || error("external coverage marker has no binding")
    Dict("segments"=>segments,"rows"=>total,"full"=>full,"replay"=>replay)
end

function _closure_reject_segmented_clone(db)
    if _closure_has_segments(db) && _closure_count(db,"SELECT COUNT(*) n FROM closure_evidence_segments")>0
        error("checkpoint has external coverage segments; use closure_export_checkpoint or rehydrate with closure_rehydrate_segments! before this legacy copy/upgrade")
    end
    nothing
end

"""
    closure_rehydrate_segments!(store; max_segments=typemax(Int))

Restore exact original TEXT/BLOB evidence one bounded segment per transaction.
Cold artifacts remain available for rollback/audit; callers may garbage collect
unreferenced files only after publishing and verifying a replacement checkpoint.
"""
function closure_rehydrate_segments!(s::ClosureStore;max_segments=typemax(Int))
    max_segments isa Integer && max_segments>=0 || throw(ArgumentError("max_segments must be nonnegative"))
    SQLite.intransaction(s.db) && error("rehydrate coverage between coordinator transactions")
    _closure_has_segments(s.db) || return Dict("segments"=>0,"rows"=>0)
    segments=0;restored=0
    for meta in _closure_rows(s.db,"SELECT digest FROM closure_evidence_segments ORDER BY digest LIMIT ?",(max_segments,))
        digest=String(meta["digest"]);rows=_closure_segment_load(s.db,digest;directory=s.directory)
        _closure_transaction(s) do
            for (ordinal,row) in enumerate(rows)
                binding=only(_closure_rows(s.db,"SELECT segment_digest,ordinal FROM closure_segment_chunks WHERE job_id=? AND first_x=?",(row["job_id"],row["first_x"])))
                binding["segment_digest"]==digest && binding["ordinal"]==ordinal || error("external coverage restore binding differs")
                current=only(_closure_rows(s.db,"SELECT * FROM chunks WHERE job_id=? AND first_x=?",(row["job_id"],row["first_x"])))
                current["evidence"]==_CLOSURE_SEGMENT_PREFIX*digest*":"*string(ordinal) && all(current[k]==row[k] for k in _CLOSURE_LEDGER_FIELDS) || error("external coverage restore envelope differs")
                _closure_exec(s.db,"UPDATE chunks SET evidence=? WHERE job_id=? AND first_x=?",(row["evidence"],row["job_id"],row["first_x"]))
                _closure_exec(s.db,"DELETE FROM closure_segment_chunks WHERE job_id=? AND first_x=?",(row["job_id"],row["first_x"]))
            end
            _closure_exec(s.db,"DELETE FROM closure_evidence_segments WHERE digest=?",(digest,))
        end
        segments+=1;restored+=length(rows)
    end
    Dict("segments"=>segments,"rows"=>restored)
end
