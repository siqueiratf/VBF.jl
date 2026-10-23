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
    _closure_encode_chunk_bytes(take!(io))
end

"""Apply the unchanged digest, header and compression to a logical row stream."""
function _closure_encode_chunk_bytes(raw::Vector{UInt8};normalized=_closure_v2_from_raw(raw))
    length(raw)<=_CLOSURE_LEDGER_LIMIT || error("compact ledger block exceeds size limit")
    vcat(normalized===nothing ? _CLOSURE_LEDGER_MAGIC : _CLOSURE_LEDGER_MAGIC_V2,reinterpret(UInt8,[htol(UInt64(length(raw)))]),SHA.sha256(raw),
        transcode(CodecZstd.ZstdCompressor,normalized===nothing ? raw : normalized))
end

"""Decode a block and verify its digest, length and SQLite coverage envelope."""
function _closure_unpack_chunks(row)
    value=row["evidence"]
    _closure_segment_reference(value)===nothing || error("external coverage payload requires a checkpoint-aware read; use _closure_foreach_chunk or rehydrate")
    value isa AbstractString && return [Dict{String,Any}(key=>row[key] for key in (_CLOSURE_LEDGER_FIELDS...,"evidence"))]
    value isa Vector{UInt8} && length(value)>=49 && value[1:8] in (_CLOSURE_LEDGER_MAGIC,_CLOSURE_LEDGER_MAGIC_V2) || error("unknown compact ledger encoding")
    size=Int(ltoh(read(IOBuffer(value[9:16]),UInt64)))
    4<=size<=_CLOSURE_LEDGER_LIMIT || error("invalid compact ledger decoded size")
    # Bound decompression before allocating the declared raw size.
    stream=CodecZstd.ZstdDecompressorStream(IOBuffer(value[49:end]))
    normalized=value[1:8]==_CLOSURE_LEDGER_MAGIC_V2
    raw=try read(stream,(normalized ? _CLOSURE_LEDGER_LIMIT : size)+1) finally close(stream) end
    length(raw)<=_CLOSURE_LEDGER_LIMIT || error("ledger decompression exceeds size limit")
    normalized && (raw=_closure_v2_raw(raw,size))
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
    cache=_ClosureSegmentCache()
    try
        for row in query, record in _closure_unpack_chunks(_closure_resolve_chunk(db,row,cache))
            f(record)
        end
    finally
        DBInterface.close!(query)
    end
    nothing
end

# A native row has thirteen machine Ints, one Bool and fixed ASCII text.
# On supported word sizes its complete framed representation fits in 1024 bytes.
const _CLOSURE_LEDGER_SHA_BATCH=64*1024
const _CLOSURE_LEDGER_NATIVE_ROW_BOUND=1024

"""Append one logical row without changing the historical framing or checks."""
function _closure_write_ledger_row!(io,job_id,proof,cap::Int,first_evidence,limit::Int,native_writer)
    position(io)+44<=limit || error("compact ledger block exceeds size limit")
    for value in (job_id,proof["first_x"],proof["next_x"],proof["total_x"],cap)
        value isa Integer && value>=0 || error("invalid compact ledger integer")
        write(io,htol(UInt64(value)))
    end
    length_position=position(io);write(io,UInt32(0));text_position=position(io)
    if first_evidence===nothing
        _closure_write_coset_evidence(io,proof,limit,native_writer)
    else
        sizeof(first_evidence)<=limit-text_position || error("compact ledger block exceeds size limit")
        write(io,first_evidence)
    end
    next_position=position(io)
    # Patching a fixed-width length preserves the previous raw byte stream.
    seek(io,length_position);write(io,htol(UInt32(next_position-text_position)));seek(io,next_position)
    nothing
end

"""Hash only the active bytes, then reuse both private bounded buffers."""
function _closure_flush_ledger_sha!(context,io,scratch)
    n=position(io);seekstart(io)
    readbytes!(io,scratch,n)==n || error("private ledger buffer lost bytes")
    SHA.update!(context,scratch,n)
    truncate(io,0);seekstart(io)
    n
end

"""Retain the V1 logical digest without materializing its complete native stream.

A batch ends only between complete rows, after its text-length field is patched.
The two 64 KiB buffers remain private to this encoding. Native schemas that fail
V2 normalization return to the original raw encoder; generic schemas never enter
this path.
"""
function _closure_native_ledger_row(job_id,chunks,n,first_evidence,native_writer)
    io=IOBuffer(;sizehint=_CLOSURE_LEDGER_SHA_BATCH,maxsize=_CLOSURE_LEDGER_SHA_BATCH)
    scratch=Vector{UInt8}(undef,_CLOSURE_LEDGER_SHA_BATCH)
    context=SHA.SHA256_CTX()
    write(io,htol(UInt32(n)));capped=0;flushed=0
    for (i,chunk) in enumerate(chunks)
        position(io)>_CLOSURE_LEDGER_SHA_BATCH-_CLOSURE_LEDGER_NATIVE_ROW_BOUND &&
            (flushed+=_closure_flush_ledger_sha!(context,io,scratch))
        proof=chunk["proof"];cap=Int(proof["capped"]);capped=max(capped,cap)
        _closure_write_ledger_row!(io,job_id,proof,cap,i==1 ? first_evidence : nothing,
            _CLOSURE_LEDGER_LIMIT-flushed,native_writer)
    end
    raw_length=flushed+_closure_flush_ledger_sha!(context,io,scratch)
    normalized=all(c->_closure_common_coset_forms(c["proof"])!==nothing,chunks) ?
        _closure_v2_payload(job_id,[c["proof"] for c in chunks]) : nothing
    normalized===nothing && return nothing
    firstproof=first(chunks)["proof"];lastproof=last(chunks)["proof"]
    evidence=vcat(_CLOSURE_LEDGER_MAGIC_V2,reinterpret(UInt8,[htol(UInt64(raw_length))]),
        SHA.digest!(context),transcode(CodecZstd.ZstdCompressor,normalized))
    (job_id=job_id,first_x=firstproof["first_x"],next_x=lastproof["next_x"],
        total_x=firstproof["total_x"],capped,evidence)
end

"""Encode one packet's coverage rows exactly as the ledger stores them."""
function _closure_ledger_row(job_id,chunks)
    n=length(chunks)
    1<=n<=65536 || error("invalid compact ledger block length")
    firstproof=first(chunks)["proof"];lastproof=last(chunks)["proof"]
    first_evidence=_closure_coset_evidence_text(firstproof)
    if n==1
        return (job_id=job_id,first_x=firstproof["first_x"],next_x=lastproof["next_x"],
            total_x=firstproof["total_x"],capped=Int(firstproof["capped"]),evidence=first_evidence)
    end
    native_writer=firstproof isa _ClosureCosetProof ? _ClosureCosetEvidenceWriter(firstproof.forms) : nothing
    # Proof lengths vary slightly with integer widths. Reserve near the final
    # size without retaining a second array of Dict rows solely for encoding.
    estimate=4+n*max(512,44+sizeof(first_evidence)+64)
    # Small blocks need less scratch in the original raw encoder. Only the
    # immutable native schema gives the bounded row width needed for batching.
    if Sys.WORD_SIZE<=64 && estimate>2*_CLOSURE_LEDGER_SHA_BATCH &&
            eltype(chunks)<:Union{_ClosurePreparedV5Chunk,_ClosureCosetChunk}
        row=_closure_native_ledger_row(job_id,chunks,n,first_evidence,native_writer)
        row===nothing || return row
    end
    io=IOBuffer(;sizehint=min(_CLOSURE_LEDGER_LIMIT,estimate))
    write(io,htol(UInt32(n)));capped=0
    for (i,chunk) in enumerate(chunks)
        proof=chunk["proof"];cap=Int(proof["capped"]);capped=max(capped,cap)
        _closure_write_ledger_row!(io,job_id,proof,cap,i==1 ? first_evidence : nothing,
            _CLOSURE_LEDGER_LIMIT,native_writer)
    end
    (job_id=job_id,first_x=firstproof["first_x"],next_x=lastproof["next_x"],total_x=firstproof["total_x"],
        capped,evidence=_closure_encode_chunk_bytes(take!(io);normalized=
            all(c->_closure_common_coset_forms(c["proof"])!==nothing,chunks) ?
                _closure_v2_payload(job_id,[c["proof"] for c in chunks]) : nothing))
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
