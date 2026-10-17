"""Command-line adapter for the public VBFSearch application API."""
module CLI
using TOML
import ..VBFSearch
const ROOT=VBFSearch.ROOT
const COMMANDS=("search","discover","publish","resume","status","stop","audit","report","validate","compare","classify","verify","closure")
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

"""Print the supported command surface."""
function help(io=stdout)
    print(io,"""
Usage: bin/vbf COMMAND [OPTIONS]

  search   --output DIR [--method v5|switching] [--duration 8h] [--threads 30]
           [--parents 1000] [--input CANDIDATES.tsv ... | --corpus NAME ...] [--reference DIR]
  discover --name SLUG [search options]  (search, then register new catalog classes)
  publish  DIR --name SLUG              (register verified separating signatures)
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
  closure  init CAMPAIGN.toml --output DIR
           [--root-first 1] [--root-last 0] [--root-order forward|reverse]
           [--extension-cosets 1] [--switching-directions 1]
  closure  upgrade SOURCE --output DIR [--switching-directions 32]
  closure  run|resume DIR [--duration 60s] [--evaluations 1000] [--jobs 16]
           [--parents 0] [--equivalence-duration 2s] [--equivalence-nodes 100000]
  closure  status|stop DIR

Search is currently restricted to quadratic (8,8)-APNs. Catalog seeds are the
default; --corpus samples named bulk corpora deterministically with --seed.
--input selects explicit seeds and excludes their signatures from
additional-discovery counts. Searches freeze a finite parent plan, checkpoint
automatically and do not promote discoveries to parents within the same run.
The separate closure controller recursively promotes verified quadratic EA
classes and interleaves complete switching with exact target-52 extensions.
The run/resume adapter uses one worker.
An extension coset is indivisible and can overrun a budget.
Closure root intervals are inclusive one-based rows of the fully audited file;
root-last 0 includes its final row. Descendants have no partition/profile filter.

Defaults: method v5, duration 8h, one worker. Optional search settings:
  --seed INTEGER --target-b6 52 --bent max --chunk-size 128
  --slice 60s --evaluations 10000 --ea-representatives 0 --orbit-duration 30s

Reference defaults to VBFCatalog's own signature index. Discover writes under
packages/VBFSearch/data/search/SLUG. Published corpora remain reference-scoped;
matching signatures are not promoted as new classes.
VBF_APN_REFERENCE and VBF_APN_SUPPLEMENT can override these paths.
Corpus absence is scoped evidence; literature-wide novelty remains unresolved.
""")
end

function closure_command(args)
    isempty(args) && error("closure needs init, upgrade, run, resume, status or stop")
    action=first(args);rest=args[2:end]
    if action=="init"
        cfg,_,pos=options(rest,["output","root-first","root-last","root-order","extension-cosets","switching-directions"])
        length(pos)==1 && haskey(cfg,"output") || error("closure init needs CAMPAIGN.toml --output DIR")
        println(VBFSearch.closure_init(only(pos);output=cfg["output"],
            root_first=parse(Int,get(cfg,"root-first","1")),root_last=parse(Int,get(cfg,"root-last","0")),
            root_order=Symbol(get(cfg,"root-order","forward")),
            extension_cosets=parse(Int,get(cfg,"extension-cosets","1")),
            switching_directions=parse(Int,get(cfg,"switching-directions","1"))))
    elseif action=="upgrade"
        cfg,_,pos=options(rest,["output","switching-directions"])
        length(pos)==1 && haskey(cfg,"output") || error("closure upgrade needs SOURCE --output DIR")
        println(VBFSearch.closure_upgrade(only(pos);output=cfg["output"],
            switching_directions=parse(Int,get(cfg,"switching-directions","32"))))
    elseif action in ("run","resume")
        cfg,_,pos=options(rest,["duration","evaluations","jobs","parents","equivalence-duration","equivalence-nodes"])
        length(pos)==1 || error("closure $action needs RUN_DIRECTORY")
        println(VBFSearch.closure_run!(only(pos);
            duration_seconds=parse(Float64,duration(get(cfg,"duration","60s"))),
            max_evaluations=parse(Int,get(cfg,"evaluations","1000")),max_jobs=parse(Int,get(cfg,"jobs","16")),
            max_parents=parse(Int,get(cfg,"parents","0")),
            equivalence_seconds=parse(Float64,duration(get(cfg,"equivalence-duration","2s"))),
            equivalence_nodes=parse(Int,get(cfg,"equivalence-nodes","100000"))))
    elseif action in ("status","stop")
        length(rest)==1 || error("closure $action needs RUN_DIRECTORY")
        action=="status" ? println(VBFSearch.closure_snapshot(only(rest))) : VBFSearch.closure_stop!(only(rest))
    else
        error("unknown closure action $action")
    end
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

"""Parse CLI options into the same typed configuration used by Julia callers."""
function search_configuration(command,args)
    allowed=command=="search" ? [collect(keys(SEARCH_FLAGS));"output";"input";"corpus"] :
        ["duration","threads","slice","evaluations","chunk-size"]
    cfg,repeated,pos=options(args,allowed;multiple=command=="search" ? ["input","corpus"] : String[])
    runtime=Dict("duration"=>duration(get(cfg,"duration","8h")),"threads"=>get(cfg,"threads","1"))
    if command=="search"
        isempty(pos) && haskey(cfg,"output") || error("search needs --output DIR")
        dir=abspath(pop!(cfg,"output"))
        isdir(dir) && !isempty(readdir(dir)) && error("output directory is not empty")
        d=VBFSearch.config_dict(VBFSearch.SearchConfig(output=dir))
        d["input"]=abspath.(repeated["input"])
        d["corpus"]=repeated["corpus"]
        all(isfile,d["input"]) || error("missing input file")
    else
        length(pos)==1 || error("resume needs RUN_DIRECTORY")
        dir=abspath(only(pos))
        d=VBFSearch.config_dict(VBFSearch.resume_config(dir))
    end
    for (key,value) in cfg
        name=SEARCH_FLAGS[key]
        d[name]=key in ("duration","slice","orbit-duration") ? duration(value) : value
    end
    d["wall-seconds"]=runtime["duration"];d["workers"]=runtime["threads"]
    VBFSearch.config_from_dict(d)
end

"""Start Julia with the requested threads; pass data, never interpolated Julia code."""
function launch(config)
    mktemp() do path,io
        TOML.print(io,VBFSearch.config_dict(config));close(io)
        julia=Base.julia_cmd()
        program="using VBFSearch,TOML; VBFSearch.search(VBFSearch.config_from_dict(TOML.parsefile(only(ARGS))))"
        run(`$julia --startup-file=no --project=$ROOT --threads=$(config.workers) -e $program -- $path`)
    end
end

function main(args=ARGS)
    if isempty(args) || first(args) in ("help","--help","-h") || "--help" in args
        help();return
    end
    command=first(args);rest=args[2:end]
    command in COMMANDS || error("unknown command $command; see bin/vbf help")
    if command=="closure"
        closure_command(rest)
    elseif command=="discover"
        cfg,repeated,pos=options(rest,[collect(keys(SEARCH_FLAGS));"name";"input";"corpus";"output"];multiple=["input","corpus"])
        isempty(pos) && haskey(cfg,"name") || error("discover needs --name SLUG")
        name=pop!(cfg,"name")
        occursin(r"^[a-z][a-z0-9_-]*$",name) || error("use a lowercase corpus slug")
        get!(cfg,"output",joinpath(VBFSearch.search_data_dir(),"search",name))
        forwarded=String[]
        for (k,v) in cfg;append!(forwarded,["--"*k,v]);end
        for path in repeated["input"];append!(forwarded,["--input",path]);end
        for corpus in repeated["corpus"];append!(forwarded,["--corpus",corpus]);end
        config=search_configuration("search",forwarded)
        launch(config)
        println(VBFSearch.publish(config.output;name))
    elseif command=="publish"
        cfg,_,pos=options(rest,["name"])
        length(pos)==1 && haskey(cfg,"name") || error("publish needs RUN_DIRECTORY --name SLUG")
        println(VBFSearch.publish(only(pos);name=cfg["name"]))
    elseif command in ("search","resume")
        launch(search_configuration(command,rest))
    elseif command in ("status","stop","verify")
        length(rest)==1 || error("$command needs one path")
        dir=abspath(only(rest))
        command=="status" ? VBFSearch.status(dir) : command=="verify" ? VBFSearch.verify_certificate(dir) : VBFSearch.stop!(dir)
    elseif command=="report"
        cfg,_,pos=options(rest,["output"]);length(pos)==1 || error("report needs RUN_DIRECTORY")
        VBFSearch.report(abspath(only(pos));output=get(cfg,"output",joinpath(only(pos),"publication")))
    elseif command=="audit"
        cfg,_,pos=options(rest,["limit","reference","supplement"]);length(pos)==1 || error("audit needs RUN_DIRECTORY")
        VBFSearch.audit(abspath(only(pos));reference=get(cfg,"reference",get(ENV,"VBF_APN_REFERENCE",VBFSearch.DEFAULT_REFERENCE)),
            supplement=get(cfg,"supplement",get(ENV,"VBF_APN_SUPPLEMENT",VBFSearch.DEFAULT_SUPPLEMENT)),limit=parse(Int,get(cfg,"limit","0")))
    elseif command=="classify"
        cfg,_,pos=options(rest,["duration","nodes","pairs"]);length(pos)==1 || error("classify needs RUN_DIRECTORY")
        result=VBFSearch.classify_snapshot(abspath(only(pos));seconds=parse(Float64,duration(get(cfg,"duration","30s"))),
            nodes=parse(Int,get(cfg,"nodes","1000000")),max_pairs=parse(Int,get(cfg,"pairs","100")))
        println(result)
    elseif command=="validate"
        cfg,repeated,pos=options(rest,["input","output","reference","supplement","limit"];multiple=["input"])
        isempty(pos) && haskey(cfg,"output") && !isempty(repeated["input"]) || error("validate needs --input FILE --output DIR")
        println(VBFSearch.validate(repeated["input"];output=cfg["output"],
            reference=get(cfg,"reference",get(ENV,"VBF_APN_REFERENCE",VBFSearch.DEFAULT_REFERENCE)),supplement=get(cfg,"supplement",get(ENV,"VBF_APN_SUPPLEMENT",VBFSearch.DEFAULT_SUPPLEMENT)),
            limit=parse(Int,get(cfg,"limit","0"))))
    else
        cfg,_,pos=options(rest,["candidate","target","output","relation","duration","nodes"])
        isempty(pos) && all(k->haskey(cfg,k),("candidate","target","output")) || error("compare needs --candidate HEX --target HEX --output FILE")
        proof=VBFSearch.compare(VBFSearch.candidate_lut(cfg["candidate"]),VBFSearch.candidate_lut(cfg["target"]);
            relation=Symbol(get(cfg,"relation","ccz")),timeout_seconds=parse(Float64,duration(get(cfg,"duration","30s"))),
            max_nodes=parse(Int,get(cfg,"nodes","1000000")))
        mkpath(dirname(abspath(cfg["output"])))
        VBFSearch.atomic_toml(cfg["output"],proof)
        println(proof["status"])
    end
end
end
