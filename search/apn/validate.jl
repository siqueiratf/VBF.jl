"""Import historical functions into an independently verified evidence database, or recheck a graph certificate."""
const VALIDATE_USAGE=nothing
include("evidence.jl")
include("store.jl")
include("inputs.jl")
using .DiscoveryEvidence,.DiscoveryStore,.DiscoveryInputs,TOML,Dates

function validate_inputs(args)
    cfg=Dict("outdir"=>"", "baseline"=>DEFAULT_REFERENCE,"limit"=>"0","certificate"=>"")
    inputs=String[]
    iseven(length(args)) || error("use --name VALUE pairs")
    for i in 1:2:length(args)
        key=replace(args[i],r"^--"=>"")
        key=="input" ? push!(inputs,abspath(args[i+1])) : haskey(cfg,key) ? (cfg[key]=args[i+1]) : error("unknown option $key")
    end
    if !isempty(cfg["certificate"])
        proof=TOML.parsefile(cfg["certificate"])
        verify_comparison(proof) || error("certificate not independently verifiable (exhaustive solver negatives need a replay)")
        println("Graph witness or separating quadratic invariant independently verified.")
        return
    end
    isempty(inputs) && error("at least one --input TSV is required")
    isempty(cfg["outdir"]) && error("--outdir is required")
    limit=parse(Int,cfg["limit"]);limit>=0 || error("limit must be nonnegative; zero means every record")
    reference=open_reference(cfg["baseline"])
    identity=Dict("method"=>"historical_import", "inputs"=>source_fingerprint(inputs),
        "reference"=>reference.metadata,"code"=>implementation_fingerprint(),"limit"=>limit)
    store=open_store(cfg["outdir"],identity)
    total=0
    try
        for path in inputs
            input_digest=filehash(path)
            batch=Dict{String,Any}[]
            each_candidate(path) do row
                limit>0 && total>=limit && return
                p=classify(candidate_lut(row.payload),reference)
                p["apn"] && p["quadratic"] || error("invalid quadratic APN at $path:$(row.line)")
                p["sigma_hash"]==row.hash || error("signature mismatch at $path:$(row.line)")
                p["origin"]=Dict("file_sha256"=>input_digest,
                    "file"=>abspath(path),"line"=>row.line,"original_status"=>row.status,"record"=>row.fields)
                push!(batch,p);total+=1
                if length(batch)>=256
                    transaction(store) do;for item in batch;register!(store,item);end;end
                    empty!(batch)
                end
            end
            transaction(store) do;for item in batch;register!(store,item);end;end
        end
        summary=merge(snapshot(store),Dict("records_independently_verified"=>total,
            "complete_input_validation"=>limit==0,"generated_utc"=>string(Dates.now(Dates.UTC))))
        atomic_toml(joinpath(store.path,"validation.toml"),summary)
        println(summary)
    finally
        close_store(store);close_reference(reference)
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && validate_inputs(ARGS)
