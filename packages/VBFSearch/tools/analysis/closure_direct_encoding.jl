"""Offline exact-byte experiment writing coset proofs into the raw ledger stream.

The persistent framing, sorted TOML text, digest and compressor stay unchanged.
Each proof is written after a reserved length word, which is patched after the
write. This removes one temporary buffer and string per complete coset.
"""
module ClosureDirectEncoding
using VBFSearch,SHA
const FP=VBFSearch
const LIMIT=FP._CLOSURE_LEDGER_LIMIT
const FIELDS=FP._CLOSURE_COSET_INTEGER_FIELDS
const _CLOSURE_COSET_INTEGER_FIELDS=FIELDS
const _closure_text=FP._closure_text
const _closure_encode_chunk_bytes=FP._closure_encode_chunk_bytes
const baseline_directory=abspath(get(ENV,"VBF_ENCODING_BASELINE_DIRECTORY",
    joinpath(@__DIR__,"../../data/research/analyses/closure-optimization-20261018c/baseline")))
const source_bindings=Dict(name=>bytes2hex(open(sha256,joinpath(baseline_directory,name)))
    for name in ("closure_algorithms.jl","closure_ledger.jl"))
source=read(joinpath(baseline_directory,"closure_algorithms.jl"),String)
body=match(r"function _closure_coset_evidence_text\(.*?(?=\n\"\"\"Apply)"s,source)
body===nothing && error("cannot locate pinned proof formatter")
Core.eval(@__MODULE__,Meta.parse(replace(String(body.match),
    "function _closure_coset_evidence_text("=>"function text_proof(";count=1)))
source=read(joinpath(baseline_directory,"closure_ledger.jl"),String)
body=match(r"function _closure_ledger_row\(.*?(?=\n\"\"\"Persist)"s,source)
body===nothing && error("cannot locate pinned ledger writer")
variant=replace(String(body.match),
    "function _closure_ledger_row("=>"function baseline_row(";
    count=1)
variant=replace(variant,"_closure_coset_evidence_text"=>"text_proof","_CLOSURE_LEDGER_LIMIT"=>"LIMIT")
Core.eval(@__MODULE__,Meta.parse(variant))

"""Preserve the old formatter's exact common-schema eligibility check."""
function common_forms(proof)
    proof isa AbstractDict && length(proof)==12 || return nothing
    all(key->get(proof,key,nothing) isa Int,FIELDS) || return nothing
    get(proof,"capped",nothing) isa Bool && get(proof,"heuristic_pruning",nothing)===false || return nothing
    order=get(proof,"coset_order",nothing)
    order isa String && order=="increasing nonzero quotient integer with exact bent count" || return nothing
    forms=get(proof,"V5_forms",nothing)
    forms isa Vector && length(forms)==5 && all(x->x isa Int,forms) || return nothing
    forms
end

"""Append the same canonical proof without constructing an intermediate string."""
function write_proof(io,proof)
    forms=common_forms(proof)
    if forms===nothing
        write(io,_closure_text(proof));return nothing
    end
    print(io,"V5_forms = [",forms[1]::Int,", ",forms[2]::Int,", ",forms[3]::Int,", ",forms[4]::Int,", ",forms[5]::Int,
        "]\ncandidate_spaces = ",proof["candidate_spaces"]::Int,"\ncapped = ",proof["capped"]::Bool,
        "\ncompletion_spaces = ",proof["completion_spaces"]::Int,
        "\ncoset_order = \"increasing nonzero quotient integer with exact bent count\"\ncoset_representative = ",proof["coset_representative"]::Int,
        "\ndu_reject = ",proof["du_reject"]::Int,"\nfirst_x = ",proof["first_x"]::Int,
        "\nheuristic_pruning = false\nlinear_system_candidates = ",proof["linear_system_candidates"]::Int,
        "\nnext_x = ",proof["next_x"]::Int,"\ntotal_x = ",proof["total_x"]::Int,'\n')
    nothing
end

"""Write and patch each proof's byte length, preserving all existing framing."""
function direct_row(job_id,chunks)
    n=length(chunks);1<=n<=65536 || error("invalid compact ledger block length")
    firstproof=first(chunks)["proof"];lastproof=last(chunks)["proof"]
    first_evidence=text_proof(firstproof)
    if n==1
        return (job_id=job_id,first_x=firstproof["first_x"],next_x=lastproof["next_x"],
            total_x=firstproof["total_x"],capped=Int(firstproof["capped"]),evidence=first_evidence)
    end
    estimate=4+n*max(512,44+sizeof(first_evidence)+64)
    io=IOBuffer(;sizehint=min(LIMIT,estimate));write(io,htol(UInt32(n)));capped=0
    for (i,chunk) in enumerate(chunks)
        proof=chunk["proof"];cap=Int(proof["capped"]);capped=max(capped,cap)
        position(io)+44<=LIMIT || error("compact ledger block exceeds size limit")
        for value in (job_id,proof["first_x"],proof["next_x"],proof["total_x"],cap)
            value isa Integer && value>=0 || error("invalid compact ledger integer")
            write(io,htol(UInt64(value)))
        end
        length_position=position(io);write(io,UInt32(0));text_position=position(io)
        i==1 ? write(io,first_evidence) : write_proof(io,proof)
        next_position=position(io);next_position<=LIMIT || error("compact ledger block exceeds size limit")
        seek(io,length_position);write(io,htol(UInt32(next_position-text_position)));seek(io,next_position)
    end
    (job_id=job_id,first_x=firstproof["first_x"],next_x=lastproof["next_x"],total_x=firstproof["total_x"],
        capped,evidence=_closure_encode_chunk_bytes(take!(io)))
end
end
