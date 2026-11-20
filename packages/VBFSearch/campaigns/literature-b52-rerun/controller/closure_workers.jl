"""Construction compute in pinned worker processes; the coordinator keeps the ledger.

Optional backend of the continuous controller (`worker_processes` in the
config). Each worker process loads the same pinned VBFSearch project, builds its
own scratch contexts once (rank table and verified-property cache, exactly as
the threaded controller does), one per default thread, and runs at most that
many packets at once. The coordinator gives each worker `threads × depth`
slots (`worker_queue_depth`, default 2): the extra packets wait in the worker
and start as soon as a context is free, so the coordinator's own latency
(apply, reports) does not leave worker threads idle between packets.
It never opens the ledger: it receives the coordinator's construction packets
(`prepare_v5`, `v5`, `switching`) and returns the unchanged result of
`VBFSearch._closure_compute`. Reservation, EA, ordered application and every
database write stay in the single coordinator process.

Protocol: one loopback TCP connection per worker, authenticated by a random
token. Each message is a frame `UInt64 length (little endian) || Serialization
bytes`. Both processes load the same module versions, which the handshake
checks (active project, manifest and VBFSearch source path).

    coordinator -> worker   (:compute, id, slot, packet, seconds, evaluations)
                            (:cancel, id)    cooperative stop of one request
                            (:stats,)        counters, CPU and GC of the worker
                            (:exit,)
    worker -> coordinator   (:hello, Dict)   once, after the contexts exist
                            (:result, id, value, Dict)
                            (:error, id, text)
                            (:stats, Dict)

STOP semantics equal the threaded controller: a request whose pool stop
condition becomes true receives `:cancel`, which the worker passes to
`stop_requested`; v5 stops between complete cosets and its partial result
applies normally. A worker failure (exit, lost connection or compute error)
fails each of its requests with an exception, so the refill pool applies the
successful prefix, joins every task and rethrows; the controller then marks
unapplied 'running' jobs 'paused' (and `_closure_open` repeats this on restart).

Run as a script, this file is the worker:
    julia --project=P closure_workers.jl --serve PORT TOKEN INDEX SLOTS OPTIONS_HEX
"""
module ClosureWorkers
using VBFSearch, Sockets, Serialization, SHA
const FP=VBFSearch
const PROTOCOL="vbf-closure-workers-v1"
const MAX_FRAME=UInt64(1)<<34

"""Write one length-prefixed Serialization frame under `guard`; return its size."""
function write_frame(io,guard,message)
    buffer=IOBuffer();serialize(buffer,message);bytes=take!(buffer)
    lock(guard) do
        write(io,htol(UInt64(length(bytes))));write(io,bytes);flush(io)
    end
    length(bytes)
end

"""Read one frame; an orderly close before a frame raises EOFError."""
function read_frame(io)
    n=ltoh(read(io,UInt64))
    n<=MAX_FRAME || error("closure worker frame of $n bytes exceeds the protocol limit")
    bytes=read(io,Int(n))
    length(bytes)==n || throw(EOFError())
    started=time_ns();message=deserialize(IOBuffer(bytes))
    (message,Int(n),(time_ns()-started)*1e-9)
end

function process_cpu_seconds()
    fields=split(last(split(read("/proc/self/stat",String),") ";limit=2)))
    (parse(Int,fields[12])+parse(Int,fields[13]))/ccall(:sysconf,Clong,(Cint,),2)
end

file_sha(path)=bytes2hex(open(SHA.sha256,path))
"""Identity of the loaded code that both sides must share."""
function code_identity()
    project=Base.active_project()
    project===nothing && error("a pinned active project is required")
    manifest=joinpath(dirname(project),"Manifest.toml")
    Dict{String,Any}("protocol"=>PROTOCOL,"julia"=>string(VERSION),"project"=>project,
        "project_sha256"=>file_sha(project),"manifest_sha256"=>isfile(manifest) ? file_sha(manifest) : "",
        "vbfsearch"=>String(pathof(FP)),"workers_source_sha256"=>file_sha(@__FILE__))
end

# ---------------------------------------------------------------- coordinator

struct WorkerSpec
    cpus::String
    threads::Int
    gc_threads::Int
    heap_size_hint::String
end

"""Coordinator slots per worker thread (`worker_queue_depth`, default 2)."""
function queue_depth(config)
    depth=Int(get(config,"worker_queue_depth",2))
    1<=depth<=8 || throw(ArgumentError("worker_queue_depth must be between 1 and 8"))
    depth
end

"""Parse `worker_processes` (array of tables) plus optional defaults.

Each entry: `cpus` (taskset list, "" for no pinning), `threads` (compute
slots), optional `gc_threads` and `heap_size_hint`. Defaults come from the
top-level `worker_gc_threads` (threads÷2) and `worker_heap_size_hint` ("8G").
An empty or missing list keeps the threaded controller unchanged.
"""
function parse_specs(config)
    entries=get(config,"worker_processes",Any[])
    entries isa AbstractVector || throw(ArgumentError("worker_processes must be an array of tables"))
    specs=WorkerSpec[]
    for entry in entries
        entry isa AbstractDict || throw(ArgumentError("each worker process must be a table"))
        threads=Int(get(entry,"threads",0))
        threads>0 || throw(ArgumentError("worker threads must be positive"))
        cpus=String(get(entry,"cpus",""))
        occursin(r"^[0-9,\-]*$",cpus) || throw(ArgumentError("invalid worker CPU list: $cpus"))
        gc=Int(get(entry,"gc_threads",get(config,"worker_gc_threads",max(1,threads÷2))))
        gc>0 || throw(ArgumentError("worker GC threads must be positive"))
        heap=String(get(entry,"heap_size_hint",get(config,"worker_heap_size_hint","8G")))
        occursin(r"^[0-9]*[KMGT%]?$",heap) || throw(ArgumentError("invalid worker heap size hint: $heap"))
        push!(specs,WorkerSpec(cpus,threads,gc,heap))
    end
    specs
end

mutable struct RemoteWorker
    index::Int
    spec::WorkerSpec
    process::Base.Process
    log::String
    socket::Union{Nothing,TCPSocket}
    guard::ReentrantLock
    alive::Bool
    failure::String
    hello::Dict{String,Any}
    reader::Union{Nothing,Task}
    requests::Int
    results::Int
    request_bytes::Int
    result_bytes::Int
    max_result_bytes::Int
    decode_seconds::Float64
    stats::Union{Nothing,Dict{String,Any}}
end

mutable struct WorkerPool
    workers::Vector{RemoteWorker}
    slots::Vector{Tuple{Int,Int}}
    guard::ReentrantLock
    pending::Dict{Int,Tuple{Int,Channel{Any}}}
    inflight::Dict{Int,Tuple{Int,Any,Bool}}
    next_request::Int
    token::String
    server::Union{Nothing,Sockets.TCPServer}
    started::Float64
    ready_seconds::Float64
    closed::Bool
    watcher::Union{Nothing,Task}
    kinds::Dict{String,Vector{Float64}}
    options::Dict{String,Any}
    identity::Dict{String,Any}
    threaded_region::Bool
end

slot_count(pool::WorkerPool)=length(pool.slots)

"""Launch the worker processes without waiting for them (see `await_pool!`)."""
function start_pool(specs::Vector{WorkerSpec};log_directory,options=Dict{String,Any}(),depth::Int=2,
    julia=Base.julia_cmd(),project=dirname(Base.active_project()))
    isempty(specs) && throw(ArgumentError("no worker processes configured"))
    server=listen(ip"127.0.0.1",0);port=Int(getsockname(server)[2])
    token=bytes2hex(open(io->read(io,32),"/dev/urandom"))
    encoded=bytes2hex(Vector{UInt8}(codeunits(FP.JSON3.write(options))))
    workers=RemoteWorker[];slots=Tuple{Int,Int}[]
    mkpath(log_directory)
    try
        for (index,spec) in enumerate(specs)
            command=`$julia --startup-file=no --history-file=no --compiled-modules=existing --project=$project --threads=$(spec.threads),1 --gcthreads=$(spec.gc_threads),0`
            isempty(spec.heap_size_hint) || (command=`$command --heap-size-hint=$(spec.heap_size_hint)`)
            command=`$command $(@__FILE__) --serve $port $token $index $(spec.threads) $encoded`
            isempty(spec.cpus) || (command=`taskset -c $(spec.cpus) $command`)
            log=joinpath(log_directory,"worker-$index.log")
            process=open(log,"w") do io
                run(pipeline(command;stdin=devnull,stdout=io,stderr=io);wait=false)
            end
            push!(workers,RemoteWorker(index,spec,process,log,nothing,ReentrantLock(),false,"",
                Dict{String,Any}(),nothing,0,0,0,0,0,0.0,nothing))
            append!(slots,[(index,s) for s in 1:depth*spec.threads])
        end
    catch
        for w in workers;kill_worker(w);end
        close(server);rethrow()
    end
    WorkerPool(workers,slots,ReentrantLock(),Dict{Int,Tuple{Int,Channel{Any}}}(),Dict{Int,Tuple{Int,Any,Bool}}(),
        0,token,server,time(),0.0,false,nothing,Dict{String,Vector{Float64}}(),Dict{String,Any}(options),code_identity(),false)
end

function kill_worker(w::RemoteWorker;grace=10.0)
    process_running(w.process) || return
    try
        kill(w.process,Base.SIGTERM)
        timedwait(()->!process_running(w.process),grace;pollint=0.1)
        process_running(w.process) && kill(w.process,Base.SIGKILL)
    catch
    end
end

"""Accept and verify every worker, then start the readers and the cancel watcher."""
function await_pool!(pool::WorkerPool;timeout=900.0)
    server=pool.server;server===nothing && return pool
    accepted=Channel{Any}(length(pool.workers))
    acceptor=@async try
        for _ in pool.workers
            put!(accepted,accept(server))
        end
    catch error
        isopen(server) && put!(accepted,error)
    end
    deadline=time()+timeout;connected=0
    try
        while connected<length(pool.workers)
            for w in pool.workers
                w.socket===nothing && !process_running(w.process) &&
                    error("closure worker $(w.index) exited during startup (code $(w.process.exitcode)); see $(w.log)")
            end
            time()<deadline || error("closure workers did not start within $timeout seconds")
            timedwait(()->isready(accepted),1.0;pollint=0.01)
            isready(accepted) || continue
            socket=take!(accepted);socket isa Exception && throw(socket)
            Sockets.nagle(socket,false)
            message,_,_=read_frame(socket)
            message isa Tuple && length(message)==2 && message[1]===:hello && message[2] isa AbstractDict ||
                (close(socket);error("closure worker sent an invalid handshake"))
            hello=message[2]
            get(hello,"token","")==pool.token || (close(socket);error("closure worker handshake has an invalid token"))
            index=Int(hello["index"]);1<=index<=length(pool.workers) || error("invalid closure worker index")
            w=pool.workers[index];w.socket===nothing || error("closure worker $index connected twice")
            for key in keys(pool.identity)
                get(hello["identity"],key,nothing)==pool.identity[key] ||
                    error("closure worker $index loaded different code ($key): $(get(hello["identity"],key,nothing)) != $(pool.identity[key])")
            end
            Int(hello["slots"])==w.spec.threads==Int(hello["threads"]) || error("closure worker $index has the wrong slot count")
            delete!(hello,"token");delete!(hello,"warmup")
            w.socket=socket;w.hello=Dict{String,Any}(hello);w.alive=true;connected+=1
        end
    catch
        close(server);pool.server=nothing
        for w in pool.workers
            w.socket===nothing || close(w.socket)
            kill_worker(w)
        end
        rethrow()
    end
    close(server);pool.server=nothing
    for w in pool.workers
        w.reader=Threads.@spawn read_loop(pool,w)
    end
    pool.watcher=Threads.@spawn watch_cancellations(pool)
    # Outside a threaded region Julia polls libuv only on thread 1, which runs
    # the busy coordinator loop (apply, prepare, reports); results would wait
    # until it yields. Inside one, any idle coordinator thread polls the sockets.
    ccall(:jl_enter_threaded_region,Cvoid,());pool.threaded_region=true
    pool.ready_seconds=time()-pool.started
    pool
end

function worker_failed!(pool::WorkerPool,w::RemoteWorker,reason)
    lock(pool.guard) do
        w.alive || return
        w.alive=false;w.failure=reason
        for (id,(index,channel)) in collect(pool.pending)
            index==w.index || continue
            delete!(pool.pending,id)
            put!(channel,(:dead,id,reason))
        end
    end
end

function read_loop(pool::WorkerPool,w::RemoteWorker)
    try
        while true
            message,bytes,decode=read_frame(w.socket)
            w.decode_seconds+=decode
            kind=message[1]
            if kind===:stats
                w.stats=message[2]
                continue
            end
            kind in (:result,:error) || error("unexpected closure worker message $kind")
            id=message[2]
            channel=lock(pool.guard) do
                entry=pop!(pool.pending,id,nothing)
                entry===nothing ? nothing : entry[2]
            end
            channel===nothing && error("closure worker answered an unknown request $id")
            w.results+=1;w.result_bytes+=bytes;w.max_result_bytes=max(w.max_result_bytes,bytes)
            put!(channel,(message...,bytes,time()))
        end
    catch error
        reason=pool.closed ? "closed by the coordinator" :
            "closure worker $(w.index) (pid $(get(w.hello,"pid",0)), CPUs $(w.spec.cpus)) connection lost: "*
            sprint(showerror,error)*(process_running(w.process) ? "" : "; exit code $(w.process.exitcode), signal $(w.process.termsignal)")*"; see $(w.log)"
        worker_failed!(pool,w,reason)
    end
end

"""Forward each request's stop condition (the refill pool's `worker_stop`)."""
function watch_cancellations(pool::WorkerPool)
    while !pool.closed
        sleep(0.1)
        cancel=Tuple{Int,Int}[]
        lock(pool.guard) do
            for (id,(index,stop,sent)) in pool.inflight
                sent && continue
                if stop()
                    pool.inflight[id]=(index,stop,true);push!(cancel,(id,index))
                end
            end
        end
        for (id,index) in cancel
            w=pool.workers[index]
            try
                w.alive && write_frame(w.socket,w.guard,(:cancel,id))
            catch
            end
        end
    end
end

"""Compute one construction packet on the remote slot owned by `slot`."""
function remote_compute(pool::WorkerPool,slot::Int,packet;seconds,evaluations,stop_requested=()->false)
    index,local_slot=pool.slots[slot];w=pool.workers[index]
    channel=Channel{Any}(1)
    id=lock(pool.guard) do
        w.alive || error("closure worker $index is not available: $(w.failure)")
        pool.next_request+=1;id=pool.next_request
        pool.pending[id]=(index,channel);pool.inflight[id]=(index,stop_requested,false)
        id
    end
    started=time_ns()
    try
        try
            bytes=write_frame(w.socket,w.guard,(:compute,id,local_slot,packet,Float64(seconds),Int(evaluations)))
            lock(pool.guard) do
                w.requests+=1;w.request_bytes+=bytes
            end
        catch error
            worker_failed!(pool,w,"closure worker $index request failed: "*sprint(showerror,error))
        end
        response=take!(channel)
        kind=response[1]
        kind===:result || error(kind===:error ? "closure worker $index failed packet $(packet["job_id"]): $(response[3])" :
            "closure worker $index failed: $(response[3])")
        value=response[3]
        lock(pool.guard) do
            times=get!(pool.kinds,String(packet["kind"]),zeros(7))
            times[1]+=1;times[2]+=(time_ns()-started)*1e-9;times[3]+=response[4]["compute_seconds"]
            times[4]+=response[5];times[5]=max(times[5],response[5])
            # finished (worker) -> decoded (coordinator reader) -> resumed (waiting task)
            times[6]+=max(0.0,response[6]-get(response[4],"finished_unix",response[6]));times[7]+=max(0.0,time()-response[6])
        end
        value
    finally
        lock(pool.guard) do
            delete!(pool.inflight,id);delete!(pool.pending,id)
        end
    end
end

"""Small coordinator-side snapshot for progress reports (no remote call)."""
function summary(pool::WorkerPool)
    workers=[Dict{String,Any}("index"=>w.index,"cpus"=>w.spec.cpus,"threads"=>w.spec.threads,
        "gc_threads"=>w.spec.gc_threads,"heap_size_hint"=>w.spec.heap_size_hint,
        "pid"=>get(w.hello,"pid",0),"alive"=>w.alive,"failure"=>w.failure,
        "setup_seconds"=>get(w.hello,"setup_seconds",0.0),"rank_table_build_seconds"=>get(w.hello,"rank_table_build_seconds",0.0),
        "warmup_seconds"=>get(w.hello,"warmup_seconds",0.0),
        "requests"=>w.requests,"results"=>w.results,"request_bytes"=>w.request_bytes,
        "result_bytes"=>w.result_bytes,"max_result_bytes"=>w.max_result_bytes,"decode_seconds"=>w.decode_seconds) for w in pool.workers]
    kinds=lock(pool.guard) do
        Dict{String,Any}(k=>Dict("packets"=>Int(v[1]),"round_trip_seconds"=>v[2],"worker_compute_seconds"=>v[3],
            "result_bytes"=>Int(v[4]),"max_result_bytes"=>Int(v[5]),"delivery_seconds"=>v[6],"wake_seconds"=>v[7]) for (k,v) in pool.kinds)
    end
    Dict{String,Any}("backend"=>"worker_processes","protocol"=>PROTOCOL,"slots"=>slot_count(pool),
        "ready_seconds"=>pool.ready_seconds,"workers"=>workers,"kinds"=>kinds)
end

"""Collect worker statistics, stop every worker and close the connections."""
function close_pool!(pool::WorkerPool;timeout=30.0,statistics=true)
    pool.closed && return summary(pool)
    if statistics
        for w in pool.workers
            w.alive || continue
            try
                write_frame(w.socket,w.guard,(:stats,))
            catch
            end
        end
        timedwait(()->all(w->!w.alive || w.stats!==nothing,pool.workers),timeout;pollint=0.05)
    end
    pool.closed=true
    for w in pool.workers
        try
            w.alive && write_frame(w.socket,w.guard,(:exit,))
        catch
        end
    end
    timedwait(()->all(w->!process_running(w.process),pool.workers),timeout;pollint=0.1)
    for w in pool.workers
        kill_worker(w)
        w.socket===nothing || close(w.socket)
    end
    pool.server===nothing || close(pool.server)
    if pool.threaded_region
        ccall(:jl_exit_threaded_region,Cvoid,());pool.threaded_region=false
    end
    result=summary(pool)
    result["worker_statistics"]=[w.stats for w in pool.workers]
    result
end

# --------------------------------------------------------------------- worker

"""Multiply in GF(2^8) modulo x^8+x^4+x^3+x+1."""
function gf_mul(a::UInt8,b::UInt8)
    r=0x00
    for _ in 1:8
        (b&0x01)!=0 && (r⊻=a)
        a=(a&0x80)!=0 ? (a<<1)⊻0x1b : a<<1
        b>>=1
    end
    r
end

"""Compile every construction path once before serving (off the critical path).

Runs one packet of each kind for the Gold function x^3, a quadratic APN, in a
private context (its own property cache; the shared read-only rank table).
The results are serialized and deserialized here and sent with the handshake,
so the coordinator also compiles its decoder before the first real result.
Failures only lose the warm-up; they never affect real packets.
"""
function warmup(table)
    started=time_ns();results=Any[]
    try
        context=FP.ClosureWorkContext(;rank_table=table,property_cache_entries=64)
        lut=UInt8[gf_mul(gf_mul(UInt8(x),UInt8(x)),UInt8(x)) for x in 0:255]
        p=FP.properties(lut)
        base=Dict{String,Any}("schema"=>FP.CLOSURE_WORK_SCHEMA,"job_id"=>0,"parent_id"=>0,"job_key"=>"warmup",
            "direction"=>1,"combination"=>"1","target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>2,"switching_directions"=>1,
            "parent"=>Dict{String,Any}("lut_sha256"=>p["lut_sha256"],"lut_hex"=>bytes2hex(lut),"sigma"=>p["sigma_hash"]))
        function packet(kind,payload)
            q=merge(base,Dict{String,Any}("kind"=>kind,"payload"=>payload))
            q["packet_sha256"]=FP._closure_packet_digest(q);q
        end
        prepared=FP._closure_compute(packet("prepare_v5",Dict{String,Any}());context,seconds=120.0,evaluations=256)
        push!(results,prepared);work=prepared["work"]
        if !isempty(work["spaces"])
            payload=Dict{String,Any}("forms"=>Int.(first(work["spaces"])),"need"=>52-work["max_b5"],"b5"=>work["max_b5"])
            push!(results,FP._closure_compute(packet("v5",payload);context,seconds=120.0,evaluations=256))
        end
        push!(results,FP._closure_compute(packet("switching",Dict{String,Any}());context,seconds=30.0,evaluations=4))
        buffer=IOBuffer();serialize(buffer,results);results=deserialize(IOBuffer(take!(buffer)))
    catch error
        println(stderr,"closure worker warm-up failed (ignored): ",sprint(showerror,error))
    end
    (results,(time_ns()-started)*1e-9)
end

"""Serve compute requests until the coordinator closes the connection."""
function serve(port,token,index,slots,options)
    setup_started=time_ns()
    nthreads=Threads.nthreads(:default)
    slots==nthreads || error("worker slots $slots must equal its $nthreads default threads")
    geometry=FP.Fourier.geometry(8)
    table_started=time_ns()
    table=get(options,"precompute_rank_table",true) ?
        (get(options,"packed_rank_table",true) ? FP.Fourier.PackedPolarRankTable(geometry) : FP.Fourier.PolarRankTable(geometry)) : nothing
    table_seconds=(time_ns()-table_started)*1e-9
    entries=Int(get(options,"shared_property_cache_entries",8192))
    cache=entries==0 ? nothing : FP.DiscoveryEvidence.PropertyCache(;max_entries=entries)
    contexts=Channel{FP.ClosureWorkContext}(slots)
    for _ in 1:slots
        put!(contexts,FP.ClosureWorkContext(;rank_table=table,property_cache=cache))
    end
    warm,warm_seconds=get(options,"warmup",true) ? warmup(table) : (Any[],0.0)
    socket=connect(ip"127.0.0.1",port);Sockets.nagle(socket,false)
    guard=ReentrantLock();flags=Dict{Int,Threads.Atomic{Bool}}();flags_guard=ReentrantLock()
    kinds=Dict{String,Vector{Float64}}();tasks=Set{Task}()
    write_frame(socket,guard,(:hello,Dict{String,Any}("token"=>token,"index"=>index,"slots"=>slots,
        "threads"=>nthreads,"gc_threads"=>Threads.ngcthreads(),"pid"=>getpid(),"host"=>gethostname(),
        "identity"=>code_identity(),"setup_seconds"=>(time_ns()-setup_started)*1e-9,
        "rank_table_build_seconds"=>table_seconds,"cpu_affinity"=>affinity(),
        "warmup_seconds"=>warm_seconds,"warmup"=>warm)))
    println("closure worker $index ready: pid $(getpid()), $slots slots, affinity $(affinity())");flush(stdout)
    function compute!(id,slot,packet,seconds,evaluations,flag)
        # At most `slots` packets run; queued ones wait for a free context. The
        # reply is sent before the context is released: Julia tasks are not
        # preempted, so a queued packet would otherwise take this thread and
        # delay the finished result by a whole packet.
        started=time_ns();context=take!(contexts);queued=(time_ns()-started)*1e-9;bytes=0
        reply=try
            started=time_ns()
            value=FP._closure_compute(packet;context,seconds,evaluations,stop_requested=()->flag[])
            (:result,id,value,Dict{String,Any}("compute_seconds"=>(time_ns()-started)*1e-9,"queued_seconds"=>queued,"finished_unix"=>time()))
        catch error
            (:error,id,sprint(showerror,error,catch_backtrace()))
        end
        try
            bytes=write_frame(socket,guard,reply)
        catch error
            println(stderr,"closure worker $index cannot answer request $id: ",sprint(showerror,error))
        finally
            put!(contexts,context)
        end
        lock(flags_guard) do
            delete!(flags,id)
            times=get!(kinds,String(get(packet,"kind","unknown")),zeros(4))
            times[1]+=1;times[2]+=reply[1]===:result ? reply[4]["compute_seconds"] : 0.0
            times[3]+=bytes;times[4]=max(times[4],bytes)
        end
    end
    try
        while true
            message,bytes,_=try
                read_frame(socket)
            catch error
                error isa EOFError || error isa Base.IOError || rethrow()
                break
            end
            kind=message[1]
            if kind===:compute
                _,id,slot,packet,seconds,evaluations=message
                flag=Threads.Atomic{Bool}(false)
                lock(flags_guard) do;flags[id]=flag;end
                task=Threads.@spawn compute!(id,slot,packet,seconds,evaluations,flag)
                lock(flags_guard) do
                    filter!(!istaskdone,tasks);push!(tasks,task)
                end
            elseif kind===:cancel
                lock(flags_guard) do
                    flag=get(flags,message[2],nothing)
                    flag===nothing || (flag[]=true)
                end
            elseif kind===:stats
                write_frame(socket,guard,(:stats,worker_statistics(index,cache,kinds,flags_guard)))
            elseif kind===:exit
                break
            else
                error("unknown coordinator message $kind")
            end
        end
    finally
        # Exit promptly: the coordinator alone owns recovery of unapplied work.
        for flag in values(flags);flag[]=true;end
        close(socket)
    end
end

function worker_statistics(index,cache,kinds,flags_guard)
    gc=Base.gc_num()
    property=nothing
    if cache!==nothing
        property=lock(cache.guard) do
            Dict{String,Any}("entries"=>length(cache.values),"hits"=>cache.hits,"misses"=>cache.misses)
        end
    end
    packets=lock(flags_guard) do
        Dict{String,Any}(k=>Dict{String,Any}("packets"=>Int(v[1]),"compute_seconds"=>v[2],"result_bytes"=>Int(v[3]),
            "max_result_bytes"=>Int(v[4])) for (k,v) in kinds)
    end
    Dict{String,Any}("index"=>index,"pid"=>getpid(),"cpu_seconds"=>process_cpu_seconds(),
        "gc_seconds"=>gc.total_time/1e9,"allocated_bytes"=>Int(Base.gc_total_bytes(gc)),
        "max_rss_bytes"=>Int(Sys.maxrss()),"property_cache"=>property,"kinds"=>packets)
end

function affinity()
    try
        line=only(filter(l->startswith(l,"Cpus_allowed_list"),readlines("/proc/self/status")))
        strip(last(split(line,':')))
    catch
        ""
    end
end

end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==6 && ARGS[1]=="--serve" || error("usage: closure_workers.jl --serve PORT TOKEN INDEX SLOTS OPTIONS_HEX")
    options=ClosureWorkers.FP.JSON3.read(String(hex2bytes(ARGS[6])),Dict{String,Any})
    ClosureWorkers.serve(parse(Int,ARGS[2]),ARGS[3],parse(Int,ARGS[4]),parse(Int,ARGS[5]),options)
    exit(0)
end
