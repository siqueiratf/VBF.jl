# VBFCHN02 retains the V1 logical-stream length and SHA-256 in its envelope.
# Only the compressed representation changes: shared context, exact outcome
# tuples, and signed deltas of representatives. All logical cosets survive.
const _CLOSURE_LEDGER_MAGIC_V2=collect(codeunits("VBFCHN02"))
function _closure_putvar(io,value::UInt64)
    while value>=0x80
        write(io,UInt8(value&0x7f)|0x80);value>>=7
    end
    write(io,UInt8(value))
end
function _closure_getvar(io)
    value=UInt64(0)
    for shift in 0:7:63
        eof(io) && error("truncated ledger varint")
        byte=read(io,UInt8)
        shift==63 && byte>1 && error("ledger varint overflow")
        value|=UInt64(byte&0x7f)<<shift
        if byte<0x80
            shift>0 && byte==0 && error("noncanonical ledger varint")
            return value
        end
    end
    error("ledger varint overflow")
end
function _closure_v2_payload(job,proofs)
    n=length(proofs);1<=n<=65536 || return nothing
    # Mixed containers keep the legacy vector comparisons; native arrays need no copies.
    native_forms=eltype(proofs)<:_ClosureCosetProof
    p=first(proofs);forms=native_forms ? p.forms : p["V5_forms"];first_x=p["first_x"];total=p["total_x"]
    length(forms)==5 && all(v->v isa Integer && 0<=v<=typemax(UInt32),forms) || return nothing
    templates=NTuple{5,UInt64}[];lookup=Dict{NTuple{5,UInt64},UInt64}();entries=Tuple{Int64,UInt64}[]
    for (i,q) in enumerate(proofs)
        (native_forms ? q.forms : q["V5_forms"])==forms && q["first_x"]==first_x+i-1 && q["next_x"]==first_x+i && q["total_x"]==total || return nothing
        values=(q["candidate_spaces"],q["completion_spaces"],q["du_reject"],q["linear_system_candidates"],Int(q["capped"]))
        all(v->v isa Integer && 0<=v<=typemax(Int64),values) && values[5] in (0,1) || return nothing
        rep=q["coset_representative"];rep isa Integer && 0<=rep<=typemax(Int64) || return nothing
        key=(UInt64(values[1]),UInt64(values[2]),UInt64(values[3]),UInt64(values[4]),UInt64(values[5]))
        # At most 65536 templates exist, so the all-ones index is an unambiguous miss.
        index=get(lookup,key,typemax(UInt64))
        if index==typemax(UInt64)
            index=UInt64(length(templates));push!(templates,key);lookup[key]=index
        end
        push!(entries,(Int64(rep),index))
    end
    io=IOBuffer()
    for v in (job,first_x,total);write(io,htol(UInt64(v)));end
    for v in forms;write(io,htol(UInt32(v)));end
    write(io,htol(UInt32(n)));write(io,htol(UInt32(length(templates))))
    for template in templates,v in template;_closure_putvar(io,v);end
    previous=Int64(0)
    for (rep,index) in entries
        delta=Int128(rep)-previous;previous=rep
        _closure_putvar(io,UInt64(delta>=0 ? 2delta : -2delta-1));_closure_putvar(io,index)
    end
    take!(io)
end
function _closure_v2_from_raw(raw)
    io=IOBuffer(raw);n=Int(ltoh(read(io,UInt32)));1<=n<=65536 || return nothing
    proofs=Any[];job=nothing
    for _ in 1:n
        values=ntuple(_->ltoh(read(io,UInt64)),5)
        len=Int(ltoh(read(io,UInt32)));len<=bytesavailable(io) || error("truncated ledger evidence")
        text=String(read(io,len))
        # Future or arbitrary proof schemas remain V1, byte for byte.
        q=try TOML.parse(text) catch;return nothing end
        Set(keys(q))==Set(_CLOSURE_COSET_PROOF_KEYS) || return nothing
        _closure_common_coset_forms(q)===nothing && return nothing
        _closure_coset_evidence_text(q)==text || return nothing
        values==(UInt64(job===nothing ? values[1] : job),UInt64(q["first_x"]),UInt64(q["next_x"]),UInt64(q["total_x"]),UInt64(q["capped"])) || return nothing
        job=values[1];push!(proofs,q)
    end
    eof(io) || error("trailing ledger bytes")
    _closure_v2_payload(job,proofs)
end
function _closure_v2_raw(payload,expected_size)
    io=IOBuffer(payload);length(payload)>=52 || error("truncated normalized ledger header")
    job=ltoh(read(io,UInt64));first_x=ltoh(read(io,UInt64));total=ltoh(read(io,UInt64))
    forms=[Int(ltoh(read(io,UInt32))) for _ in 1:5]
    n=Int(ltoh(read(io,UInt32)));nt=Int(ltoh(read(io,UInt32)))
    1<=nt<=n<=65536 || error("invalid normalized ledger counts")
    all(v->v<=typemax(Int64),(job,first_x,total)) && first_x<=typemax(Int64)-n || error("normalized ledger integer overflow")
    templates=[ntuple(_->_closure_getvar(io),5) for _ in 1:nt]
    all(t->all(v->v<=typemax(Int64),t) && t[5]<=1,templates) || error("invalid ledger outcome")
    out=IOBuffer();write(out,htol(UInt32(n)));previous=Int128(0)
    for i in 0:n-1
        z=_closure_getvar(io);previous+=iseven(z) ? Int128(z>>1) : -Int128(z>>1)-1
        0<=previous<=typemax(Int64) || error("normalized ledger representative overflow")
        index=_closure_getvar(io);index<nt || error("invalid ledger template reference")
        vals=templates[Int(index)+1];first=Int(first_x)+i
        q=Dict{String,Any}("V5_forms"=>forms,"first_x"=>first,"next_x"=>first+1,"total_x"=>Int(total),
            "candidate_spaces"=>Int(vals[1]),"completion_spaces"=>Int(vals[2]),"du_reject"=>Int(vals[3]),
            "linear_system_candidates"=>Int(vals[4]),"capped"=>Bool(vals[5]),"coset_representative"=>Int(previous),
            "coset_order"=>"increasing nonzero quotient integer with exact bent count","heuristic_pruning"=>false)
        text=_closure_coset_evidence_text(q)
        for value in (job,first,first+1,total,vals[5]);write(out,htol(UInt64(value)));end
        write(out,htol(UInt32(sizeof(text))));write(out,text)
        position(out)<=expected_size || error("normalized ledger exceeds declared logical size")
    end
    eof(io) || error("trailing normalized ledger bytes")
    take!(out)
end
