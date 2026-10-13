module PerfProfiles
using Profile, Serialization, Dates, TOML
using ..PerfSupport
export profile_main
function profile_main(reg,package,args=ARGS)
    filters=Dict{Symbol,Any}(:level=>3)
    delay=0.001;out=nothing
    for arg in args
        if arg in ("-h","--help")
            println("profile.jl --group=GROUP --workload=NAME [--n=N] [--out=PATH] [--delay=0.001]")
            return
        end
        key,value=split(arg[3:end],'=';limit=2)
        if key=="out";out=value
        elseif key=="delay";delay=parse(Float64,value)
        elseif Symbol(key) in (:group,:workload,:n,:paper,:mode)
            filters[Symbol(key)]=key=="n" ? parse(Int,value) : value
        else;error("unknown profile option $key")
        end
    end
    keys=selected_keys(reg;filters...)
    length(keys)==1 || error("select exactly one workload; selected $(length(keys))")
    isfinite(delay)&&delay>0 || error("profile sampling delay must be positive")
    key=only(keys);g,name,n=key;m=reg.metadata[key]
    p=m.prepare()
    try
        value=Base.invokelatest(m.call,p);Base.invokelatest(m.validate,p,value)
    finally;m.teardown(p);end
    Profile.init(n=20_000_000,delay=delay);Profile.clear()
    p=m.prepare()
    start=time()
    try
        # Duration is profiler metadata, never a benchmark measurement.
        Profile.@profile value=Base.invokelatest(m.call,p)
        Base.invokelatest(m.validate,p,value)
    finally;m.teardown(p);end
    seconds=time()-start
    data,lidict=Profile.retrieve()
    out===nothing && (out=joinpath(PerfSupport.ROOT,"packages","VBFPaper","bench","data",package,"profiles",
        Dates.format(now(UTC),"yyyymmddTHHMMSS")*"_"*string(getpid())))
    ispath(out) && error("profile output already exists: $out")
    mkpath(out)
    manifest=source_manifest(package;paper_ids=[m.paper_id],input_files=m.input_files,config=Dict(
        "seed"=>m.seed,"sampling_delay"=>delay,"group"=>g,"workload"=>name,
        "n"=>n,"paper_id"=>m.paper_id,"mode"=>m.mode,"parameters"=>Dict(string(k)=>v for (k,v) in pairs(m.parameters))))
    manifest["measurement_protocol"]="Julia sampling profile v1"
    open(io->TOML.print(io,manifest),joinpath(out,"manifest.toml"),"w")
    provenance=manifest["provenance"]
    serialize(joinpath(out,"profile_raw.jls"),(;data,lidict,
        case=(;group=g,name,n,paper_id=m.paper_id,mode=m.mode,note=m.note,
            approach=m.approach,parameters=m.parameters),
        seed=string(m.seed),sampling_delay=delay,
        provenance=(;source_tree_sha256=provenance["source_tree_sha256"],
            cpu=provenance["cpu"],julia_threads=provenance["julia_threads"]),
        warm_seconds=NaN,profiled_seconds=seconds,julia_version=string(VERSION),
        recorded_at=string(now(UTC))))
    println("saved raw profile ",out," (",length(data)," frames); use the shared perf analysis reader for attribution")
    out
end
end
