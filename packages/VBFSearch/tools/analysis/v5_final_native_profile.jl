"""Bounded profile of the current native DU7 V5 path on frozen holdout jobs."""
module V5FinalNativeProfile
using VBF,JSON3,SHA,Profile,Dates
const Q=VBF.QuadraticExtensions
sha(path)=bytes2hex(open(SHA.sha256,path))
function run(input,output;job_limit=4,repetitions=2)
    mkpath(output);source=JSON3.read(read(input,String),Dict{String,Any})
    jobs=source["records"][1:min(job_limit,length(source["records"]))]
    files=[joinpath(dirname(pathof(VBF)),"constructions",name) for name in
        ("quadratic_extensions.jl","quadratic_extension_du7.jl","quadratic_rank_table.jl",
         "quadratic_extension_histograms.jl")]
    hashes=Dict(path=>sha(path) for path in files)
    G=Q.geometry(8);start=time();table=Q.PolarRankTable(G);build=time()-start
    work=Q.V5Work(23);results=Dict{String,Any}[]
    first_job=first(jobs)
    Q.v5_extensions(G,UInt32.(first_job["forms"]),Int(first_job["need"]),work;
        beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_x=8,max_kernel=23)
    Profile.init(n=5_000_000,delay=0.0005);Profile.clear();started=time()
    Profile.@profile for repetition in 1:repetitions,job in jobs
        trial=@timed Q.v5_extensions(G,UInt32.(job["forms"]),Int(job["need"]),work;
            beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23)
        result=trial.value
        length(result.Ss)==job["output_count"] && result.nX==job["cosets"] || error("holdout result changed")
        push!(results,Dict("parent_id"=>job["parent_id"],"repetition"=>repetition,
            "seconds"=>trial.time,"bytes"=>trial.bytes,"gc_seconds"=>trial.gctime,
            "nX"=>result.nX,"outputs"=>length(result.Ss),"candidates"=>result.ncand))
    end
    elapsed=time()-started
    open(joinpath(output,"profile-flat.txt"),"w") do io
        Profile.print(io;format=:flat,sortedby=:count,C=false,mincount=5)
    end
    open(joinpath(output,"profile-tree.txt"),"w") do io
        Profile.print(io;format=:tree,C=false,mincount=20,maxdepth=22)
    end
    for path in files;hashes[path]==sha(path) || error("native source changed during profile");end
    report=Dict("schema"=>"vbfsearch-native-profile-v1","created_utc"=>string(now(UTC)),
        "input"=>abspath(input),"input_sha256"=>sha(input),"source_hashes"=>hashes,
        "tool_sha256"=>sha(@__FILE__),"rank_table_build_seconds"=>build,
        "elapsed_seconds"=>elapsed,"sample_delay_seconds"=>0.0005,
        "threads"=>Threads.nthreads(),"records"=>results,
        "scope"=>"Four existing holdout jobs, repeated twice; descriptive native hotspot profile, no campaign writes.")
    open(io->JSON3.pretty(io,report),joinpath(output,"profile.json"),"w")
    println(JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("expected NATIVE_HOLDOUT OUTPUT_DIR")
    run(ARGS...)
end
end
