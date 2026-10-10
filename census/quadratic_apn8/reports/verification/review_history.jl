"""Reconcile all historical study lists against the source-rebuilt quadratic baseline.

The existing independent verification of four files is reused only at matching
file/reference digests. Other records are independently verified; --full true
rechecks every input instead of reusing that report.
"""
const REVIEW_HISTORY_USAGE=nothing
using VBFSearch: DiscoveryEvidence
using VBFSearch: DiscoveryInputs
using .DiscoveryEvidence,.DiscoveryInputs,TOML,Dates
function review_history(args)
    cfg=Dict("outdir"=>joinpath(@__DIR__,"results","history"),"baseline"=>DEFAULT_REFERENCE,"full"=>"false")
    iseven(length(args)) || error("use --name VALUE pairs")
    for i in 1:2:length(args)
        key=replace(args[i],r"^--"=>"");haskey(cfg,key) || error("unknown option $key");cfg[key]=args[i+1]
    end
    cfg["full"] in ("true","false") || error("full must be true or false")
    paths=[joinpath(ROOT,p) for p in ["census/quadratic_apn8/search_b52/results/desk1/found.tsv", "census/quadratic_apn8/new_classes_553.tsv", "census/quadratic_apn8/new_classes_extra.tsv", "census/quadratic_apn8/search_b52/new_classes_trial_773.tsv", "census/quadratic_apn8/theory/hyperplane_scan/new_classes_hyperplane.tsv"]]
    known,verification=validated_study(paths,cfg["baseline"];reuse=cfg["full"]=="false")
    reference=open_reference(cfg["baseline"])
    seen=Set{String}();absent=Set{String}();sources=Dict{String,Any}[]
    try
        for path in paths
            hashes=Set{String}();new_absent=Set{String}();count=0
            each_candidate(path) do row
                count+=1;push!(hashes,row.hash)
            end
            for hash in hashes
                hit=haskey(reference.supplement,hash) || !isempty(collect(DiscoveryEvidence.DBI.execute(reference.statement,(hash,))))
                if !hit
                    hash in absent || push!(new_absent,hash)
                    push!(absent,hash)
                end
            end
            push!(sources,Dict("path"=>relpath(path,ROOT),"records"=>count,"distinct_signatures"=>length(hashes),
                "additional_absent_signatures"=>length(new_absent),"sha256"=>filehash(path)))
            union!(seen,hashes)
        end
        report=Dict("reference"=>reference.metadata,"verification"=>verification,"sources"=>sources,
            "distinct_study_signatures"=>length(seen),"corpus_absent_signature_buckets"=>length(absent),
            "quadratic_ccz_class_lower_bound_absent"=>length(absent),
            "absent_candidates_inequivalent_to_all_apn_power_functions"=>
                all(row->!(row["sigma_hash"] in absent),reference.metadata["gold_coverage"]),
            "literature_novelty"=>"unresolved","created_utc"=>string(Dates.now(Dates.UTC)))
        mkpath(cfg["outdir"])
        open(io->TOML.print(io,report;sorted=true),joinpath(cfg["outdir"],"history.toml"),"w")
        println("Historical distinct signatures: $(length(seen)); absent from specified quadratic reference: $(length(absent))")
        report
    finally
        close_reference(reference)
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && review_history(ARGS)
