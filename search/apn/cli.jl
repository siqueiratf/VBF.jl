"""Repository command for reproducible APN searches and their evidence.

The lightweight launcher parses options before starting Julia worker threads;
algorithms belong to VBF and data/catalog operations to VBFCatalog.
"""
module APNCommand
using TOML,Dates
const ROOT=normpath(joinpath(@__DIR__,"../.."))
const COMMANDS=("search","resume","status","stop","audit","report","validate","compare","classify","verify")
const SEARCH_FLAGS=Dict("threads"=>"workers","parents"=>"limit","duration"=>"wall-seconds",
    "method"=>"method","seed"=>"seed","reference"=>"baseline","supplement"=>"supplement",
    "slice"=>"seconds","evaluations"=>"evaluations","chunk-size"=>"chunk-x",
    "target-b6"=>"target-b6","bent"=>"v5-bent","ea-representatives"=>"ea-representatives",
    "orbit-duration"=>"orbit-seconds")

"""Convert a positive finite duration such as 30s, 15m or 8h to seconds."""
function duration(value)
    m=match(r"^([0-9]+(?:\.[0-9]+)?)([smh]?)$",value)
    m===nothing && error("invalid duration $value; use seconds, 15m or 8h")
    seconds=parse(Float64,m[1])*get(Dict(""=>1,"s"=>1,"m"=>60,"h"=>3600),m[2],1)
    seconds>0 && isfinite(seconds) || error("duration must be positive and finite")
    string(seconds)
end

"""Print the supported command surface without loading the computational packages."""
function help(io=stdout)
    print(io,"""
Usage: bin/vbf COMMAND [OPTIONS]

  search   --output DIR [--method v5|switching] [--duration 8h] [--threads 30]
           [--parents 1000] [--input CANDIDATES.tsv ...] [--reference DIR]
  resume   DIR [--duration 8h] [--threads 30]
  status   DIR
  stop     DIR
  audit    DIR [--limit N] [--reference DIR] [--supplement FILE]
  report   DIR [--output DIR]
  validate --input FILE [--input FILE ...] --output DIR [--reference DIR]
  compare  --candidate HEX --target HEX --output FILE [--relation ccz|ea]
           [--duration 30s] [--nodes 1000000]
  classify DIR [--duration 30s] [--nodes 1000000] [--pairs 100]
  verify   CERTIFICATE.toml

Search is currently restricted to quadratic (8,8)-APNs. Catalog seeds are the
default; --input selects explicit seeds and excludes their signatures from
additional-discovery counts. Searches freeze a finite parent plan, checkpoint
automatically and do not promote discoveries to parents within the same run.

Defaults: method v5, duration 8h, one worker. Optional search settings:
  --seed INTEGER --target-b6 52 --bent max --chunk-size 128
  --slice 60s --evaluations 10000 --ea-representatives 0 --orbit-duration 30s

Reference defaults to data/apn/reference and data/apn/supplement.tsv.
VBF_APN_REFERENCE and VBF_APN_SUPPLEMENT can override these paths.
Corpus absence is scoped evidence; literature-wide novelty remains unresolved.
""")
end

"""Parse options with explicit arity, rejecting unknown or repeated singleton flags."""
function options(args,allowed;multiple=String[])
    cfg=Dict{String,String}();repeated=Dict(k=>String[] for k in multiple);pos=String[];i=1
    while i<=length(args)
        token=args[i]
        if startswith(token,"--")
            key=token[3:end];key in allowed || error("unknown option $token")
            i<length(args) && !startswith(args[i+1],"--") || error("$token needs a value")
            if key in multiple
                push!(repeated[key],args[i+1])
            else
                haskey(cfg,key) && error("repeated option $token")
                cfg[key]=args[i+1]
            end
            i+=2
        else
            push!(pos,token);i+=1
        end
    end
    cfg,repeated,pos
end

"""Read a committed experiment manifest. Status is a database snapshot, not a writer action."""
function run_identity(dir)
    path=joinpath(dir,"manifest.toml")
    isfile(path) || error("not a search run: $dir")
    TOML.parsefile(path)["identity"]
end

"""Build engine arguments; resume recovers semantic parameters instead of asking for them again."""
function search_arguments(command,args)
    allowed=command=="search" ? [collect(keys(SEARCH_FLAGS));"output";"input"] :
        ["duration","threads","slice","evaluations","chunk-size"]
    cfg,repeated,pos=options(args,allowed;multiple=command=="search" ? ["input"] : String[])
    forwarded=String[]
    if command=="search"
        isempty(pos) || error("search uses --output DIR")
        haskey(cfg,"output") || error("search needs --output DIR")
        dir=abspath(pop!(cfg,"output"));isdir(dir) && !isempty(readdir(dir)) && error("output directory is not empty")
        get!(cfg,"method","v5")
        cfg["method"] in ("v5","switching") || error("method must be v5 or switching")
        for input in repeated["input"]
            isfile(input) || error("missing input: $input")
            append!(forwarded,["--input",abspath(input)])
        end
    else
        length(pos)==1 || error("resume needs RUN_DIRECTORY")
        dir=abspath(only(pos));identity=run_identity(dir)
        for (key,value) in identity["configuration"]
            append!(forwarded,["--"*key,string(value)])
        end
        # The manifest is committed before planning and the first session file.
        # Recover even if the first launch crashed during initialization.
        locations=identity["reference_locations"]
        append!(forwarded,["--baseline",locations["baseline"],"--supplement",locations["supplement"],"--resume","true"])
    end
    threads=tryparse(Int,get(cfg,"threads","1"))
    threads!==nothing && threads>0 || error("threads must be a positive integer")
    get!(cfg,"duration","8h")
    for (key,value) in cfg
        key=="threads" && continue
        name=SEARCH_FLAGS[key]
        if key in ("duration","slice","orbit-duration")
            value=duration(value)
        elseif key in ("threads","parents","evaluations","chunk-size","seed","target-b6","ea-representatives")
            parsed=tryparse(Int,value);parsed!==nothing || error("$key must be an integer")
            minimum=key in ("seed","target-b6","ea-representatives") ? 0 : 1
            parsed>=minimum || error("invalid $key")
        elseif key in ("reference","supplement")
            value=abspath(value)
        end
        append!(forwarded,["--"*name,value])
    end
    append!(forwarded,["--outdir",dir,"--workers",string(threads)])
    # No STOP mutation during parsing or a failed launch.
    threads,dir,forwarded
end

"""Launch one existing engine entry point in the root workspace with the requested workers."""
function execute_script(script,args;threads=1,env=Pair{String,String}[])
    julia=Base.julia_cmd()
    cmd=`$julia --startup-file=no --compiled-modules=no --project=$ROOT --threads=$threads $(joinpath(@__DIR__,script)) $args`
    run(addenv(cmd,env...))
end

"""Dispatch commands; a fresh worker process keeps separately runnable modules isolated."""
function main(args=ARGS)
    if isempty(args) || first(args) in ("help","--help","-h") || "--help" in args
        help();return
    end
    command=first(args);rest=args[2:end];command in COMMANDS || error("unknown command $command; see bin/vbf help")
    if command in ("search","resume")
        threads,dir,forwarded=search_arguments(command,rest)
        execute_script("run.jl",forwarded;threads)
    elseif command in ("status","stop")
        length(rest)==1 || error("$command needs RUN_DIRECTORY")
        dir=abspath(only(rest));run_identity(dir)
        if command=="stop"
            touch(joinpath(dir,"STOP"));println("Stop requested; workers will commit their current progress: $dir")
        else
            execute_script("status.jl",[dir])
        end
    elseif command=="verify"
        length(rest)==1 || error("verify needs CERTIFICATE.toml")
        execute_script("verify_certificate.jl",[abspath(only(rest))])
    elseif command=="report"
        cfg,_,pos=options(rest,["output"]);length(pos)==1 || error("report needs RUN_DIRECTORY")
        forwarded=[abspath(only(pos))];haskey(cfg,"output") && push!(forwarded,abspath(cfg["output"]))
        run(`python3 $(joinpath(@__DIR__,"report.py")) $forwarded`)
    elseif command=="audit"
        cfg,_,pos=options(rest,["limit","reference","supplement"]);length(pos)==1 || error("audit needs RUN_DIRECTORY")
        forwarded=[abspath(only(pos))];haskey(cfg,"limit") && append!(forwarded,["--limit",cfg["limit"]])
        env=Pair{String,String}[]
        haskey(cfg,"reference") && push!(env,"VBF_APN_REFERENCE"=>abspath(cfg["reference"]))
        haskey(cfg,"supplement") && push!(env,"VBF_APN_SUPPLEMENT"=>abspath(cfg["supplement"]))
        execute_script("audit.jl",forwarded;env)
    elseif command=="classify"
        cfg,_,pos=options(rest,["duration","nodes","pairs"]);length(pos)==1 || error("classify needs RUN_DIRECTORY")
        forwarded=[abspath(only(pos)),"--seconds",duration(get(cfg,"duration","30s")),"--nodes",get(cfg,"nodes","1000000"),"--max-pairs",get(cfg,"pairs","100")]
        execute_script("classify.jl",forwarded)
    elseif command=="validate"
        cfg,repeated,pos=options(rest,["input","output","reference","limit"];multiple=["input"])
        isempty(pos) && haskey(cfg,"output") && !isempty(repeated["input"]) || error("validate needs --input FILE --output DIR")
        forwarded=["--outdir",abspath(cfg["output"]),"--limit",get(cfg,"limit","0")]
        haskey(cfg,"reference") && append!(forwarded,["--baseline",abspath(cfg["reference"])])
        for input in repeated["input"];append!(forwarded,["--input",abspath(input)]);end
        execute_script("validate.jl",forwarded)
    else
        cfg,_,pos=options(rest,["candidate","target","output","relation","duration","nodes"])
        isempty(pos) && all(k->haskey(cfg,k),("candidate","target","output")) || error("compare needs --candidate HEX --target HEX --output FILE")
        forwarded=["--candidate",cfg["candidate"],"--target",cfg["target"],"--out",abspath(cfg["output"]),
            "--relation",get(cfg,"relation","ccz"),"--seconds",duration(get(cfg,"duration","30s")),"--nodes",get(cfg,"nodes","1000000")]
        execute_script("compare.jl",forwarded)
    end
end
end
if abspath(PROGRAM_FILE)==@__FILE__
    try
        APNCommand.main()
    catch e
        message=e isa Base.ProcessFailedException ? "worker process failed; see the error above" : sprint(showerror,e)
        println(stderr,"vbf: ",message);exit(1)
    end
end
