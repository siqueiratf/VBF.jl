"""Lossless blocks of the original per-coset coverage records.

SQLite keeps one indexed interval per block. Its BLOB contains a versioned,
little-endian stream of all original columns, compressed with Zstandard and
protected by SHA-256. Legacy TEXT evidence remains readable. Grouping changes
neither candidate paths nor the atomic cursor transition that certifies coverage.
"""
const _CLOSURE_LEDGER_MAGIC=UInt8[0x56,0x42,0x46,0x43,0x48,0x4e,0x30,0x31] # VBFCHN01
const _CLOSURE_LEDGER_LIMIT=64*1024^2
const _CLOSURE_LEDGER_FIELDS=("job_id","first_x","next_x","total_x","capped")

_closure_unpack_chunks(row::SQLite.Row)=_closure_unpack_chunks(Dict{String,Any}(String(k)=>row[k] for k in propertynames(row)))

"""Encode complete logical rows, retaining the evidence text byte for byte."""
function _closure_pack_chunks(rows)
    1<=length(rows)<=65536 || error("invalid compact ledger block length")
    io=IOBuffer();write(io,htol(UInt32(length(rows))))
    for row in rows
        for key in _CLOSURE_LEDGER_FIELDS
            value=row[key];value isa Integer && value>=0 || error("invalid compact ledger integer")
            write(io,htol(UInt64(value)))
        end
        evidence=row["evidence"];evidence isa String || error("ledger evidence must be text")
        bytes=codeunits(evidence);write(io,htol(UInt32(length(bytes))));write(io,bytes)
    end
    raw=take!(io);length(raw)<=_CLOSURE_LEDGER_LIMIT || error("compact ledger block exceeds size limit")
    vcat(_CLOSURE_LEDGER_MAGIC,reinterpret(UInt8,[htol(UInt64(length(raw)))]),SHA.sha256(raw),
        transcode(CodecZstd.ZstdCompressor,raw))
end

"""Decode a block and verify its digest, length and SQLite coverage envelope."""
function _closure_unpack_chunks(row)
    value=row["evidence"]
    value isa AbstractString && return [Dict{String,Any}(key=>row[key] for key in (_CLOSURE_LEDGER_FIELDS...,"evidence"))]
    value isa Vector{UInt8} && length(value)>=49 && value[1:8]==_CLOSURE_LEDGER_MAGIC || error("unknown compact ledger encoding")
    size=Int(ltoh(read(IOBuffer(value[9:16]),UInt64)))
    4<=size<=_CLOSURE_LEDGER_LIMIT || error("invalid compact ledger decoded size")
    # Bound decompression before allocating the declared raw size.
    stream=CodecZstd.ZstdDecompressorStream(IOBuffer(value[49:end]))
    raw=try read(stream,size+1) finally close(stream) end
    length(raw)==size && SHA.sha256(raw)==value[17:48] || error("compact ledger checksum mismatch")
    io=IOBuffer(raw);n=Int(ltoh(read(io,UInt32)))
    1<=n<=65536 || error("invalid compact ledger row count")
    rows=Dict{String,Any}[];cursor=Int(row["first_x"]);capped=0
    for _ in 1:n
        record=Dict{String,Any}(key=>Int(ltoh(read(io,UInt64))) for key in _CLOSURE_LEDGER_FIELDS)
        len=Int(ltoh(read(io,UInt32)));len<=bytesavailable(io) || error("truncated compact ledger evidence")
        record["evidence"]=String(read(io,len))
        record["job_id"]==row["job_id"] && record["first_x"]==cursor &&
            record["total_x"]==row["total_x"] || error("compact ledger coverage mismatch")
        step=record["next_x"]-cursor
        (step==1 || (step==0 && n==1 && cursor==1 && record["total_x"]==0)) &&
            record["capped"] in (0,1) || error("invalid compact ledger coverage step")
        cursor=record["next_x"];capped|=record["capped"];push!(rows,record)
    end
    eof(io) && cursor==row["next_x"] && capped==row["capped"] || error("compact ledger envelope mismatch")
    rows
end

"""Visit original per-coset rows with bounded memory, across both encodings."""
function _closure_foreach_chunk(f,db;job_id=nothing)
    sql="SELECT * FROM chunks"*(job_id===nothing ? " ORDER BY job_id,first_x" : " WHERE job_id=? ORDER BY first_x")
    query=DBInterface.execute(db,sql,job_id===nothing ? () : (job_id,))
    try
        for row in query, record in _closure_unpack_chunks(row)
            f(record)
        end
    finally
        DBInterface.close!(query)
    end
    nothing
end

"""Encode one packet's coverage rows exactly as the ledger stores them."""
function _closure_ledger_row(job_id,chunks)
    rows=[Dict{String,Any}("job_id"=>job_id,"first_x"=>c["proof"]["first_x"],
        "next_x"=>c["proof"]["next_x"],"total_x"=>c["proof"]["total_x"],
        "capped"=>Int(c["proof"]["capped"]),"evidence"=>_closure_coset_evidence_text(c["proof"])) for c in chunks]
    firstrow=first(rows);lastrow=last(rows)
    (job_id=job_id,first_x=firstrow["first_x"],next_x=lastrow["next_x"],total_x=firstrow["total_x"],
        capped=maximum(r["capped"] for r in rows),evidence=length(rows)==1 ? firstrow["evidence"] : _closure_pack_chunks(rows))
end

"""Persist an already validated work packet as one atomic coverage interval.

`encoded` is the row of _closure_ledger_row from an in-process worker, so the
serial writer does not encode it again. The coordinator checks its envelope
against the validated cosets. A result that crossed a process boundary (for
example as JSON) has no such row, and the coordinator then encodes it here."""
function _closure_insert_chunks!(s,job_id,chunks;encoded=nothing)
    isempty(chunks) && return
    row=encoded isa NamedTuple ? encoded : _closure_ledger_row(job_id,chunks)
    row.job_id==job_id && row.first_x==first(chunks)["proof"]["first_x"] && row.next_x==last(chunks)["proof"]["next_x"] &&
        row.total_x==first(chunks)["proof"]["total_x"] && row.capped==maximum(Int(c["proof"]["capped"]) for c in chunks) ||
        error("encoded coverage envelope differs from the validated cosets")
    _closure_exec(s.db,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",(job_id,row.first_x,row.next_x,row.total_x,row.capped,row.evidence))
end
