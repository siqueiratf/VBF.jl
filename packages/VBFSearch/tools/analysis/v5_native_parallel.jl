"""Bounded thread-safety and throughput check of the paired V5 holdout."""
module V5NativeParallel
using VBF,JSON3,SHA,Dates
include("v6_completion_reuse_triangles.jl")
const Q=VBF.QuadraticExtensions
const reference=V6CompletionReuseTriangles.reference_v5_extensions

"Read process CPU time in seconds using the host's own clock-tick frequency."
function process_cpu_seconds(ticks)
    fields=split(last(split(read("/proc/self/stat",String),')';limit=2)))
    (parse(Float64,fields[12])+parse(Float64,fields[13]))/ticks
end

"One independent scratch buffer per worker; geometry and rank lookup are read-only."
function worker(indices,records,G,table,optimized)
    work=Q.V5Work(23);out=Tuple{Int,String}[]
    for i in indices
        record=records[i];V=UInt32.(record["forms"]);need=Int(record["need"])
        r=optimized ? Q.v5_extensions(G,V,need,work;beta=Q.BETA8,max_kernel=23,
            du7_filter=:bitsets,rank_table=table) : reference(G,V,need,work;beta=Q.BETA8,max_kernel=23)
        !r.capped && r.next_x==r.nX+1 || error("parallel job did not exhaust")
        normalized=sort!(collect(r.Ss);by=Tuple)
        push!(out,(i,bytes2hex(SHA.sha256(JSON3.write(normalized)))))
    end
    out
end

function run(input,output;workers=8)
    raw=JSON3.read(read(input,String));raw["complete"] || error("incomplete holdout")
    records=raw["records"];G=Q.geometry(8);table=Q.PolarRankTable(G)
    workers=min(workers,Threads.nthreads(),length(records));ticks=parse(Float64,read(`getconf CLK_TCK`,String))
    first_record=records[1];V=UInt32.(first_record["forms"]);need=Int(first_record["need"]);warm=Q.V5Work(23)
    reference(G,V,need,warm;beta=Q.BETA8,max_x=8,max_kernel=23)
    Q.v5_extensions(G,V,need,warm;beta=Q.BETA8,max_x=8,max_kernel=23,du7_filter=:bitsets,rank_table=table)
    worker(1:0,records,G,table,false)
    timings=Dict{String,Any}();proofs=Dict{String,Any}()
    for optimized in (false,true)
        GC.gc();cpu=process_cpu_seconds(ticks);started=time()
        tasks=[Threads.@spawn worker(i:workers:length(records),records,G,table,optimized) for i in 1:workers]
        result=sort!(reduce(vcat,fetch.(tasks));by=first)
        seconds=time()-started;cpu_seconds=process_cpu_seconds(ticks)-cpu;name=optimized ? "optimized" : "reference"
        timings[name]=Dict("wall_seconds"=>seconds,"process_cpu_seconds"=>cpu_seconds,"average_active_cores"=>cpu_seconds/seconds)
        proofs[name]=result
    end
    proofs["reference"]==proofs["optimized"] || error("parallel output digest mismatch")
    report=Dict("schema"=>"vbfsearch-native-v5-parallel-holdout-v1","created_utc"=>string(now(UTC))*"Z",
        "input_sha256"=>bytes2hex(open(SHA.sha256,input)),"workers"=>workers,"jobs"=>length(records),
        "timings"=>timings,"exact_output_digests_match"=>true,
        "throughput_speedup"=>timings["reference"]["wall_seconds"]/timings["optimized"]["wall_seconds"],
        "scope"=>"One bounded in-memory batch; excludes campaign SQLite, EA admission, remote transport and rank-table construction")
    open(io->JSON3.pretty(io,report),output,"w");report
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && V5NativeParallel.run(ARGS[1],ARGS[2])
