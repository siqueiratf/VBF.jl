"""Scheduler-independent entry point for the frozen threaded closure controller.

The Python supervisor owns signal handling; Julia owns resource validation and
the ordinary witness-verifying controller. No scheduler or service manager is
required. Paths in CONFIG.toml resolve relative to that file.
"""
module ClosureLauncher
using TOML
include("closure_operations.jl")
using .ClosureOperations: validate_resources

"""Read operational configuration without depending on the caller's directory."""
function read_config(path;env=ENV)
    source=abspath(path);config=TOML.parsefile(source);base=dirname(source)
    for key in ("run","evidence")
        haskey(config,key) && config[key] isa AbstractString || throw(ArgumentError("$key path is required"))
    end
    for key in ("run","evidence","timing_history","seed_progress_helper","controller_path",
            "checkpoint_directory","checkpoint_active_project","evidence_segment_directory","quota_status_file")
        haskey(config,key) || continue
        config[key] isa AbstractString || throw(ArgumentError("$key must be a path"))
        isempty(config[key]) || (config[key]=abspath(joinpath(base,config[key])))
    end
    for key in ("stop_files","storage_paths")
        haskey(config,key) || continue
        values=config[key]
        values isa AbstractVector && all(x->x isa AbstractString,values) || throw(ArgumentError("$key must contain paths"))
        config[key]=[abspath(joinpath(base,x)) for x in values]
    end
    if haskey(env,"VBF_CLOSURE_STOP_FILE")
        stop=String(env["VBF_CLOSURE_STOP_FILE"])
        isempty(stop) || push!(get!(config,"stop_files",String[]),abspath(stop))
    end
    config
end

"""Validate actual thread pools before loading or dispatching controller work."""
function run(path;controller_path=nothing,env=ENV)
    config=read_config(path;env)
    resources=validate_resources(config;env)
    config["concurrency"]=resources["concurrency"]
    controller=controller_path===nothing ? String(get(config,"controller_path",joinpath(@__DIR__,"closure_continuous.jl"))) : abspath(controller_path)
    isfile(controller) || throw(ArgumentError("controller does not exist: $controller"))
    owner=Module(gensym(:ClosureController))
    Base.include(owner,controller)
    Base.invokelatest() do
        isdefined(owner,:ContinuousSeedSearch) || error("controller must define ContinuousSeedSearch.run(config)")
        getfield(getfield(owner,:ContinuousSeedSearch),:run)(config)
    end
end

"""Build a child invocation retaining this Julia binary, project and thread pools."""
function worker_command(path;controller_path=nothing)
    project=Base.active_project()
    project===nothing && error("a pinned Julia project is required")
    options=Base.JLOptions()
    sweep=max(0,Int(options.nsweepthreads));mark=max(1,Threads.ngcthreads()-sweep)
    pools=string(Threads.nthreads(:default),",",Threads.nthreads(:interactive))
    command=`$(Base.julia_cmd()) --startup-file=no --history-file=no --compiled-modules=existing --project=$(dirname(project)) --threads=$pools --gcthreads=$mark,$sweep`
    if options.heap_size_hint>0
        command=`$command --heap-size-hint=$(options.heap_size_hint)B`
    end
    command=`$command $(@__FILE__) --worker $(abspath(path))`
    controller_path===nothing ? command : `$command $(abspath(controller_path))`
end

"""Replace this process with the signal supervisor without opening the database.

`shutdown_grace_seconds` bounds cooperative drain. `supervisor_duration_seconds`
optionally requests STOP after a wall-clock interval including child startup.
The controller's own `duration_seconds` retains its established semantics.
`replace_process=false` waits and returns the child status for embedding; direct
PID-targeted signals require the default process replacement.
"""
function supervise(path;controller_path=nothing,python="python3",supervisor_path=joinpath(@__DIR__,"closure_supervise.py"),replace_process=true)
    config=read_config(path)
    validate_resources(config)
    grace=Float64(get(config,"shutdown_grace_seconds",600.0))
    isfinite(grace) && grace>0 || throw(ArgumentError("shutdown_grace_seconds must be positive and finite"))
    command=`$python $supervisor_path --stop-file $(joinpath(config["evidence"],"STOP")) --grace-seconds $grace`
    if haskey(config,"supervisor_duration_seconds")
        duration=Float64(config["supervisor_duration_seconds"])
        isfinite(duration) && duration>=0 || throw(ArgumentError("supervisor_duration_seconds must be nonnegative and finite"))
        command=`$command --duration-seconds $duration`
    end
    child=worker_command(path;controller_path)
    command=`$command -- $child`
    if replace_process
        Sys.isunix() || throw(ArgumentError("signal supervision requires POSIX process replacement"))
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
    process=Base.run(ignorestatus(command))
    process.exitcode
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    if length(ARGS) in (2,3) && first(ARGS)=="--worker"
        result=ClosureLauncher.run(ARGS[2];controller_path=length(ARGS)==3 ? ARGS[3] : nothing)
        println(ClosureLauncher.ClosureOperations.FP.JSON3.write(result))
    elseif length(ARGS)==1
        exit(ClosureLauncher.supervise(only(ARGS)))
    else
        error("usage: closure_run.jl CONFIG.toml")
    end
end
