"""One-command front end for the existing audited recursive CPU search.

Only standard libraries load here. The supervised child loads the search engine
once, with its final thread pools, and initializes a fresh run before dispatch.
"""
module VBFSearchCommand
using TOML, Dates

const ROOT=normpath(joinpath(@__DIR__,"..","..",".."))
const VALUES=Dict("--start"=>"start","--end"=>"end","--time"=>"time",
    "--output"=>"output","--campaign"=>"campaign","--threads"=>"threads",
    "--heap-size-hint"=>"heap","--heap"=>"heap")

"""Describe seed numbering, limits, and the fresh-run command surface."""
function help(io=stdout)
    print(io,"""
Usage: vbfsearch --recursive-closure [OPTIONS]

  --start ID          First audited seed row (inclusive, one-based; default 1)
  --end ID            Last audited seed row (inclusive; default last seed)
  -j [N], --threads N Compute threads; bare -j or N=auto chooses automatically
                      Default: 1. Under Slurm, auto budgets GC/interactive CPUs.
  --time SECONDS      Wall-time budget, including worker startup and setup
                      Also accepts 30s, 15m, 8h. Default: until stopped.
  --output PATH       Final .sqlite file (default: data/search/vbfsearch-....sqlite)
                      A path without .sqlite/.sqlite3/.db retains directory output.
  --campaign FILE     Audited seed plan (default: installed literature b6=52 plan,
                      overridable with VBF_SEARCH_CAMPAIGN)
  --heap SIZE         Julia heap hint, e.g. 16G; defaults scale with thread count
  --dry-run           Print the resolved plan without creating files or searching
  -h, --help          Show this help

Example:
  bin/vbfsearch --recursive-closure -j 8 --start=1 --end=100 --time=1h --output=results.sqlite

The seed interval selects initial roots; all reached quadratic descendants remain
eligible. It does not limit recursion or guarantee disjoint descendant classes.
Ctrl-C, TERM and USR1 stop new work and drain dispatched packets. Draining can
extend --time; the shutdown grace is 600 seconds. Single-file output embeds the
configuration and provenance after a clean stop. Temporary work/journal files
exist while running; failed/interrupted packaging retains the working data.
Every invocation starts a fresh run; existing output is refused.
Dependencies and audited seed inputs must already be installed. No GPU is used.
""")
end

"""Parse flags without importing the search engine or touching the filesystem."""
function options(args)
    config=Dict{String,String}();flags=Set{String}();i=1
    function put!(key,value)
        haskey(config,key) && throw(ArgumentError("repeated option for $key"))
        isempty(value) && throw(ArgumentError("$key needs a value"))
        config[key]=value
    end
    while i<=length(args)
        token=args[i]
        if token in ("--help","-h")
            push!(flags,"help");i+=1;continue
        elseif token in ("--recursive-closure","--dry-run")
            token in flags && throw(ArgumentError("repeated option $token"))
            push!(flags,token);i+=1;continue
        elseif token=="-j"
            value="auto"
            if i<length(args) && !startswith(args[i+1],"-")
                i+=1;value=args[i]
            end
            put!("threads",value);i+=1;continue
        elseif startswith(token,"-j") && length(token)>2
            put!("threads",token[3:end]);i+=1;continue
        end
        parts=split(token,'=';limit=2);key=first(parts)
        haskey(VALUES,key) || throw(ArgumentError("unknown option $token; see vbfsearch --help"))
        if length(parts)==2
            value=last(parts)
        else
            i<length(args) && !startswith(args[i+1],"-") || throw(ArgumentError("$key needs a value"))
            i+=1;value=args[i]
        end
        put!(VALUES[key],String(value));i+=1
    end
    (;config,flags)
end

"""Require a positive integer with a user-facing flag name in errors."""
function positive(value,name)
    number=tryparse(Int,value)
    number!==nothing && number>0 || throw(ArgumentError("$name must be a positive integer"))
    number
end

"""Interpret a finite positive budget in seconds, minutes or hours."""
function seconds(value)
    found=match(r"^([0-9]+(?:\.[0-9]+)?)([smh]?)$",value)
    found===nothing && throw(ArgumentError("--time needs seconds, 30s, 15m or 8h"))
    result=parse(Float64,found[1])*get(Dict(""=>1,"s"=>1,"m"=>60,"h"=>3600),found[2],1)
    isfinite(result) && result>0 || throw(ArgumentError("--time must be positive and finite"))
    result
end

"""Respect a local CPU affinity mask when automatically choosing worker threads."""
function available_cpu_count(;status=Sys.islinux() && isfile("/proc/self/status") ? read("/proc/self/status",String) : "",fallback=Sys.CPU_THREADS)
    found=match(r"(?m)^Cpus_allowed_list:\s*([0-9,-]+)",status)
    found===nothing && return max(1,fallback)
    count=sum(split(found[1],',')) do span
        ends=parse.(Int,split(span,'-'))
        length(ends)==1 ? 1 : ends[2]-ends[1]+1
    end
    max(1,min(fallback,count))
end

"""Choose compute and auxiliary pools within an explicit Slurm allocation.

Local auto uses the available CPU count and the previously measured 8,1 GC
setting at 32 or more compute threads. Slurm additionally reserves auxiliary
pools, following the maintained controller's conservative resource validator.
"""
function threads(value;env=ENV,cpu_threads=available_cpu_count())
    allocation=haskey(env,"SLURM_CPUS_PER_TASK") ? positive(env["SLURM_CPUS_PER_TASK"],"SLURM_CPUS_PER_TASK") : 0
    auto=value=="auto"
    count=auto ? (allocation>0 ? allocation : cpu_threads) : positive(value,"--threads")
    allocation==0 && count>cpu_threads && throw(ArgumentError("--threads=$count exceeds the $cpu_threads available local CPUs"))
    mark=count>=32 ? 8 : count>=8 ? 2 : 1
    sweep=count>=32 ? 1 : 0
    interactive=count>1 ? 1 : 0
    if auto && allocation>0
        interactive=allocation>=4 ? 1 : 0
        count=allocation-mark-sweep-interactive
    elseif allocation>0 && count+mark+sweep+interactive>allocation
        mark=1;sweep=0;interactive=0
    end
    count>0 && (allocation==0 || count+mark+sweep+interactive<=allocation) ||
        throw(ArgumentError("thread pools exceed SLURM_CPUS_PER_TASK=$allocation; use bare -j for automatic budgeting (at least 2 allocated CPUs are required)"))
    (;compute=count,interactive,mark,sweep,allocation)
end

"""Find the installed audited campaign without rebuilding or selecting new seeds."""
function default_campaign(env=ENV)
    data=abspath(get(env,"VBF_SEARCH_DATA_DIR",joinpath(ROOT,"packages","VBFSearch","data")))
    abspath(get(env,"VBF_SEARCH_CAMPAIGN",joinpath(data,"search","literature-b52-closure-20261014","campaign.toml")))
end

"""Resolve a launch plan; dry runs stop here before any directory/database write."""
function plan(parsed;env=ENV,cpu_threads=available_cpu_count(),output_default=nothing)
    "--recursive-closure" in parsed.flags || throw(ArgumentError("select --recursive-closure; see vbfsearch --help"))
    cfg=parsed.config
    first_seed=positive(get(cfg,"start","1"),"--start")
    last_seed=haskey(cfg,"end") ? positive(cfg["end"],"--end") : nothing
    budget=haskey(cfg,"time") ? seconds(cfg["time"]) : nothing
    pools=threads(get(cfg,"threads","1");env,cpu_threads)
    heap=get(cfg,"heap",pools.compute==1 ? "512M" : pools.compute<16 ? "4G" : pools.compute<64 ? "16G" : "32G")
    occursin(r"^[1-9][0-9]*(?:[KMGTP]B?|B)?$",heap) || throw(ArgumentError("--heap needs positive bytes or a size such as 512M or 16G"))
    campaign=abspath(get(cfg,"campaign",default_campaign(env)))
    isfile(campaign) || throw(ArgumentError("audited seed plan is not installed at $campaign; use --campaign FILE or VBF_SEARCH_CAMPAIGN"))
    manifest=TOML.parsefile(campaign)
    startswith(get(manifest,"schema",""),"vbfsearch-literature-closure-plan-") || throw(ArgumentError("unsupported audited seed plan"))
    total=Int(manifest["roots"]["qualified_root_count"])
    last_seed===nothing && (last_seed=total)
    1<=first_seed<=last_seed<=total || throw(ArgumentError("seed interval must satisfy 1 <= start <= end <= $total"))
    roots=manifest["roots"];base=dirname(campaign)
    for name in ("qualified_root_file","equivalence_evidence","qualification_evidence")
        path=abspath(joinpath(base,roots[name]))
        isfile(path) || throw(ArgumentError("audited seed input is missing: $path"))
    end
    for path in (joinpath(dirname(joinpath(base,roots["qualified_root_file"])),"selected_roots.tsv"),
            joinpath(dirname(joinpath(base,roots["equivalence_evidence"])),"EA_certificates.tsv"))
        isfile(path) || throw(ArgumentError("audited seed input is missing: $path"))
    end
    data=abspath(get(env,"VBF_SEARCH_DATA_DIR",joinpath(ROOT,"packages","VBFSearch","data")))
    output_default===nothing && (output_default=joinpath(data,"search","vbfsearch-"*Dates.format(now(),"yyyymmdd-HHMMSS-sss")*"-"*string(getpid())*".sqlite"))
    output=abspath(get(cfg,"output",output_default))
    (ispath(output) || islink(output)) && throw(ArgumentError("output already exists: $output; choose a new --output path"))
    single=any(ext->endswith(lowercase(output),ext),(".sqlite",".sqlite3",".db"))
    workspace=single ? joinpath(dirname(output),"."*basename(output)*".work") : output
    single && (ispath(workspace) || islink(workspace)) && throw(ArgumentError("working data already exists at $workspace; choose a new output filename"))
    config=Dict{String,Any}("campaign"=>campaign,"output"=>output,
        "output_format"=>single ? "sqlite" : "directory","workspace"=>workspace,
        "root_first"=>first_seed,"root_last"=>last_seed,
        "run"=>joinpath(workspace,"state"),"evidence"=>joinpath(workspace,"session"),
        "julia_threads"=>string(pools.compute,",",pools.interactive),
        "julia_gc_threads"=>string(pools.mark,",",pools.sweep),"heap_size_hint"=>heap,
        "concurrency"=>pools.compute,"reservation_horizon"=>max(1024,4pools.compute),
        "reservation_refill_batch"=>16,"max_apply_per_step"=>32,"window_size"=>100,
        "parent_scope"=>"all","baseline_policy"=>"summary","indexed_ea_queue"=>true,
        "cached_global_counts"=>true,"shared_property_cache_entries"=>8192,
        "checkpoint_on_stop"=>false,"human_progress"=>true,"shutdown_grace_seconds"=>600.0)
    pools.allocation>0 && (config["cpu_allocation"]=pools.allocation)
    budget===nothing || (config["supervisor_duration_seconds"]=budget)
    (;config,pools,heap,total,budget)
end

"""Show the decisions that affect search scope, CPU use and output location."""
function describe(io,launch)
    cfg=launch.config;p=launch.pools
    println(io,"Search: recursive closure (V5 extensions + complete switching)")
    println(io,"Initial seeds: ",cfg["root_first"],"–",cfg["root_last"]," of ",launch.total," (inclusive audited rows)")
    println(io,"CPU pools: ",p.compute," compute, ",p.interactive," interactive, GC ",p.mark,",",p.sweep)
    println(io,"Heap hint: ",launch.heap)
    println(io,"Time: ",launch.budget===nothing ? "until stopped" : string(launch.budget," seconds including worker setup; then drain"))
    println(io,"Seed plan: ",cfg["campaign"])
    println(io,"Output: ",cfg["output"])
    cfg["output_format"]=="sqlite" && println(io,"Output format: one SQLite file with embedded provenance after clean shutdown")
end

"""Build the single search child with fixed pools and no implicit package install."""
function worker_command(launch,path;project=ROOT)
    p=launch.pools
    command=`$(Base.julia_cmd()) --startup-file=no --history-file=no --project=$project --threads=$(p.compute),$(p.interactive) --gcthreads=$(p.mark),$(p.sweep) --heap-size-hint=$(launch.heap) $(joinpath(@__DIR__,"vbfsearch_worker.jl")) $(abspath(path))`
    command
end

"""Replace the lightweight front end so signals reach the existing supervisor."""
function replace_process(command)
    Sys.isunix() || throw(ArgumentError("vbfsearch currently requires POSIX signal supervision"))
    arguments=command.exec
    pointers=Vector{Ptr{UInt8}}(undef,length(arguments)+1)
    GC.@preserve arguments pointers begin
        for i in eachindex(arguments)
            pointers[i]=pointer(arguments[i])
        end
        pointers[end]=C_NULL
        ccall(:execvp,Cint,(Cstring,Ptr{Ptr{UInt8}}),first(arguments),pointers)
    end
    throw(SystemError("execvp",Libc.errno()))
end

"""Launch a fresh supervised run, or report its plan without side effects."""
function main(args=ARGS;env=ENV,io=stdout,dispatch=replace_process)
    isempty(args) && (help(io);return 0)
    parsed=options(args)
    "help" in parsed.flags && (help(io);return 0)
    VERSION>=v"1.12" || throw(ArgumentError("Julia >= 1.12 is required"))
    launch=plan(parsed;env);describe(io,launch);flush(io)
    "--dry-run" in parsed.flags && return 0
    Sys.which("python3")===nothing && throw(ArgumentError("python3 is required for cooperative signal supervision"))
    workspace=launch.config["workspace"]
    mkpath(dirname(workspace));mkdir(workspace)
    path=joinpath(workspace,"command.toml")
    open(path,"w") do stream
        TOML.print(stream,launch.config;sorted=true)
    end
    if launch.config["output_format"]=="sqlite"
        archive=joinpath(workspace,"launcher");mkdir(archive)
        for source in (@__FILE__,joinpath(@__DIR__,"vbfsearch_worker.jl"),joinpath(@__DIR__,"vbfsearch_output.jl"),
                joinpath(@__DIR__,"closure_supervise.py"),joinpath(ROOT,"bin","vbfsearch"))
            cp(source,joinpath(archive,basename(source)))
        end
    end
    child=worker_command(launch,path)
    command=`python3 $(joinpath(@__DIR__,"closure_supervise.py")) --stop-file $(joinpath(launch.config["evidence"],"STOP")) --grace-seconds 600`
    launch.budget===nothing || (command=`$command --duration-seconds $(launch.budget)`)
    request=get(env,"VBF_SEARCH_STOP_FILE","")
    isempty(request) || (command=`$command --request-file $(abspath(request))`)
    command=`$command -- $child`
    withenv("OPENBLAS_NUM_THREADS"=>"1","OMP_NUM_THREADS"=>"1","MKL_NUM_THREADS"=>"1","JULIA_NUM_PRECOMPILE_TASKS"=>"1") do
        dispatch(command)
    end
    0
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    try
        exit(VBFSearchCommand.main())
    catch error
        error isa ArgumentError || rethrow()
        println(stderr,"vbfsearch: ",error.msg)
        exit(2)
    end
end
