#!/usr/bin/env julia
# Bounded read-only-input pilot; never opens a campaign database or dispatches jobs.
# Run from the repository root, for example:
# julia --project=docs/inspector packages/VBFSearch/tools/analysis/v5_stabilizer_pilot.jl \
#   --sample sample.json --output stabilizer-pilot.json --sample-stride 4 --max-samples 32
using VBF, JSON3, SHA, Statistics

function stabilizer_pilot_options(args)
    options=Dict("sample-stride"=>"4", "max-samples"=>"32", "max-nodes"=>"10000",
        "timeout-seconds"=>"1.0", "max-memory-bytes"=>string(512*1024^2))
    allowed=Set(vcat(collect(keys(options)), ["sample","output"]))
    iseven(length(args)) || error("options require --name value pairs")
    for i in 1:2:length(args)
        startswith(args[i],"--") || error("expected --option")
        name=args[i][3:end]
        name in allowed || error("unknown option --$name")
        options[name]=args[i+1]
    end
    all(name->haskey(options,name), ("sample","output")) ||
        error("required: --sample sample.json --output report.json")
    return options
end

function stabilizer_pilot_implementation_digest()
    root=normpath(joinpath(@__DIR__,"../../../VBF/src"))
    paths=sort!([joinpath(dir,name) for (dir,_,names) in walkdir(root)
        for name in names if endswith(name,".jl")])
    files=[Dict("path"=>relpath(path,root),"sha256"=>bytes2hex(sha256(read(path))))
        for path in paths]
    binding=join([file["path"]*":"*file["sha256"]*"\n" for file in files])
    return Dict("sha256"=>bytes2hex(sha256(binding)),"files"=>files)
end

function stabilizer_pilot_main(args=ARGS)
    options=stabilizer_pilot_options(args)
    stride=parse(Int,options["sample-stride"])
    limit=parse(Int,options["max-samples"])
    max_nodes=parse(Int,options["max-nodes"])
    timeout=parse(Float64,options["timeout-seconds"])
    memory=parse(Int,options["max-memory-bytes"])
    stride>=1 && limit>=0 || error("sample stride must be positive and limit nonnegative")
    max_nodes>=0 && timeout>=0 && memory>=0 || error("budgets must be nonnegative")
    sample_path=abspath(options["sample"])
    output_path=abspath(options["output"])
    sample_path==output_path && error("output must differ from immutable input")
    sample_bytes=read(sample_path)
    input_digest=bytes2hex(sha256(sample_bytes))
    samples=JSON3.read(String(sample_bytes))
    indices=collect(1:stride:length(samples))
    resize!(indices,min(limit,length(indices)))
    implementation=stabilizer_pilot_implementation_digest()
    Q=VBF.QuadraticExtensions
    G=Q.geometry(8)
    # Warm the small-dimensional backend. First n=8 specialization costs, if
    # any, remain in the first recorded wall-clock measurement.
    warm=quadratic_space_stabilizers(Q.geometry(4),UInt32[0x21];timeout_seconds=20.0)
    warm.complete || error("small control did not exhaust its automorphism search")
    records=Dict{String,Any}[]
    work=nothing
    function publish(verified=false)
        times=[record["discovery_seconds"] for record in records]
        report=Dict("schema"=>"vbfsearch-v5-stabilizer-pilot-v1",
            "sample_path"=>sample_path,"sample_sha256"=>input_digest,
            "script_sha256"=>bytes2hex(sha256(read(@__FILE__))),
            "implementation"=>implementation,"julia_version"=>string(VERSION),
            "sample_indices"=>indices,"sampling"=>"deterministic stride, original input ordering",
            "max_nodes"=>max_nodes,"timeout_seconds"=>timeout,"max_memory_bytes"=>memory,
            "complete"=>verified && length(records)==length(indices),
            "backend"=>"bounded native EA automorphisms; exact projected GL-generator replay",
            "measured_spaces"=>length(records),
            "exhausted_trivial_input_stabilizers"=>count(r->r["group_complete"] &&
                r["generator_count"]==0,records),
            "spaces_with_verified_nonidentity_generators"=>count(r->r["generator_count"]>0,records),
            "sum_original_cosets"=>sum((r["original_cosets"] for r in records);init=0),
            "sum_representative_cosets"=>sum((r["orbit_count"] for r in records);init=0),
            "median_discovery_seconds"=>isempty(times) ? nothing : median(times),
            "records"=>records)
        mkpath(dirname(output_path))
        temporary=output_path*".tmp"
        open(temporary,"w") do io
            JSON3.pretty(io,report)
        end
        mv(temporary,output_path;force=true)
    end
    for i in indices
        sample=samples[i]
        forms=UInt32.(sample.forms)
        started=time_ns()
        stabilizers=quadratic_space_stabilizers(G,forms;
            max_nodes,timeout_seconds=timeout,max_memory_bytes=memory)
        discovery=(time_ns()-started)*1e-9
        record=Dict{String,Any}("sample_index"=>i,"job_id"=>sample.job_id,
            "origin"=>sample.origin,"b5"=>sample.b5,"need"=>sample.need,
            "generator_count"=>length(stabilizers.generators),
            "generators"=>stabilizers.generators,"discovery_seconds"=>discovery,
            "group_complete"=>stabilizers.complete,"stop_reason"=>String(stabilizers.stop_reason),
            "nodes_visited"=>stabilizers.nodes_visited,
            "discarded_identity_actions"=>stabilizers.discarded_identity_actions,
            "original_cosets"=>sample.result.total_x)
        if !isempty(stabilizers.generators)
            work===nothing && (work=Q.V5Work(23,8))
            started=time_ns()
            counts=Q.coset_bent_counts!(work.cnt,G,forms,Q.BETA8)
            X=UInt32[j-1 for j in 2:length(work.cnt)
                if work.cnt[j]==Int(sample.need)*counts.scale]
            length(X)==sample.result.total_x || error("stored eligible-coset count mismatch")
            plan=quadratic_extension_orbits(G,forms,X,stabilizers.generators)
            record["planning_seconds"]=(time_ns()-started)*1e-9
            record["orbit_count"]=length(plan.representatives)
            record["saved_cosets"]=length(X)-length(plan.representatives)
        else
            record["planning_seconds"]=0.0
            record["orbit_count"]=sample.result.total_x
            record["saved_cosets"]=0
        end
        push!(records,record)
        publish()
        println((sample_index=i,origin=sample.origin,b5=sample.b5,
            generators=record["generator_count"],complete=stabilizers.complete,
            seconds=discovery,orbits=record["orbit_count"],saved=record["saved_cosets"]))
        flush(stdout)
    end
    # Inputs and implementation are bound before any measurements; refuse an
    # unnoticed edit during this otherwise read-only evidence collection.
    bytes2hex(sha256(read(sample_path)))==input_digest || error("input changed during pilot")
    stabilizer_pilot_implementation_digest()["sha256"]==implementation["sha256"] ||
        error("mathematics implementation changed during pilot")
    publish(true)
    return output_path
end

abspath(PROGRAM_FILE)==(@__FILE__) && stabilizer_pilot_main()
