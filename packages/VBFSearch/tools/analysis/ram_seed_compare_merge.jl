"""Verify disjoint complete root shards without inventing a sequential digest.

Every shard independently checks the complete candidate/EA partition. Only
construction counts are summed. The original canonical digests remain attached
to their precise root ordinal lists; a new summary hash binds those shard
receipts and is explicitly distinct from the all-roots sequential digest.
"""
module RAMSeedCompareMerge
using JSON3,SHA

function canonical(value)
    value isa NamedTuple && return canonical(Dict(String(k)=>v for (k,v) in pairs(value)))
    value isa AbstractDict && return [(String(k),canonical(v)) for (k,v) in sort!(collect(value);by=x->String(first(x)))]
    value isa AbstractVector && return map(canonical,value)
    value
end
digest(path)=bytes2hex(open(SHA.sha256,path))
function file_pin(path)
    wal=path*"-wal"
    Dict("bytes"=>filesize(path),"mtime"=>mtime(path),
        "wal"=>(isfile(wal) ? Dict("bytes"=>filesize(wal),"mtime"=>mtime(wal)) : nothing))
end

"""Require a complete, stable, identically sourced set of verified shard receipts."""
function merge_reports(paths)
    isempty(paths) && error("no comparison shard receipts supplied")
    sources=map(paths) do path
        bytes=read(path)
        (;path=abspath(path),sha256=bytes2hex(SHA.sha256(bytes)),
            report=JSON3.read(bytes,Dict{String,Any}))
    end
    first_report=first(sources).report
    total=Int(first_report["total_expanded_roots"]);total>0 || error("empty expanded-root registry")
    shard_count=Int(first_report["root_shard"]["count"])
    shard_count==length(sources) || error("missing or extra comparison shard receipts")
    seen=falses(total);indices=Set{Int}();counts=Dict{String,Int128}()
    science_shards=Any[];counter_logs=Any[];counter_totals=Dict{String,Int128}()
    strict=true
    common=("schema","ram","baseline","source_pins","helper_julia","helper_source_sha256",
        "total_expanded_roots","expanded_root_registry_sha256","audited_root_inventory",
        "roots_sha256","source_runtime")
    candidate_keys=("rows","classes","sha256")
    policy_keys=("field","per_coset_reduction_only","policy")
    helper=joinpath(@__DIR__,"ram_seed_compare.jl")
    digest(helper)==first_report["helper_source_sha256"] || error("comparison helper differs from the shards' pinned source")
    for source in sort!(sources;by=x->Int(x.report["root_shard"]["index"]))
        report=source.report
        report["schema"]=="vbfsearch-ram-seed-comparison-v1" || error("unsupported comparison shard schema")
        all(get(report,k,false)===true for k in ("verified","source_files_unchanged","helper_source_unchanged")) ||
            error("comparison shard failed or changed sources: "*source.path)
        for key in common
            isequal(report[key],first_report[key]) || error("comparison shards differ in "*key)
        end
        for key in candidate_keys
            isequal(report["candidates"][key],first_report["candidates"][key]) || error("candidate/EA shard checks differ in "*key)
        end
        for key in policy_keys
            isequal(report["coverage_work_counter"][key],first_report["coverage_work_counter"][key]) || error("coverage accounting policies differ")
        end
        index=Int(report["root_shard"]["index"])
        Int(report["root_shard"]["count"])==shard_count && 1<=index<=shard_count && !(index in indices) ||
            error("invalid or repeated shard index")
        push!(indices,index)
        ordinals=Int.(report["expanded_root_ordinals"])
        ordinals==collect(index:shard_count:total) || error("shard root ordinals differ from their exact declared selection")
        length(ordinals)==report["expanded_roots"] || error("shard root count differs from its ordinal list")
        for ordinal in ordinals
            seen[ordinal] && error("comparison shards overlap")
            seen[ordinal]=true
        end
        Set(keys(report["counts"]))==Set(keys(first_report["counts"])) || error("shard count domains differ")
        for (key,count) in report["counts"]
            count isa Integer && count>=0 || error("invalid shard construction count")
            counts[key]=get(counts,key,Int128(0))+count
        end
        for key in ("different_jobs","different_cosets","ram_total","baseline_total")
            count=report["coverage_work_counter"][key]
            count isa Integer && count>=0 || error("invalid shard coverage accounting count")
            counter_totals[key]=get(counter_totals,key,Int128(0))+count
        end
        strict &= Bool(report["strict_full_proof_parity"])
        log=String(report["counter_difference_log"])
        digest(log)==report["counter_difference_log_sha256"] || error("shard coverage diagnostic log changed")
        push!(counter_logs,(;index,path=log,sha256=report["counter_difference_log_sha256"]))
        push!(science_shards,(;index,ordinals,science=report["science"],receipt=source.path,receipt_sha256=source.sha256))
    end
    all(seen) && indices==Set(1:shard_count) || error("comparison root shard union is incomplete")
    current=Dict("ram"=>file_pin(first_report["ram"]),"baseline"=>file_pin(first_report["baseline"]))
    isequal(current,first_report["source_pins"]) || error("comparison databases or WAL changed after the shard checks")
    summary=bytes2hex(SHA.sha256(codeunits(JSON3.write(canonical(science_shards)))))
    (;schema="vbfsearch-ram-seed-comparison-shards-v1",verified=true,
        expanded_roots=total,shard_count,root_union_complete=true,root_union_disjoint=true,
        expanded_root_registry_sha256=first_report["expanded_root_registry_sha256"],
        audited_root_inventory=first_report["audited_root_inventory"],roots_sha256=first_report["roots_sha256"],
        ram=first_report["ram"],baseline=first_report["baseline"],source_pins=first_report["source_pins"],
        helper_source_sha256=first_report["helper_source_sha256"],source_runtime=first_report["source_runtime"],
        counts,candidates=first_report["candidates"],strict_full_proof_parity=strict,
        coverage_work_counter=merge(Dict(key=>first_report["coverage_work_counter"][key] for key in policy_keys),counter_totals),
        counter_difference_logs=counter_logs,science_shards,shard_summary_sha256=summary,
        digest_scope="ordered shard receipts; individual root-shard digests retained; not the all-roots sequential digest")
end

function main(args=ARGS)
    length(args)>=3 || error("usage: ram_seed_compare_merge.jl OUTPUT.json SHARD1.json SHARD2.json [...]")
    output=abspath(first(args));ispath(output) && error("merged comparison output already exists")
    helper=digest(@__FILE__);started=time()
    report=Dict(String(k)=>v for (k,v) in pairs(merge_reports(args[2:end])))
    report["merge_helper_sha256"]=helper;report["elapsed_seconds"]=time()-started
    digest(@__FILE__)==helper || error("comparison merge helper changed while checking receipts")
    open(io->JSON3.pretty(io,report),output,"w")
    println("RAM_SEED_COMPARISON_SHARDS_VERIFIED ",output)
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
end
