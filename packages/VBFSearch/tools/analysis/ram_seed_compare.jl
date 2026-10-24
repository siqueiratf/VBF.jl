"""Bounded read-only scientific comparison of a RAM initial-seed run and SQLite baseline.

Construction jobs are matched by parent LUT and canonical scientific payload.
Paths retain full witnesses, with switching kernel job references made logical.
Coverage is compared per coset rather than per physical compressed block. The
existing VBFSearch codec verifies every source envelope and logical checksum;
native V2 fields feed the existing writer without billions of TOML parses.
No search mathematics or database writes are implemented here.
"""
module RAMSeedCompare
using VBFSearch,SQLite,SHA,TOML,JSON3
const FP=VBFSearch
const DB=FP.DBInterface
const BUFFER_BYTES=64*1024
const MAX_RSS_BYTES=1024^3
const MAX_PARTITION_BYTES=128*1024^2
const MAX_COUNTER_BYTES=64*1024^2
const MAX_SEGMENT_BYTES=64*1024^2

"""A concrete first scientific difference, retaining bounded diagnostic context."""
struct Difference <: Exception
    domain::String
    key::String
    left::Any
    right::Any
end
Base.showerror(io::IO,e::Difference)=print(io,"scientific mismatch in ",e.domain," at ",e.key)

"""Percent-escape URI delimiters before SQLite's explicit read-only open."""
function ro_uri(path)
    value=replace(abspath(path),"%"=>"%25","?"=>"%3f","#"=>"%23"," "=>"%20")
    "file://"*value*"?mode=ro"
end

"""Open with native read-only enforcement and bounded page caches."""
function open_readonly(path)
    db=SQLite.DB(ro_uri(path))
    SQLite.C.sqlite3_db_readonly(db.handle,"main")==1 || error("SQLite did not enforce read-only open")
    for sql in ("PRAGMA query_only=ON","PRAGMA cache_size=-8192","PRAGMA temp_store=FILE",
                "PRAGMA temp.cache_size=-8192","PRAGMA mmap_size=0")
        SQLite.execute(db,sql)
    end
    db
end

"""Pin content-changing file metadata without reading a multi-gigabyte database twice."""
function file_pin(path)
    wal=path*"-wal"
    (bytes=filesize(path),mtime=mtime(path),
        wal=isfile(wal) ? (bytes=filesize(wal),mtime=mtime(wal)) : nothing)
end

"""Read this helper's current RSS; the comparison holds no growing proof history."""
function rss_bytes()
    Sys.islinux() || return 0
    for line in eachline("/proc/self/status")
        startswith(line,"VmRSS:") && return parse(Int,split(line)[2])*1024
    end
    0
end

"""Bound retained working state before advancing to another root or cold segment."""
function check_memory()
    used=rss_bytes()
    if used>MAX_RSS_BYTES
        GC.gc();used=rss_bytes()
        used<=MAX_RSS_BYTES || error("comparison helper exceeds its 1 GiB RSS budget")
    end
    used
end

"""Stable JSON values for metadata; binary proof streams have their own framing."""
function canonical(value)
    value isa AbstractDict && return [(String(k),canonical(v)) for (k,v) in sort!(collect(value);by=x->String(first(x)))]
    value isa Tuple && return map(canonical,value)
    value isa AbstractVector && return map(canonical,value)
    ismissing(value) ? nothing : value
end

"""Add an unambiguous length-framed metadata row to a running digest."""
function frame!(context,value)
    bytes=codeunits(JSON3.write(canonical(value)))
    SHA.update!(context,reinterpret(UInt8,[htol(UInt64(length(bytes)))]))
    SHA.update!(context,bytes)
    nothing
end

"""Stream one query, releasing native statement state even after a mismatch."""
function each_row(f,db,sql,args=())
    query=DB.execute(db,sql,args)
    try
        for row in query
            f(Dict{String,Any}(String(k)=>row[k] for k in propertynames(row)))
        end
    finally
        DB.close!(query)
    end
    nothing
end

"""Compare sorted rows directly and hash all their normalized scientific fields."""
function compare_rows(leftdb,rightdb,sql,leftargs,rightargs,normalize,domain,key)
    left=DB.execute(leftdb,sql,leftargs);right=DB.execute(rightdb,sql,rightargs)
    lstate=rstate=nothing;lfirst=rfirst=true;count=0;context=SHA.SHA2_256_CTX()
    try
        while true
            l=lfirst ? iterate(left) : iterate(left,lstate)
            r=rfirst ? iterate(right) : iterate(right,rstate)
            lfirst=rfirst=false
            if l===nothing || r===nothing
                l===nothing && r===nothing || throw(Difference(domain,key,l===nothing ? "end" : "extra row",r===nothing ? "end" : "extra row"))
                break
            end
            lrow,lstate=l;rrow,rstate=r
            a=normalize(lrow,:left);b=normalize(rrow,:right)
            a==b || throw(Difference(domain,key,a,b))
            frame!(context,a);count+=1
        end
    finally
        DB.close!(left);DB.close!(right)
    end
    (;rows=count,sha256=bytes2hex(SHA.digest!(context)))
end

"""Bounded byte sink used for packet-independent per-coset canonical hashes."""
mutable struct ByteSink
    context::SHA.SHA2_256_CTX
    bytes::Vector{UInt8}
    used::Int
end
ByteSink()=ByteSink(SHA.SHA2_256_CTX(),Vector{UInt8}(undef,BUFFER_BYTES),0)
function flush!(sink::ByteSink)
    sink.used==0 && return
    SHA.update!(sink.context,sink.bytes,sink.used);sink.used=0
end
function append_bytes!(sink::ByteSink,bytes,first::Int,n::Int)
    while n>0
        room=length(sink.bytes)-sink.used
        room==0 && (flush!(sink);room=length(sink.bytes))
        amount=min(room,n)
        copyto!(sink.bytes,sink.used+1,bytes,first,amount)
        sink.used+=amount;first+=amount;n-=amount
    end
    nothing
end
function append_byte!(sink::ByteSink,value::UInt8)
    sink.used==length(sink.bytes) && flush!(sink)
    sink.used+=1;sink.bytes[sink.used]=value
    nothing
end

"""Append an unsigned scalar without allocating a temporary byte vector."""
@inline function append_uint64!(sink::ByteSink,value::UInt64)
    sink.used>length(sink.bytes)-8 && flush!(sink)
    @inbounds for byte in 0:7
        sink.bytes[sink.used+byte+1]=UInt8((value>>(8byte))&0xff)
    end
    sink.used+=8
    nothing
end

"""Compare mathematical proof data separately from the versioned solver work count."""
mutable struct CoverageAudit
    mathematical::ByteSink
    counters::Vector{Int}
    reference::Union{Nothing,Vector{Int}}
    differing_cosets::Int
    first_difference::Any
    linear_candidates::Int128
end
function CoverageAudit(total;reference=nothing)
    0<=total<=MAX_COUNTER_BYTES÷sizeof(Int) || error("one V5 job exceeds the comparison counter budget")
    CoverageAudit(ByteSink(),reference===nothing ? zeros(Int,total) : Int[],reference,0,nothing,Int128(0))
end

"""Retain or compare every per-coset count, allowing only a documented reduction."""
function accounting!(audit::CoverageAudit,first,total,count)
    count>=0 || error("negative linear-system work count")
    audit.linear_candidates+=count
    if total==0
        count==0 || error("empty eligible domain has nonzero work")
        return
    end
    if audit.reference===nothing
        audit.counters[first]=count
    else
        first<=length(audit.reference) || error("accounting reference exceeds domain")
        ram=audit.reference[first]
        ram<=count || throw(Difference("coverage accounting increased",string(first),ram,count))
        if ram!=count
            audit.differing_cosets+=1
            audit.first_difference===nothing && (audit.first_difference=(coset=first,ram,baseline=count))
        end
    end
    nothing
end

"""All fixed native mathematical fields; the omitted counter is audited independently."""
function mathematical!(audit::CoverageAudit,proof::FP._ClosureCosetProof)
    append_byte!(audit.mathematical,0x01)
    for value in (proof.forms...,proof.first_x,proof.next_x,proof.total_x,
                  proof.candidate_spaces,proof.completion_spaces,proof.du_reject,
                  proof.coset_representative,Int(proof.capped))
        value>=0 || error("negative mathematical proof field")
        append_uint64!(audit.mathematical,UInt64(value))
    end
    accounting!(audit,proof.first_x,proof.total_x,proof.linear_system_candidates)
end

"""Preserve every future/generic field, normalizing only the known work counter."""
function mathematical!(audit::CoverageAudit,proof::AbstractDict)
    if FP._closure_common_coset_forms(proof)!==nothing
        native=FP._ClosureCosetProof(Tuple(Int.(proof["V5_forms"])),Int(proof["first_x"]),
            Int(proof["next_x"]),Int(proof["total_x"]),Int(proof["candidate_spaces"]),
            Int(proof["linear_system_candidates"]),Int(proof["du_reject"]),Int(proof["completion_spaces"]),
            Int(proof["coset_representative"]),Bool(proof["capped"]))
        mathematical!(audit,native)
    else
        fields=copy(proof);count=Int(pop!(fields,"linear_system_candidates"))
        bytes=codeunits(JSON3.write(canonical(fields)))
        append_byte!(audit.mathematical,0x02);append_uint64!(audit.mathematical,UInt64(length(bytes)))
        append_bytes!(audit.mathematical,bytes,1,length(bytes))
        accounting!(audit,Int(proof["first_x"]),Int(proof["total_x"]),count)
    end
end

"""Decode the existing V2 integer representation into existing native proof records."""
function native_v2_proofs(value,row)
    stream=FP.CodecZstd.ZstdDecompressorStream(IOBuffer(value[49:end]))
    job,first,total,forms,n,nt,payload=try
        header=read(stream,52);length(header)==52 || error("truncated normalized ledger header")
        head=IOBuffer(header)
        job=ltoh(read(head,UInt64));first=ltoh(read(head,UInt64));total=ltoh(read(head,UInt64))
        forms=ntuple(_->Int(ltoh(read(head,UInt32))),5)
        n=Int(ltoh(read(head,UInt32)));nt=Int(ltoh(read(head,UInt32)))
        1<=nt<=n<=65536 || error("invalid normalized ledger counts")
        # Five UInt64 varints/template and two/row need at most ten bytes each.
        # This format-derived bound is <4.4 MiB even for the largest block;
        # requesting the generic 64 MiB limit needlessly reserves that much.
        limit=50nt+20n
        payload=read(stream,limit+1)
        length(payload)<=limit || error("normalized ledger decompression exceeds native format budget")
        (job,first,total,forms,n,nt,payload)
    finally
        close(stream)
    end
    io=IOBuffer(payload)
    all(v->v<=typemax(Int64),(job,first,total)) && first<=typemax(Int64)-n || error("normalized ledger integer overflow")
    Int(job)==row["job_id"] && Int(first)==row["first_x"] && Int(total)==row["total_x"] || error("normalized ledger header differs from SQL envelope")
    templates=[ntuple(_->FP._closure_getvar(io),5) for _ in 1:nt]
    all(t->all(v->v<=typemax(Int64),t) && t[5]<=1,templates) || error("invalid normalized ledger outcome")
    proofs=Vector{FP._ClosureCosetProof}(undef,n);previous=Int128(0);capped=0
    for i in 1:n
        z=FP._closure_getvar(io);previous+=iseven(z) ? Int128(z>>1) : -Int128(z>>1)-1
        0<=previous<=typemax(Int64) || error("normalized ledger representative overflow")
        index=FP._closure_getvar(io);index<nt || error("invalid normalized ledger template index")
        values=templates[Int(index)+1];cursor=Int(first)+i-1
        cursor<Int(total)+1 || error("normalized ledger cursor exceeds eligible domain")
        proofs[i]=FP._ClosureCosetProof(forms,cursor,cursor+1,Int(total),Int(values[1]),
            Int(values[4]),Int(values[3]),Int(values[2]),Int(previous),Bool(values[5]))
        capped|=Int(values[5])
    end
    eof(io) && Int(first)+n==row["next_x"] && capped==row["capped"] || error("normalized ledger envelope mismatch")
    proofs
end

"""Verify V1 logical checksum with its existing writer and canonicalize in one pass.

Physical job IDs and per-block row-count headers are removed only from the
canonical comparison stream. The original complete stream is still hashed and
checked against its stored size/SHA. No mathematical field is omitted.
"""
function native_coverage!(sink::ByteSink,value,row,audit)
    length(value)>=49 && value[1:8]==FP._CLOSURE_LEDGER_MAGIC_V2 || error("not a native V2 block")
    expected_size=Int(ltoh(read(IOBuffer(value[9:16]),UInt64)))
    4<=expected_size<=FP._CLOSURE_LEDGER_LIMIT || error("invalid ledger decoded-size bound")
    proofs=native_v2_proofs(value,row)
    io=IOBuffer(;sizehint=BUFFER_BYTES,maxsize=BUFFER_BYTES);scratch=Vector{UInt8}(undef,BUFFER_BYTES)
    original=SHA.SHA2_256_CTX();write(io,htol(UInt32(length(proofs))))
    spans=Tuple{Int,Int}[];raw_length=0
    function flush_original!()
        size=FP._closure_flush_ledger_sha!(original,io,scratch);raw_length+=size
        for (first,last) in spans
            append_byte!(sink,0x01)
            append_bytes!(sink,scratch,first+1,last-first)
        end
        empty!(spans)
    end
    writer=FP._ClosureCosetEvidenceWriter(first(proofs).forms)
    for proof in proofs
        mathematical!(audit,proof)
        position(io)>BUFFER_BYTES-FP._CLOSURE_LEDGER_NATIVE_ROW_BOUND && flush_original!()
        first=position(io)
        FP._closure_write_ledger_row!(io,Int(row["job_id"]),proof,Int(proof.capped),nothing,
            FP._CLOSURE_LEDGER_LIMIT-raw_length,writer)
        push!(spans,(first+8,position(io)))
    end
    flush_original!()
    raw_length==expected_size && SHA.digest!(original)==value[17:48] || error("native ledger logical checksum mismatch")
    length(proofs)
end

"""Use the existing generic decoder for legacy blocks or text exhaustion markers."""
function generic_coverage!(sink::ByteSink,row,audit)
    records=FP._closure_unpack_chunks(row)
    for record in records
        proof=TOML.parse(record["evidence"])
        for key in ("first_x","next_x","total_x","capped")
            Int(proof[key])==Int(record[key]) || error("text proof differs from ledger envelope")
        end
        mathematical!(audit,proof)
        buffer=IOBuffer()
        for key in ("first_x","next_x","total_x","capped");write(buffer,htol(UInt64(record[key])));end
        text=codeunits(record["evidence"]);write(buffer,htol(UInt32(length(text))));write(buffer,text)
        bytes=take!(buffer);append_byte!(sink,0x01);append_bytes!(sink,bytes,1,length(bytes))
    end
    length(records)
end

"""Bound cold-codec scratch before the existing decoder allocates a sealed segment.

The full reference uses 16 MiB segments. A segment transition can temporarily own
compressed bytes, decoded bytes and copied row payloads together; account for all
three and release the old cache before invoking the library codec when necessary.
"""
function resolve_chunk(db,row,cache)
    reference=FP._closure_segment_reference(row["evidence"])
    if reference!==nothing && cache.digest!=reference.digest
        meta=only(FP._closure_rows(db,"SELECT raw_bytes,compressed_bytes FROM closure_evidence_segments WHERE digest=?",(reference.digest,)))
        raw=Int(meta["raw_bytes"]);compressed=Int(meta["compressed_bytes"])
        0<raw<=MAX_SEGMENT_BYTES && 0<compressed<=MAX_SEGMENT_BYTES+1024^2 ||
            error("one cold segment exceeds the comparison decode budget")
        scratch=3raw+compressed
        if rss_bytes()+scratch>MAX_RSS_BYTES
            empty!(cache.rows);cache.digest="";GC.gc()
            rss_bytes()+scratch<=MAX_RSS_BYTES || error("insufficient comparison RSS allowance for the next cold segment")
        end
    end
    FP._closure_resolve_chunk(db,row,cache)
end

"""Stream every physical block, resolving/checking existing sealed cold storage."""
function coverage(db,job,cache;reference_counters=nothing)
    sink=ByteSink();cursor=1;total=nothing;rows=blocks=0;audit=nothing;peak=0
    each_row(db,"SELECT * FROM chunks WHERE job_id=? ORDER BY first_x",(job["id"],)) do raw
        resolved=resolve_chunk(db,raw,cache)
        resolved["first_x"]==cursor || error("coverage has a gap or overlap")
        if total===nothing
            total=Int(resolved["total_x"])
            audit=CoverageAudit(total;reference=reference_counters)
        end
        total==resolved["total_x"] && resolved["capped"]==0 || error("coverage changed domain or is capped")
        evidence=resolved["evidence"]
        count=evidence isa Vector{UInt8} && length(evidence)>=49 && evidence[1:8]==FP._CLOSURE_LEDGER_MAGIC_V2 ?
            native_coverage!(sink,evidence,resolved,audit) : generic_coverage!(sink,resolved,audit)
        rows+=count;blocks+=1;cursor=Int(resolved["next_x"])
        blocks%32==0 && (peak=max(peak,check_memory()))
    end
    total===nothing || cursor==total+1 || error("complete job has incomplete coverage")
    flush!(sink)
    audit===nothing && (audit=CoverageAudit(0;reference=reference_counters))
    flush!(audit.mathematical)
    (;rows,blocks,total_x=total,peak_observed_rss_bytes=peak,sha256=bytes2hex(SHA.digest!(sink.context)),
        mathematical_sha256=bytes2hex(SHA.digest!(audit.mathematical.context)),
        linear_system_candidates=audit.linear_candidates,differing_cosets=audit.differing_cosets,
        first_counter_difference=audit.first_difference,counters=audit.counters)
end

"""Derive an ID-independent construction key while retaining the full payload."""
function jobs_for_root(db,parent,parent_digest)
    jobs=FP._closure_rows(db,"SELECT * FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching') ORDER BY kind,job_key",(parent,))
    bykey=Dict{String,Dict{String,Any}}();references=Dict{Int,String}()
    for job in jobs
        payload=TOML.parse(job["payload"]);kind=job["kind"]
        suffix=kind=="v5" ? ":"*join(first(FP.Fourier.rref(UInt32.(payload["forms"]))),",") : ""
        key=parent_digest*":"*kind*suffix
        haskey(bykey,key) && error("duplicate logical construction job")
        job["logical_payload"]=payload;bykey[key]=job;references[Int(job["id"])]=key
    end
    (;bykey,references)
end

"""Normalize the only physical cross-job reference in construction witnesses."""
function witness(text,references)
    occursin("kernel_job",text) || return text
    value=TOML.parse(text)
    if haskey(value,"kernel_job")
        id=Int(value["kernel_job"]);haskey(references,id) || error("witness references another parent's unknown job")
        value["kernel_job"]=references[id]
    end
    canonical(value)
end

"""Compare the candidate universe and its EA partition without loading baseline history."""
function candidates_and_partition(ram,baseline_path)
    DB.execute(ram,"ATTACH DATABASE ? AS baseline",(ro_uri(baseline_path),))
    SQLite.C.sqlite3_db_readonly(ram.handle,"baseline")==1 || error("attached baseline is not read-only")
    SQLite.execute(ram,"PRAGMA baseline.cache_size=-8192");SQLite.execute(ram,"PRAGMA baseline.mmap_size=0")
    # Parent IDs are contiguous native store IDs. Two UInt32 lookup arrays keep
    # the full 1.46M-candidate campaign's partition state in tens of MiB, rather
    # than retaining two growing hash tables or any candidate/LUT properties.
    left_max=Int(only(FP._closure_rows(ram,"SELECT COALESCE(MAX(id),0) n FROM main.parents"))["n"])
    right_max=Int(only(FP._closure_rows(ram,"SELECT COALESCE(MAX(id),0) n FROM baseline.parents"))["n"])
    0<=left_max<=typemax(UInt32) && 0<=right_max<=typemax(UInt32) || error("class identifiers exceed compact partition format")
    left_max+right_max<=MAX_PARTITION_BYTES÷sizeof(UInt32) || error("class partition exceeds comparison map budget")
    forward=zeros(UInt32,left_max);reverse=zeros(UInt32,right_max)
    partition_classes=0;context=SHA.SHA2_256_CTX();count=0;peak=check_memory()
    sql="""SELECT a.id,a.lut_hex,a.sigma,a.apn,a.degree,a.class_id,
        b.id baseline_id,b.lut_hex baseline_lut,b.sigma baseline_sigma,
        b.apn baseline_apn,b.degree baseline_degree,b.class_id baseline_class
        FROM main.candidates a LEFT JOIN baseline.candidates b ON b.id=a.id ORDER BY a.id"""
    plan=FP._closure_rows(ram,"EXPLAIN QUERY PLAN "*sql)
    try
        each_row(ram,sql) do row
            id=row["id"];ismissing(row["baseline_id"]) && throw(Difference("candidates",id,"present","missing"))
            a=(row["lut_hex"],row["sigma"],row["apn"],row["degree"])
            b=(row["baseline_lut"],row["baseline_sigma"],row["baseline_apn"],row["baseline_degree"])
            isequal(a,b) || throw(Difference("candidates",id,a,b))
            left=row["class_id"];right=row["baseline_class"]
            if row["apn"]==1 && row["degree"]==2
                !ismissing(left) && !ismissing(right) || throw(Difference("classes",id,left,right))
                left=Int(left);right=Int(right)
                1<=left<=left_max && 1<=right<=right_max || error("candidate class is outside its parent registry")
                (forward[left]==0 || forward[left]==right) && (reverse[right]==0 || reverse[right]==left) ||
                    throw(Difference("classes",id,(left,Int(forward[left])),(right,Int(reverse[right]))))
                forward[left]==0 && (partition_classes+=1)
                forward[left]=UInt32(right);reverse[right]=UInt32(left)
            else
                ismissing(left) && ismissing(right) || throw(Difference("terminal classes",id,left,right))
            end
            frame!(context,(id,a));count+=1
            count%100000==0 && begin
                peak=max(peak,check_memory());println("CANDIDATES ",count," classes ",partition_classes);flush(stdout)
            end
        end
    finally
        SQLite.execute(ram,"DETACH DATABASE baseline")
    end
    (;rows=count,classes=partition_classes,sha256=bytes2hex(SHA.digest!(context)),query_plan=plan,
        partition_map_bytes=sizeof(forward)+sizeof(reverse),peak_observed_rss_bytes=max(peak,check_memory()))
end

"""Compare every expanded audited root, using only indexed per-parent/job reads."""
function compare(ram_path,baseline_path;progress_seconds=30.0,counter_log=nothing,root_shard=(index=1,count=1))
    1<=root_shard.index<=root_shard.count || error("root shard must satisfy 1 <= index <= count")
    ram=open_readonly(ram_path);baseline=open_readonly(baseline_path)
    domains=Dict(name=>SHA.SHA2_256_CTX() for name in ("jobs","paths","kernels","evaluations","coverage"))
    counts=Dict(name=>0 for name in keys(domains));counts["coverage_blocks_ram"]=0;counts["coverage_blocks_baseline"]=0
    ram_cache=FP._ClosureSegmentCache();base_cache=FP._ClosureSegmentCache()
    strict_proof_parity=true;counter_jobs=counter_cosets=0;counter_examples=Any[]
    ram_linear_total=baseline_linear_total=Int128(0)
    try
        ri=TOML.parse(only(FP._closure_rows(ram,"SELECT value FROM metadata WHERE key='identity'"))["value"])
        bi=TOML.parse(only(FP._closure_rows(baseline,"SELECT value FROM metadata WHERE key='identity'"))["value"])
        for key in ("roots_sha256","campaign_sha256","inputs")
            ri[key]==bi[key] || throw(Difference("identity",key,ri[key],bi[key]))
        end
        rs=copy(ri["scientific"]);bs=copy(bi["scientific"])
        for key in ("extension_cosets","switching_directions","execution_backend","scheduling")
            pop!(rs,key,nothing);pop!(bs,key,nothing)
        end
        rs==bs || throw(Difference("scientific parameters","identity",rs,bs))
        inventory_sql="SELECT candidate_id,source FROM parents WHERE origin='root' ORDER BY id"
        inventory=compare_rows(ram,baseline,inventory_sql,(),(),(r,_)->(r.candidate_id,r.source),"root inventory","all audited roots")
        roots=FP._closure_rows(ram,"SELECT p.id,p.candidate_id FROM parents p JOIN jobs j ON j.parent_id=p.id WHERE p.origin='root' AND j.kind='prepare_v5' AND j.status='done' ORDER BY p.id")
        isempty(roots) && error("RAM file has no expanded audited roots")
        registry=SHA.SHA2_256_CTX()
        for root in roots;frame!(registry,(Int(root["id"]),String(root["candidate_id"])));end
        registry_sha256=bytes2hex(SHA.digest!(registry))
        ordinals=collect(root_shard.index:root_shard.count:length(roots))
        root_map=Dict(String(row["candidate_id"])=>Int(row["id"]) for row in FP._closure_rows(baseline,"SELECT id,candidate_id FROM parents WHERE origin='root'"))
        last_progress=time();started=time();peak=check_memory()
        for (position,ordinal) in enumerate(ordinals)
            root=roots[ordinal]
            root_id=Int(root["id"]);parent_digest=String(root["candidate_id"])
            rj=jobs_for_root(ram,root_id,parent_digest);bj=jobs_for_root(baseline,root_map[parent_digest],parent_digest)
            Set(keys(rj.bykey))==Set(keys(bj.bykey)) || throw(Difference("jobs",parent_digest,sort!(collect(keys(rj.bykey))),sort!(collect(keys(bj.bykey)))))
            for key in sort!(collect(keys(rj.bykey)))
                a=rj.bykey[key];b=bj.bykey[key]
                left=(a["kind"],canonical(a["logical_payload"]),a["status"],a["direction"],a["combination"])
                right=(b["kind"],canonical(b["logical_payload"]),b["status"],b["direction"],b["combination"])
                left==right && a["status"]=="done" || throw(Difference("jobs",key,left,right))
                if a["kind"]=="prepare_v5"
                    TOML.parse(a["result"])==TOML.parse(b["result"]) || throw(Difference("maximizer proof",key,a["result"],b["result"]))
                end
                frame!(domains["jobs"],(key,left));counts["jobs"]+=1
                for (name,sql,normalizer) in (
                    ("paths","SELECT cursor,child_id,witness FROM paths WHERE job_id=? ORDER BY cursor,child_id",
                        (row,side)->(String(row.cursor),String(row.child_id),witness(String(row.witness),side==:left ? rj.references : bj.references))),
                    ("kernels","SELECT direction,dimension,evidence FROM kernels WHERE job_id=? ORDER BY direction",
                        (row,_)->(Int(row.direction),Int(row.dimension),String(row.evidence))),
                    ("evaluations","SELECT direction,combination,candidate_id,apn FROM evaluations WHERE job_id=? ORDER BY direction,combination",
                        (row,_)->(Int(row.direction),String(row.combination),String(row.candidate_id),Int(row.apn))))
                    result=compare_rows(ram,baseline,sql,(a["id"],),(b["id"],),normalizer,name,key)
                    frame!(domains[name],(key,result));counts[name]+=result.rows
                end
                ca=coverage(ram,a,ram_cache);cb=coverage(baseline,b,base_cache;reference_counters=ca.counters)
                peak=max(peak,ca.peak_observed_rss_bytes,cb.peak_observed_rss_bytes)
                (ca.rows,ca.total_x,ca.mathematical_sha256)==(cb.rows,cb.total_x,cb.mathematical_sha256) ||
                    throw(Difference("mathematical coverage",key,(ca.rows,ca.total_x,ca.mathematical_sha256),
                        (cb.rows,cb.total_x,cb.mathematical_sha256)))
                ram_linear_total+=ca.linear_system_candidates;baseline_linear_total+=cb.linear_system_candidates
                if ca.sha256!=cb.sha256
                    cb.differing_cosets>0 || throw(Difference("unexplained full-proof bytes",key,ca.sha256,cb.sha256))
                    strict_proof_parity=false;counter_jobs+=1;counter_cosets+=cb.differing_cosets
                    detail=(job=key,cosets=cb.differing_cosets,first=cb.first_counter_difference,
                        ram_work=ca.linear_system_candidates,baseline_work=cb.linear_system_candidates,
                        ram_full_sha256=ca.sha256,baseline_full_sha256=cb.sha256)
                    length(counter_examples)<32 && push!(counter_examples,detail)
                    counter_log===nothing || println(counter_log,JSON3.write(detail))
                end
                frame!(domains["coverage"],(key,ca.rows,ca.total_x,ca.mathematical_sha256));counts["coverage"]+=ca.rows
                counts["coverage_blocks_ram"]+=ca.blocks;counts["coverage_blocks_baseline"]+=cb.blocks
            end
            peak=max(peak,check_memory())
            if time()-last_progress>=progress_seconds || position==length(ordinals)
                println("ROOTS ",position,"/",length(ordinals)," paths ",counts["paths"]," cosets ",counts["coverage"],
                    " elapsed ",round(time()-started;digits=1),"s RSS ",round(rss_bytes()/1024^2;digits=1),"MiB")
                flush(stdout);last_progress=time()
            end
        end
        candidate_result=candidates_and_partition(ram,baseline_path)
        (;verified=true,expanded_roots=length(ordinals),total_expanded_roots=length(roots),
            expanded_root_ordinals=ordinals,expanded_root_registry_sha256=registry_sha256,root_shard,
            audited_root_inventory=inventory.rows,
            roots_sha256=ri["roots_sha256"],counts,
            science=Dict(name=>bytes2hex(SHA.digest!(context)) for (name,context) in domains),
            candidates=candidate_result,peak_observed_rss_bytes=max(peak,rss_bytes(),candidate_result.peak_observed_rss_bytes),
            strict_full_proof_parity=strict_proof_parity,
            coverage_work_counter=Dict("field"=>"linear_system_candidates","different_jobs"=>counter_jobs,
                "different_cosets"=>counter_cosets,"ram_total"=>ram_linear_total,"baseline_total"=>baseline_linear_total,
                "per_coset_reduction_only"=>true,"examples"=>counter_examples,
                "policy"=>"historical initial seed source had no DU7 bitset prefilter; current worker uses an exact necessary prefilter; every other proof field must match"),
            source_runtime=(ram=ri["julia"],baseline=bi["julia"]),
            scope="all construction jobs, paths/witnesses, kernels, evaluations, per-coset coverage and candidate/EA partitions for RAM-expanded audited roots")
    finally
        close(ram);close(baseline)
    end
end

"""Publish a comparison receipt on success or a concrete first mismatch on failure."""
function main(args=ARGS)
    length(args) in (3,4) || error("usage: ram_seed_compare.jl RAM.sqlite BASELINE.sqlite OUTPUT.json [--root-shard=I/N]")
    shard=(index=1,count=1)
    if length(args)==4
        found=match(r"^--root-shard=([1-9][0-9]*)/([1-9][0-9]*)$",args[4])
        found===nothing && error("root shard needs --root-shard=I/N")
        shard=(index=parse(Int,found[1]),count=parse(Int,found[2]))
        shard.index<=shard.count || error("root shard index exceeds count")
    end
    ram,baseline,output=abspath.(args[1:3]);ispath(output) && error("comparison output already exists")
    helper_sha256=bytes2hex(open(SHA.sha256,@__FILE__))
    pins=(ram=file_pin(ram),baseline=file_pin(baseline));started=time()
    report=Dict{String,Any}("schema"=>"vbfsearch-ram-seed-comparison-v1","ram"=>ram,"baseline"=>baseline,
        "source_pins"=>pins,"helper_julia"=>string(VERSION),"rss_budget_bytes"=>MAX_RSS_BYTES,
        "helper_source_sha256"=>helper_sha256)
    problem=nothing
    counter_path=output*".counter-differences.jsonl"
    ispath(counter_path) && error("counter comparison log already exists")
    try
        open(counter_path,"w") do counter_log
            merge!(report,Dict(String(k)=>v for (k,v) in pairs(compare(ram,baseline;counter_log,root_shard=shard))))
        end
        report["counter_difference_log"]=counter_path
        report["counter_difference_log_sha256"]=bytes2hex(open(SHA.sha256,counter_path))
    catch error
        problem=error;report["verified"]=false;report["error"]=sprint(showerror,error)
        error isa Difference && (report["difference"]=Dict("domain"=>error.domain,"key"=>error.key,"ram"=>canonical(error.left),"baseline"=>canonical(error.right)))
        report["backtrace"]=sprint(showerror,error,catch_backtrace())
    end
    report["elapsed_seconds"]=time()-started
    report["source_files_unchanged"]=pins==(ram=file_pin(ram),baseline=file_pin(baseline))
    report["helper_source_unchanged"]=helper_sha256==bytes2hex(open(SHA.sha256,@__FILE__))
    if !report["source_files_unchanged"] || !report["helper_source_unchanged"]
        report["verified"]=false
        problem=ErrorException("comparison source database/WAL or helper changed during comparison")
        report["error"]=sprint(showerror,problem)
    end
    open(io->JSON3.pretty(io,report),output,"w")
    problem===nothing || throw(problem)
    println("RAM_SEED_COMPARISON_VERIFIED ",output)
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
end
