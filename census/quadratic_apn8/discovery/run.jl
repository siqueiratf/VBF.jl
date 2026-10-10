"""Transactional, resumable finite switching or V5 construction searches. See README.md."""
const DISCOVERY_USAGE=nothing
using SHA
const BOOT_PROVENANCE_SHA=bytes2hex(open(SHA.sha256,joinpath(@__DIR__,"provenance.jl")))
include("provenance.jl")
const BOOT_IMPLEMENTATION=source_fingerprint_impl(normpath(joinpath(@__DIR__,"../../..")))
BOOT_IMPLEMENTATION["census/quadratic_apn8/discovery/provenance.jl"]==BOOT_PROVENANCE_SHA || error("provenance helper changed while loading")
include("evidence.jl")
include("store.jl")
include("inputs.jl")
using .DiscoveryEvidence,.DiscoveryStore,.DiscoveryInputs
using VBF,VBFCatalog,SHA,TOML,Dates,Random
module Fourier
include("../search_b52/common.jl")
end
const ROOT=normpath(joinpath(@__DIR__,"../../.."))

function run_options(args)
    cfg=Dict("outdir"=>joinpath(@__DIR__,"results","run"),"resume"=>"false",
        "method"=>"switching","wall-seconds"=>"28800","seconds"=>"60",
        "evaluations"=>"10000","workers"=>string(Threads.nthreads()),
        "limit"=>"1000","seed"=>"82026","chunk-x"=>"128",
        "target-b6"=>"52","v5-bent"=>"max","baseline"=>Existing.DEFAULT_OUTPUT,
        "supplement"=>joinpath(ROOT,Existing.SUPPLEMENT),
        "orbit-seconds"=>"0","ea-representatives"=>"0")
    inputs=String[]
    iseven(length(args)) || error("use --name VALUE pairs")
    for i in 1:2:length(args)
        key=replace(args[i],r"^--"=>"")
        if key=="input"
            push!(inputs,abspath(args[i+1]))
        else
            haskey(cfg,key) || error("unknown option $(args[i])")
            cfg[key]=args[i+1]
        end
    end
    cfg,inputs
end

function code_identity()
    current=implementation_fingerprint()
    current==BOOT_IMPLEMENTATION || error("implementation changed while packages were loading; restart from a stable checkout")
    current
end

function prepared_options(cfg)
    method=cfg["method"]
    method in ("switching","v5") || error("method must be switching or v5")
    workers=parse(Int,cfg["workers"])
    1<=workers<=Threads.nthreads() || error("invalid worker count")
    wall=parse(Float64,cfg["wall-seconds"]);seconds=parse(Float64,cfg["seconds"])
    wall>0 && isfinite(wall) && seconds>0 && isfinite(seconds) || error("positive finite time limits required")
    parse(Int,cfg["limit"])>0 && parse(Int,cfg["evaluations"])>0 && parse(Int,cfg["chunk-x"])>0 || error("positive enumeration limits required")
    ea=parse(Int,cfg["ea-representatives"]);orbit=parse(Float64,cfg["orbit-seconds"])
    ea>=0 && orbit>=0 && isfinite(orbit) && (ea==0 || orbit>0) || error("invalid EA representative limits")
    cfg["resume"] in ("true","false") || error("resume must be true or false")
    workers,wall,seconds
end

function scientific_run(args)
    cfg,extra=run_options(args)
    workers,wall,seconds=prepared_options(cfg)
    resume=cfg["resume"]=="true"
    dir=abspath(cfg["outdir"])
    resume || !isdir(dir) || isempty(readdir(dir)) || error("new runs need an empty output directory")
    mkpath(dir)
    original=unique(vcat([joinpath(ROOT,p) for p in [Existing.STUDY_INPUTS;Existing.SUPPLEMENT]],extra))
    frozen=joinpath(dir,"inputs")
    if !resume
        mkpath(frozen)
        for (i,p) in enumerate(original)
            isfile(p) || error("missing input $p")
            cp(p,joinpath(frozen,string(i)*"_"*basename(p)))
        end
    end
    paths=sort!([joinpath(frozen,f) for f in readdir(frozen)];by=p->parse(Int,first(split(basename(p),'_'))))
    reference=open_reference(abspath(cfg["baseline"]);supplement_path=abspath(cfg["supplement"]))
    known,validation=validated_study(paths,abspath(cfg["baseline"]))
    semantic=Dict(k=>cfg[k] for k in ("method","limit","seed","target-b6","v5-bent","orbit-seconds","ea-representatives"))
    identity=Dict("configuration"=>semantic,"inputs"=>source_fingerprint(paths),"code"=>code_identity(),
        "reference"=>Dict(k=>reference.metadata[k] for k in ("sha256","manifest_sha256","supplement_sha256","signatures")),
        "julia"=>string(VERSION))
    store=open_store(dir,identity;resume)
    started=time_ns();remaining()=max(0.0,wall-(time_ns()-started)*1e-9)
    stopped=Threads.Atomic{Bool}(false)
    last_stop_check=Threads.Atomic{UInt64}(0)
    # Poll from the workers themselves: a Timer task can starve when every
    # default-pool thread runs a CPU-bound construction.
    stop_wanted=function()
        stopped[] && return true
        now=time_ns();previous=last_stop_check[]
        if now>=previous && now-previous>=250_000_000 &&
            Threads.atomic_cas!(last_stop_check,previous,now)==previous
            isfile(joinpath(dir,"STOP")) && (stopped[]=true)
        end
        stopped[]
    end
    errors=String[]
    try
    # Archive the exact implementation, including uncommitted work, outside git.
    for (relative,digest) in identity["code"]
        destination=joinpath(dir,"source",relative)
        if !isfile(destination)
            mkpath(dirname(destination));cp(joinpath(ROOT,relative),destination)
        end
        filehash(destination)==digest || error("source archive changed: $relative")
    end
        if isempty(query(store,"SELECT value FROM metadata WHERE key='plan_complete'"))
            transaction(store) do
            _,seeds=Existing.load_study(paths,max(1,cld(parse(Int,cfg["limit"]),length(paths))),Xoshiro(parse(Int,cfg["seed"])))
            gold=gold_apn(8).lut
            gp=properties(gold)
            pushfirst!(seeds,(gp["sigma_hash"],bytes2hex(gold)))
            unique!(seeds);resize!(seeds,min(length(seeds),parse(Int,cfg["limit"])))
            for (hash,payload) in seeds
                kind=cfg["method"]=="v5" ? "prepare_v5" : "switching"
                seed!(store,Existing.candidate_lut(payload),hash,kind)
            end
            if cfg["method"]=="switching" && parse(Int,cfg["ea-representatives"])>0
                for seed in query(store,"SELECT * FROM seeds")
                    add_unit!(store,seed["id"],"prepare_ea",Dict("lut_hex"=>seed["lut_hex"]))
                end
            end
            DiscoveryStore.execute!(store.db,"INSERT INTO metadata VALUES('plan_complete','true')")
            end
            atomic_toml(joinpath(dir,"study_validation.toml"),validation)
        end
        started=time_ns()
        session=DiscoveryStore.transaction(store) do
            DiscoveryStore.execute!(store.db,"INSERT INTO sessions(started) VALUES(?)",(string(Dates.now(Dates.UTC)),))
            Int(only(query(store,"SELECT last_insert_rowid() id"))["id"])
        end
        atomic_toml(joinpath(dir,"session_$(session).toml"),Dict("configuration"=>cfg,"workers"=>workers,
            "git_commit"=>readchomp(`git -C $ROOT rev-parse HEAD`),"git_dirty"=>!isempty(readchomp(`git -C $ROOT status --porcelain`)),"started_utc"=>string(Dates.now(Dates.UTC)),
            "cpu"=>Sys.cpu_info()[1].model,"cpu_threads"=>Sys.CPU_THREADS,
            "platform"=>Sys.MACHINE,"word_size"=>Sys.WORD_SIZE,"pid"=>getpid(),
            "compiled_modules"=>Int(Base.JLOptions().use_compiled_modules),
            "optimization_level"=>Int(Base.JLOptions().opt_level),
            "gc_threads"=>Threads.ngcthreads(),"julia_threads"=>Threads.nthreads(),"reference"=>reference.metadata))
        println("Discovery session $session: $workers workers; $wall seconds; method $(cfg["method"]); $dir")
        flush(stdout)
        Threads.@threads :static for worker in 1:workers
            localref=open_reference(abspath(cfg["baseline"]);supplement_path=abspath(cfg["supplement"]))
            geometry=cfg["method"]=="v5" ? Fourier.geometry(8) : nothing
            work=cfg["method"]=="v5" ? Fourier.V5Work(23) : nothing
            try
                while remaining()>0 && !stop_wanted()
                    unit=claim!(store)
                    unit===nothing && break
                    try
                        payload=DiscoveryStore.parse_toml(unit["payload"])
                        F=SBox{8,UInt8}(hex2bytes(payload["lut_hex"]))
                        if unit["kind"]=="switching"
                            verify_ccz_witness(hex2bytes(unit["lut_hex"]),F.lut,
                                payload["ccz_columns"],payload["ccz_constant"]) || error("invalid saved parent CCZ map")
                        end
                        parent=classify(F.lut,localref)
                        parent["apn"] || error("non-APN seed")
                        parent["role"]="seed";parent["additional_signature"]=false
                        get(parent,"sigma_hash",unit["sigma"])==unit["sigma"] || error("seed signature mismatch")
                        register!(store,parent)
                        if unit["kind"]=="prepare_ea"
                            orbit=ea_class_representatives(F;prefer_permutations=false,
                                subspace_algorithm=:optimized,timeout_seconds=min(seconds,parse(Float64,cfg["orbit-seconds"]),remaining()))
                            selected=0
                            for (j,G) in enumerate(orbit.representatives)
                                algebraic_degree(G)==2 && continue
                                A=orbit.mappings[j]
                                verify_ccz_witness(F.lut,G.lut,Int.(A.linear.cols),Int(A.constant)) || error("invalid orbit witness")
                                add_unit!(store,unit["seed_id"],"switching",Dict("lut_hex"=>bytes2hex(G.lut),
                                    "ccz_columns"=>Int.(A.linear.cols),"ccz_constant"=>Int(A.constant),"orbit_index"=>j))
                                selected+=1
                                selected>=parse(Int,cfg["ea-representatives"]) && break
                            end
                            finish!(store,unit,Dict("orbit_complete"=>orbit.complete,"available"=>length(orbit.representatives),
                                "selected_nonquadratic"=>selected,"representative_cap"=>parse(Int,cfg["ea-representatives"]),
                                "stop"=>string(orbit.stop_reason));done=true)
                        elseif unit["kind"]=="prepare_v5"
                            parent["quadratic"] || error("V5 requires quadratic APN")
                            a=anf(F)
                            c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:7 for j in (i+1):7]
                            comp=Fourier.comp_forms(Fourier.coord_forms(c,8));bent=Fourier.bent_mask(geometry,comp)
                            best=first(Fourier.max_bent_dim(comp,bent,5))
                            want=cfg["v5-bent"]=="max" ? Set([best]) : Set(parse.(Int,split(cfg["v5-bent"],',')))
                            spaces=Fourier.subspaces_of_comp(comp,bent,5;keep=n->n in want)
                            for V in spaces
                                need=parse(Int,cfg["target-b6"])-V.nbent
                                need<0 && continue
                                add_unit!(store,unit["seed_id"],"v5",Dict("lut_hex"=>payload["lut_hex"],"forms"=>Int.(V.forms),"need"=>need))
                            end
                            finish!(store,unit,Dict("v5_spaces"=>length(spaces),"heuristic_pruning"=>false);done=true)
                        elseif unit["kind"]=="v5"
                            r=Fourier.v5_extensions(geometry,UInt32.(payload["forms"]),Int(payload["need"]),work;
                                beta=Fourier.BETA8,max_kernel=23,max_x=parse(Int,cfg["chunk-x"]),
                                start_x=Int(unit["direction"]),should_stop=()->stop_wanted() || remaining()==0)
                            records=Dict{String,Any}[]
                            for S in r.Ss
                                _,G=Fourier.function_of(geometry,S)
                                p=classify(G.lut,localref)
                                p["apn"] && p["quadratic"] || error("invalid Fourier extension")
                                p["additional_signature"]=!p["reference_signature_match"] && !(p["sigma_hash"] in known)
                                p["role"]="generated";push!(records,p)
                            end
                            proof=Dict("first_x"=>Int(unit["direction"]),"next_x"=>r.next_x,"total_x"=>r.nX,
                                "capped"=>r.capped,"candidate_spaces"=>length(r.Ss),"heuristic_pruning"=>false)
                            if r.nX_used>0 || r.nX==0
                                commit_chunk!(store,unit,proof,records;done=r.next_x>r.nX && !r.capped)
                            else
                                finish!(store,unit,Dict("stop"=>"time_or_external"))
                            end
                        else
                            callback=function(event,value)
                                p=event===:candidate_complete ? classify(value.candidate.lut,localref) : nothing
                                if p!==nothing
                                    p["apn"]==value.apn || error("independent APN test disagrees")
                                    p["role"]="generated"
                                    p["additional_signature"]=p["apn"] && p["quadratic"] && !p["reference_signature_match"] && !(p["sigma_hash"] in known)
                                end
                                checkpoint!(store,unit,event,value,p)
                            end
                            r=switching_neighbors_bounded(F;max_evaluations=parse(Int,cfg["evaluations"]),
                                timeout_seconds=min(seconds,remaining()),start_direction=Int(unit["direction"]),
                                start_combination=parse(BigInt,unit["combination"]),checkpoint=callback,
                                stop_requested=()->stop_wanted() || remaining()==0)
                            finish!(store,unit,Dict("nodes_this_slice"=>nodes_visited(r),"seconds_this_slice"=>elapsed_seconds(r),
                                "stop"=>r isa Exhausted ? "none" : string(r.where_it_stopped.reason));done=r isa Exhausted)
                        end
                        lock(store.guard) do
                            atomic_toml(joinpath(dir,"progress.toml"),merge(snapshot(store),Dict("session"=>session,"elapsed_seconds"=>(time_ns()-started)*1e-9)))
                        end
                    catch err
                        message=sprint(showerror,err,catch_backtrace())
                        finish!(store,unit,Dict("error"=>message))
                        lock(store.guard) do;push!(errors,message);end
                        stopped[]=true
                    end
                end
            finally
                close_reference(localref)
            end
        end
        summary=merge(snapshot(store),Dict("session"=>session,"elapsed_seconds"=>(time_ns()-started)*1e-9,
            "stop"=>!isempty(errors) ? "error" : stopped[] ? "external" : remaining()==0 ? "time" : "plan_exhausted","errors"=>errors))
        DiscoveryStore.transaction(store) do
            DiscoveryStore.execute!(store.db,"UPDATE sessions SET finished=?,seconds=?,reason=? WHERE id=?",
                (string(Dates.now(Dates.UTC)),summary["elapsed_seconds"],summary["stop"],session))
        end
        atomic_toml(joinpath(dir,"summary.toml"),summary)
        println(summary)
        isempty(errors) || error("discovery session failed; state preserved: $(join(errors,"; "))")
        summary
    finally
        close_store(store);close_reference(reference)
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && scientific_run(ARGS)
