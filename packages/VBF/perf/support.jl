"""Development tooling: BenchmarkTools groups, reproducible setup and file outputs.

Included by package-local perf runners; never loaded by any runtime package.
"""
module PerfSupport
using BenchmarkTools, Random, SHA, Dates, TOML, Statistics, Printf
export suite, benchmark!, register_suites!, main, run_suite, source_manifest, selected_keys
const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const DEFAULT_SEED = 1592594996
suite() = (benchmarks=BenchmarkGroup(), metadata=Dict{Tuple{String,String,Int},NamedTuple}())

function benchmark!(reg; group, name, n=0, cost=1, setup=()->nothing, call,
              samples=0, note="", approach=group, parameters=(;), paper_id="", mode="",
              validate=(payload,value)->nothing, validation="separate execution completed; optional workload assertions", teardown=payload->nothing, seed=DEFAULT_SEED, input_files=String[])
    1 <= cost <= 3 || throw(ArgumentError("cost must be in 1:3"))
    samples >= 0 || throw(ArgumentError("samples must be nonnegative"))
    key=(String(group),String(name),Int(n))
    haskey(reg.metadata,key) && error("duplicate workload $key")
    # Reset random state and allocate mutable payload once per sample, outside timing.
    # evals=1 is deliberately fixed: mutations/searches must not reuse payloads.
    prepare = () -> (Random.seed!(seed); setup())
    haskey(reg.benchmarks,group) || (reg.benchmarks[group]=BenchmarkGroup())
    reg.benchmarks[group][(String(name),Int(n))] =
        @benchmarkable $call(payload) setup=(payload=$prepare()) teardown=($teardown(payload)) evals=1
    reg.metadata[key] = (; cost=Int(cost), samples=Int(samples), note=String(note),
        approach=String(approach), parameters, paper_id=String(paper_id), mode=String(mode),
        seed=Int(seed), validation=String(validation), input_files=String.(input_files), prepare, call, validate, teardown)
    reg
end

function register_suites!(reg, directory, owner::Module)
    for path in sort(readdir(directory;join=true))
        endswith(path,".jl") || continue
        Base.include(owner,path)
        Base.invokelatest(Base.invokelatest(getfield,owner,:register!),reg)
    end
    reg
end

function selected_keys(reg; level=1, group=nothing, workload=nothing, n=nothing,
                       paper=nothing, mode=nothing)
    sort!([key for (key,m) in reg.metadata if m.cost<=level &&
        (group===nothing || key[1]==group) && (workload===nothing || key[2]==workload) &&
        (n===nothing || key[3]==0 || key[3]==n) &&
        (paper===nothing || m.paper_id==paper) && (mode===nothing || m.mode==mode)])
end

function source_manifest(package; config=Dict(), paper_ids=String[], input_files=String[])
    paths=String[]
    for folder in (joinpath(ROOT,"packages"),)
        for (base,dirs,files) in walkdir(folder)
            filter!(d->!(d in ("VBFWorkingPaper","results","input","inputs","tuples",".git","corpora","node_modules","historical")),dirs)
            for f in files
                (endswith(f,".jl") || endswith(f,".toml") || f in ("Makefile","paper.mk")) && push!(paths,joinpath(base,f))
            end
        end
    end
    # Bind the actual stored inputs of selected paper workloads without copying them.
    papers=joinpath(ROOT,"packages","VBFRepro","src")
    if package=="VBFRepro" && isdir(papers)
        for (base,dirs,_) in walkdir(papers)
            filter!(d->!(d in ("results",".git","node_modules")),dirs)
            basename(base) in paper_ids || continue
            for (folder,subdirs,files) in walkdir(base)
                filter!(d->!(d in ("results",".git","node_modules")),subdirs)
                append!(paths,[joinpath(folder,f) for f in files])
            end
            empty!(dirs)
        end
    end
    unique!(paths)
    for f in ("Project.toml","Manifest.toml")
        p=joinpath(ROOT,f);isfile(p) && push!(paths,p)
    end
    hashes=Dict(relpath(p,ROOT)=>bytes2hex(sha256(read(p))) for p in sort(paths))
    tree=bytes2hex(sha256(join(k*"\t"*hashes[k]*"\n" for k in sort(collect(keys(hashes))))))
    revision=try chomp(read(`git -C $ROOT rev-parse HEAD`,String)) catch; "unavailable" end
    dirty=try !isempty(read(`git -C $ROOT status --porcelain`,String)) catch; true end
    manifest = Dict("schema_version"=>1, "measurement_protocol"=>"BenchmarkTools trial summary v1",
        "package"=>package, "created_utc"=>string(now(UTC)), "config"=>config,
        "provenance"=>Dict("source_tree_sha256"=>tree,"source_files"=>hashes,
            "git_commit"=>revision,"git_dirty"=>dirty,"julia_version"=>string(VERSION),
            "julia_threads"=>Threads.nthreads(),"cpu"=>Sys.cpu_info()[1].model,
            "cpu_threads"=>Sys.CPU_THREADS,"total_memory_bytes"=>Sys.total_memory(),
            "os"=>string(Sys.KERNEL),"benchmarktools_version"=>string(pkgversion(BenchmarkTools))))
    if package != "VBF"
        catalog=get(ENV,"BFA_CATALOG_PATH",joinpath(ROOT,"packages","VBFCatalog","BFA_catalog.sqlite"))
        isfile(catalog) && (manifest["inputs"]=Dict("catalog_path"=>abspath(catalog),
            "catalog_sha256"=>bytes2hex(open(sha256,catalog))))
    end
    if !isempty(input_files)
        inputs=get!(manifest,"inputs",Dict{String,Any}())
        inputs["workload_files"]=Dict(abspath(p)=>bytes2hex(open(sha256,p)) for p in unique(input_files))
    end
    manifest
end

clean(value) = replace(string(value), '\t'=>' ', '\n'=>' ', '\r'=>' ')
function run_suite(reg, package; out=nothing, seconds=1.0, samples=nothing,
                   level=1, group=nothing, workload=nothing, n=nothing, paper=nothing, mode=nothing)
    isfinite(seconds) && seconds>0 || throw(ArgumentError("seconds must be finite and positive"))
    samples===nothing || samples>0 || throw(ArgumentError("samples must be positive"))
    keys=selected_keys(reg;level,group,workload,n,paper,mode)
    isempty(keys) && throw(ArgumentError("no workloads match filters"))
    out===nothing && (out=joinpath(ROOT,"data","perf",package,Dates.format(now(UTC),"yyyymmddTHHMMSS")*"_"*string(getpid())))
    ispath(out) && throw(ArgumentError("output path already exists: $out"))
    mkpath(out)
    config=Dict{String,Any}("seconds"=>seconds,"samples"=>samples===nothing ? "per-workload defaults" : samples,"evals"=>1,
        "level"=>level,"seed"=>DEFAULT_SEED,"setup"=>"fresh payload and reset RNG per sample")
    for (key,value) in (("group",group),("workload",workload),("n",n),("paper",paper),("mode",mode))
        value===nothing || (config[key]=value)
    end
    manifest=source_manifest(package;config,paper_ids=unique([reg.metadata[k].paper_id for k in keys]),
        input_files=vcat([reg.metadata[k].input_files for k in keys]...))
    manifest["workloads"]=[Dict("group"=>k[1],"workload"=>k[2],"n"=>k[3],
        "seed"=>reg.metadata[k].seed,"note"=>reg.metadata[k].note,
        "validation"=>reg.metadata[k].validation,"evals"=>1,
        "sample_limit"=>samples===nothing ? (reg.metadata[k].samples>0 ? reg.metadata[k].samples : 100) : samples,
        "parameters"=>Dict(string(a)=>v for (a,v) in pairs(reg.metadata[k].parameters))) for k in keys]
    open(joinpath(out,"manifest.toml"),"w") do io; TOML.print(io,manifest); end
    env=dirname(Base.active_project())
    for name in ("Project.toml","Manifest.toml")
        p=joinpath(env,name);isfile(p) && cp(p,joinpath(out,name))
    end
    results=BenchmarkGroup()
    open(joinpath(out,"timings.tsv"),"w") do io
        println(io,"package\tgroup\tworkload\tcase\tn\tpaper_id\tapproach\tmode\tstatus\tsamples\ttime_ns_min\ttime_ns_median\ttime_ns_mean\tmemory_bytes\tallocations\tgctime_ns")
        for key in keys
            g,name,dim=key; m=reg.metadata[key]
            # Validate a separate execution. Validation and reporting are never timed.
            payload=m.prepare()
            try
                value=Base.invokelatest(m.call,payload)
                Base.invokelatest(m.validate,payload,value)
            finally
                m.teardown(payload)
            end
            benchmark=reg.benchmarks[g][(name,dim)]
            trial=BenchmarkTools.run(benchmark;seconds,samples=samples===nothing ? (m.samples>0 ? m.samples : 100) : samples,evals=1)
            haskey(results,g) || (results[g]=BenchmarkGroup());results[g][(name,dim)]=trial
            lo=minimum(trial);mid=median(trial);avg=mean(trial)
            case=dim==0 ? name : name*"_n"*string(dim)
            println(io,join(clean.((package,g,name,case,dim,m.paper_id,m.approach,m.mode,"ok",
                length(trial),lo.time,mid.time,avg.time,lo.memory,lo.allocs,mid.gctime)), '\t'))
            flush(io)
            BenchmarkTools.save(joinpath(out,"benchmarktools.json"),results)
            @printf("%s/%s n=%d: median %.3g ns (%d samples)\n",g,name,dim,mid.time,length(trial))
        end
    end
    println("saved ",out)
    (;out,results,manifest)
end

function main(reg, package, args=ARGS)
    opts=Dict{Symbol,Any}(:seconds=>1.0,:level=>1)
    listing=false
    for a in args
        if a=="--list";listing=true;continue;end
        if a in ("--help","-h")
            println("run.jl [--list] [--level=1|2|3] [--group=G] [--workload=NAME] [--n=N] [--paper=ID] [--mode=MODE] [--seconds=1] [--samples=100] [--out=PATH]")
            return nothing
        end
        startswith(a,"--") && occursin('=',a) || error("unknown argument $a")
        key,value=split(a[3:end],'=';limit=2);symbol=Symbol(key)
        symbol in (:seconds,:samples,:level,:group,:workload,:n,:paper,:mode,:out) || error("unknown option $key")
        opts[symbol]=symbol==:seconds ? parse(Float64,value) : symbol in (:samples,:level,:n) ? parse(Int,value) : value
    end
    1<=opts[:level]<=3 || error("level must be 1,2,3")
    if listing
        filters=(; (k=>v for (k,v) in opts if k in (:level,:group,:workload,:n,:paper,:mode))...)
        for key in selected_keys(reg;filters...)
            m=reg.metadata[key];println(join((key...,m.cost,m.paper_id,m.mode,m.note),'\t'))
        end
        return nothing
    end
    run_suite(reg,package;opts...)
end
end
