"""Use VBF to verify a candidate's full DDT, ANF degree and quadratic signature."""
candidate_properties(lut; detailed=false) = properties(lut; detailed)

"""Request cooperative stopping at the next supported checkpoint boundary."""
function stop!(directory)
    isfile(joinpath(directory,"manifest.toml")) || error("not a search run")
    touch(joinpath(directory,"STOP"))
    nothing
end

"""Recheck stored candidates, certificates and finite enumeration ledger."""
audit(directory; reference=get(ENV,"VBF_APN_REFERENCE",DEFAULT_REFERENCE),
        supplement=get(ENV,"VBF_APN_SUPPLEMENT",DEFAULT_SUPPLEMENT),limit=0) =
    audit_run(directory;baseline=reference,limit,supplement)

"""
    validate(inputs; output, reference=..., supplement=..., limit=0)

Validate TSV inputs and persist exact LUTs and scoped reference
evidence. Zero limit checks every input row; a positive limit records partial coverage.
"""
function validate(inputs;output,reference=get(ENV,"VBF_APN_REFERENCE",DEFAULT_REFERENCE),
        supplement=get(ENV,"VBF_APN_SUPPLEMENT",DEFAULT_SUPPLEMENT),limit=0)
    isempty(inputs) && error("at least one input TSV is required")
    limit>=0 || error("limit must be nonnegative")
    original=abspath.(inputs)
    !isdir(output) || isempty(readdir(output)) || error("validation needs an empty output directory")
    frozen=joinpath(output,"inputs");mkpath(frozen)
    paths=String[]
    for (i,path) in enumerate(original)
        target=joinpath(frozen,string(i)*"_"*basename(path))
        cp(path,target);push!(paths,abspath(target))
    end
    ref=open_reference(reference;supplement_path=supplement)
    powtab=monomial_power_table(8,conway_polynomial(8))
    store=nothing
    total=0
    try
        identity=Dict("method"=>"validation_import","inputs"=>source_fingerprint(paths),
            "reference"=>reference_metadata(ref),"code"=>implementation_fingerprint(),"limit"=>limit)
        store=open_store(output,identity)
        for path in paths
            digest=filehash(path)
            transaction(store) do
                each_candidate(path) do row
                    limit>0 && total>=limit && return
                    p=classify(candidate_lut(row.payload;powtab),ref)
                    p["apn"] && p["quadratic"] || error("invalid quadratic APN at $path:$(row.line)")
                    p["sigma_hash"]==row.hash || error("signature mismatch at $path:$(row.line)")
                    p["origin"]=Dict("file_sha256"=>digest,"file"=>path,"line"=>row.line,
                        "original_status"=>row.status,"record"=>row.fields)
                    register!(store,p);total+=1
                end
                filehash(path)==digest || error("input changed during validation: $path")
            end
        end
        summary=merge(snapshot(store),Dict("records_verified"=>total,
            "complete_input_validation"=>limit==0,"generated_utc"=>string(Dates.now(Dates.UTC))))
        atomic_toml(joinpath(store.path,"validation.toml"),summary)
        summary
    finally
        store===nothing || close_store(store)
        close_reference(ref)
    end
end

"""Check a saved comparison through the same VBF APIs used by Search."""
function verify_certificate(path)
    verify_comparison(TOML.parsefile(path)) || error("invalid or unresolved comparison certificate")
    true
end

"""Dispatch the repository CLI using the same APIs as Julia and the inspector."""
main(args=ARGS) = CLI.main(args)
