"""Prepare an explicitly versioned validation experiment from an exact clean copy.

Historical rows retain their source implementation attribution. This deliberately
creates a new experiment with recorded toolchain and implementation lineage;
the stricter controller-only `closure_upgrade` contract is unchanged.
"""
module CampaignValidationFinalize
using VBFSearch,TOML,SHA,JSON3,Dates,SQLite
const FP=VBFSearch

"""Archive current code and replace only identity metadata in the verified copy."""
function finalize_validation(source,target,receipt_path)
    receipt=JSON3.read(read(receipt_path,String),Dict{String,Any})
    source=realpath(source);target=realpath(target)
    receipt["source"]==source && receipt["target"]==target || error("copy receipt paths differ")
    receipt["source_sha256"]==receipt["copy_sha256"] || error("copy was not byte exact")
    old=TOML.parsefile(joinpath(source,"identity.toml"))
    old["schema"]==FP.CLOSURE_SCHEMA || error("unsupported source schema")
    FP.BOOT_IMPLEMENTATION[]==FP.implementation_fingerprint() || error("loaded code differs from current files")
    database=joinpath(target,"closure.sqlite")
    filesize(database)==receipt["database_bytes"] || error("copied database size changed")
    FP._closure_storage_filehash(database)==receipt["copy_sha256"] || error("copied database changed")
    implementation=FP.implementation_fingerprint()
    changed=sort!([p for p in union(keys(old["implementation"]),keys(implementation))
        if get(old["implementation"],p,nothing)!=get(implementation,p,nothing)])
    record=Dict{String,Any}("schema"=>"vbfsearch-campaign-validation-fork-v1",
        "created_utc"=>string(now(UTC))*"Z","source_directory"=>source,
        "source_main_sha256"=>receipt["source_sha256"],"copied_main_sha256"=>receipt["copy_sha256"],
        "source_identity_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(source,"identity.toml")),
        "source_sessions_through"=>receipt["source_sessions_through"],"source_table_counts"=>receipt["table_counts"],
        "prior_julia"=>old["julia"],"new_julia"=>string(VERSION),
        "prior_implementation"=>old["implementation"],"new_implementation"=>implementation,
        "changed_implementation_paths"=>changed,"scientific_parameters_unchanged"=>true,
        "historical_attribution"=>"Sessions through source_sessions_through retain prior Julia and implementation; inherited classes and proofs are historical evidence, not freshly reverified discoveries.",
        "rollback"=>"source_directory remains the stopped original; no second full database copy",
        "new_negative_cache_policy"=>"Reuse exhaustive negatives only with matching current solver fingerprint")
    workspace=joinpath(target,"replay","workspace")
    for (relative,digest) in implementation
        destination=joinpath(workspace,relative);mkpath(dirname(destination))
        cp(joinpath(FP.DiscoveryInputs.ROOT,relative),destination)
        FP.DiscoveryEvidence.filehash(destination)==digest || error("source changed during archive")
    end
    for relative in ("docs/inspector/Project.toml","docs/inspector/Manifest.toml",
            "packages/VBFSearch/tools/closure_continuous.jl","packages/VBFSearch/tools/closure_baseline.jl",
            "packages/VBFSearch/tools/closure_seed_progress.jl")
        destination=joinpath(workspace,relative);mkpath(dirname(destination))
        cp(joinpath(FP.DiscoveryInputs.ROOT,relative),destination)
    end
    current=deepcopy(old);current["implementation"]=implementation;current["julia"]=string(VERSION)
    current["validation_fork"]=Dict("record"=>"validation-fork.toml",
        "source_main_sha256"=>receipt["source_sha256"],"source_sessions_through"=>receipt["source_sessions_through"])
    current["scientific"]==old["scientific"] || error("scientific scope changed")
    db=SQLite.DB(database)
    try
        TOML.parse(only(FP._closure_rows(db,"SELECT value FROM metadata WHERE key='identity'"))["value"])==old || error("source identity differs in copied database")
        FP._closure_exec(db,"BEGIN IMMEDIATE")
        FP._closure_exec(db,"UPDATE metadata SET value=? WHERE key='identity'",(FP._closure_text(current),))
        FP._closure_exec(db,"INSERT INTO metadata VALUES('validation_fork',?)",(FP._closure_text(record),))
        FP._closure_exec(db,"COMMIT")
        FP._closure_exec(db,"PRAGMA wal_checkpoint(TRUNCATE)")
    finally
        close(db)
    end
    FP.DiscoveryStore.atomic_toml(joinpath(target,"identity.toml"),current)
    FP.DiscoveryStore.atomic_toml(joinpath(target,"validation-fork.toml"),record)
    progress=TOML.parsefile(joinpath(source,"progress.toml"))
    progress["directory"]=target;progress["state"]="validation_prepared";progress["running"]=false
    FP.DiscoveryStore.atomic_toml(joinpath(target,"progress.toml"),progress)
    implementation==FP.implementation_fingerprint() || error("source changed during finalization")
    println(JSON3.write(Dict("event"=>"validation_fork_prepared","target"=>target,
        "changed_source_paths"=>length(changed),"julia"=>string(VERSION),
        "validation_policy"=>"The production controller performs its normal identity and complete cursor checks before any search work.")))
    flush(stdout)
end
end

abspath(PROGRAM_FILE)==(@__FILE__) && CampaignValidationFinalize.finalize_validation(ARGS...)
