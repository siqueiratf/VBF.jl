function code_identity()
    current=implementation_fingerprint()
    current==BOOT_IMPLEMENTATION[] || error("implementation changed while packages were loading; restart from a stable checkout")
    current
end

function search(config::SearchConfig)
    cfg=config_dict(config)
    extra=config.inputs
    workers,wall,seconds=config.workers,config.duration,config.slice
    workers<=Threads.nthreads() || error("configuration requests more workers than Julia threads; start Julia with --threads=$(workers)")
    resume=config.resume
    dir=config.output
    resume || !isdir(dir) || isempty(readdir(dir)) || error("new runs need an empty output directory")
    mkpath(dir)
    original=unique(extra)
    frozen=joinpath(dir,"inputs")
    if !resume
        mkpath(frozen)
        if isempty(original)
            catalog_seeds(joinpath(frozen,"1_catalog.tsv");corpora=config.corpora,parents=config.parents,seed=config.seed)
        end
        for (i,p) in enumerate(original)
            isfile(p) || error("missing input $p")
            cp(p,joinpath(frozen,string(i)*"_"*basename(p)))
        end
    end
    paths=sort!([joinpath(frozen,f) for f in readdir(frozen)];by=p->parse(Int,first(split(basename(p),'_'))))
    frozen_sources=resume ? get(TOML.parsefile(joinpath(dir,"manifest.toml"))["identity"]["reference"],"sources",nothing) : nothing
    reference=open_reference(config.reference;supplement_path=config.supplement,sources=frozen_sources)
    store=nothing
    try
    known,validation=validated_study(paths)
    semantic=Dict(k=>cfg[k] for k in ("method","limit","seed","target-b6","v5-bent","orbit-seconds","ea-representatives","corpus"))
    identity=Dict("configuration"=>semantic,"inputs"=>source_fingerprint(paths),"code"=>code_identity(),
        "reference"=>Dict(k=>v for (k,v) in reference_metadata(reference) if k in ("sha256","manifest_sha256","supplement_sha256","signatures","sources")),
        "reference_locations"=>Dict("baseline"=>config.reference,"supplement"=>config.supplement),
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
    # Only a verified resume owning the writer lease may clear a stop request.
    resume && isfile(joinpath(dir,"STOP")) && rm(joinpath(dir,"STOP"))
    # Archive the exact implementation, including uncommitted work, outside git.
    for (relative,digest) in identity["code"]
        destination=joinpath(dir,"source",relative)
        if !isfile(destination)
            mkpath(dirname(destination))
            temporary=destination*".tmp"
            cp(joinpath(ROOT,relative),temporary;force=true)
            filehash(temporary)==digest || error("implementation changed during source archive: $relative")
            mv(temporary,destination)
        end
        filehash(destination)==digest || error("source archive changed: $relative")
    end
        if isempty(query(store,"SELECT value FROM metadata WHERE key='plan_complete'"))
            transaction(store) do
            _,seeds=load_study(paths,max(1,cld(config.parents,length(paths))),Xoshiro(config.seed))
            gold=gold_apn(8).lut
            gp=properties(gold)
            isempty(original) && isempty(config.corpora) && pushfirst!(seeds,(gp["sigma_hash"],bytes2hex(gold)))
            unique!(seeds);resize!(seeds,min(length(seeds),config.parents))
            for (hash,payload) in seeds
                kind=config.method===:v5 ? "prepare_v5" : "switching"
                seed!(store,candidate_lut(payload),hash,kind)
            end
            if config.method===:switching && config.ea_representatives>0
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
            "gc_threads"=>Threads.ngcthreads(),"julia_threads"=>Threads.nthreads(),"reference"=>reference_metadata(reference)))
        println("Discovery session $session: $workers workers; $wall seconds; method $(cfg["method"]); $dir")
        flush(stdout)
        Threads.@threads :dynamic for worker in 1:workers
            localref=open_reference(config.reference;supplement_path=config.supplement,sources=get(reference.metadata,"sources",nothing))
            try
                geometry=config.method===:v5 ? Fourier.geometry(8) : nothing
                work=config.method===:v5 ? Fourier.V5Work(23) : nothing
                while remaining()>0 && !stop_wanted()
                    unit=claim!(store)
                    if unit===nothing
                        active=lock(store.guard) do
                            !isempty(query(store,"SELECT 1 FROM units WHERE status='running' LIMIT 1"))
                        end
                        active || break
                        sleep(0.01) # A preparing parent can still enqueue construction units.
                        continue
                    end
                    try
                        process_unit!(store,unit,config;reference=localref,geometry,work,known,remaining,stop_wanted)
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
        try
            store===nothing || close_store(store)
        finally
            close_reference(reference)
        end
    end
end
