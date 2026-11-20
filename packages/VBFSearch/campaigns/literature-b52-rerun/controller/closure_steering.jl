"""Optional region steering of the parent windows (off by default).

See STEERING.md. With `steering = "none"` (the default) nothing here runs and
the controller keeps its FIFO order by admission id. With `steering = "region"`
each window takes a FIFO share of the lowest unfinished ids, and fills the rest
from the (two, three) lattice points that have the lowest coverage. The lattice
point of a class is entries 2 and 3 of VBF `nonbent_signature` (the number of
2- and 3-dimensional subspaces in its nonbent component set). The controller
measures each parent once and keeps the value in the added ledger table
`steering_regions`. No existing table changes.

The selection is a pure function of the ledger (parents, jobs, LUTs) and of the
parents that active windows hold. It never reads the clock or worker state.
"""
module ClosureSteering
using VBFSearch,SQLite,VBF
const FP=VBFSearch

const MODES=("none","region")
const SCORES=("ratio","expanded")
# Parents measured since the last steering_window event (for the log only).
const MEASURED_SINCE_EVENT=Ref(0)
const CONSTRUCTION="j.kind IN ('prepare_v5','v5','switching') AND j.status!='done'"

"""Read and check the steering keys; `nothing` means FIFO (the default)."""
function steering_options(config)
    mode=String(get(config,"steering","none"))
    mode in MODES || throw(ArgumentError("steering must be one of $(MODES)"))
    mode=="none" && return nothing
    share=get(config,"steering_fifo_share",0.5)
    share isa Real && 0<share<=1 || throw(ArgumentError("steering_fifo_share must be in (0, 1]"))
    score=String(get(config,"steering_score","ratio"))
    score in SCORES || throw(ArgumentError("steering_score must be one of $(SCORES)"))
    batch=Int(get(config,"steering_measure_batch",4096))
    batch>0 || throw(ArgumentError("steering_measure_batch must be positive"))
    (;mode,fifo_share=Float64(share),score,measure_batch=batch)
end

"""Record of the options for the session budgets and the evidence."""
steering_record(options)=options===nothing ? Dict{String,Any}("mode"=>"none") :
    Dict{String,Any}("mode"=>options.mode,"fifo_share"=>options.fifo_share,"score"=>options.score,
        "lattice"=>"VBF nonbent_signature entries 2 and 3","table"=>"steering_regions")

"""Number of FIFO places in a window: ceil(share * window), at least 1."""
fifo_places(window_size,share)=clamp(ceil(Int,round(share*window_size;digits=9)),1,window_size)

"""
    steer_select(frontier, point, admitted, window_size; fifo_share, score)

The pure selection rule. `frontier` holds the ids that a new window may take
(origin in scope, construction unfinished, not in an active window), in
ascending order. `point[id]` is the lattice point of a parent. `available[p]`
counts the parents of point `p` that any window may still take (all origins).
`admitted[p]` counts all parents of point `p`.

1. The FIFO part is the `fifo_places` lowest ids of the frontier.
2. Each point starts with `claimed = admitted - available` (expanded or held by
   an active window), plus the FIFO picks of this window.
3. Each further place goes to the point with the lowest key, then that point's
   lowest remaining id is taken and its `claimed` grows by 1. The key is
   `(claimed/admitted, claimed, lowest id)` for score "ratio" and
   `(claimed, claimed/admitted, lowest id)` for score "expanded".

Returns the chosen ids in ascending order and the FIFO and steered parts.
"""
function steer_select(frontier::AbstractVector{<:Integer},point::AbstractDict,available::AbstractDict,
    admitted::AbstractDict,window_size::Integer;fifo_share::Real=0.5,score::AbstractString="ratio")
    window_size>0 || throw(ArgumentError("invalid window size"))
    score in SCORES || throw(ArgumentError("invalid steering score"))
    issorted(frontier;lt=<=) || throw(ArgumentError("frontier must be strictly ascending"))
    k=min(length(frontier),Int(window_size))
    nfifo=min(k,fifo_places(Int(window_size),fifo_share))
    fifo=Int.(frontier[1:nfifo])
    claimed=Dict(p=>admitted[p]-available[p] for p in keys(admitted))
    for id in fifo;claimed[point[id]]+=1;end
    queues=Dict{Any,Vector{Int}}()
    for id in @view frontier[nfifo+1:end]
        push!(get!(queues,point[id],Int[]),Int(id))
    end
    heads=Dict(p=>1 for p in keys(queues))
    steered=Int[]
    for _ in 1:(k-nfifo)
        best=nothing;bestkey=nothing
        for (p,q) in queues
            heads[p]>length(q) && continue
            c=claimed[p];a=admitted[p]
            a>0 || error("lattice point without admitted classes")
            key=score=="ratio" ? (c//a,c,q[heads[p]]) : (c,c//a,q[heads[p]])
            if bestkey===nothing || key<bestkey
                best=p;bestkey=key
            end
        end
        push!(steered,queues[best][heads[best]]);heads[best]+=1;claimed[best]+=1
    end
    (;ids=sort!(vcat(fifo,steered)),fifo,steered)
end

"""Lattice point (two, three) of an eight-bit LUT."""
function lattice_point(lut::AbstractVector{UInt8})
    signature=nonbent_signature(SBox{8}(lut))
    item(i)=length(signature)>=i ? Int(signature[i]) : 0
    (item(2),item(3))
end

_db(s)=s isa SQLite.DB ? s : s.db
function _write(f,s)
    SQLite.intransaction(_db(s)) && return f()
    FP._closure_exec(_db(s),"BEGIN IMMEDIATE")
    try
        result=f();FP._closure_exec(_db(s),"COMMIT");result
    catch
        FP._closure_exec(_db(s),"ROLLBACK");rethrow()
    end
end

"""Add the steering table if it is absent. Existing tables do not change."""
ensure_table!(s)=FP._closure_exec(_db(s),"CREATE TABLE IF NOT EXISTS steering_regions(parent_id INTEGER PRIMARY KEY REFERENCES parents(id),candidate_id TEXT NOT NULL,two INTEGER NOT NULL,three INTEGER NOT NULL)")

"""Measure every parent that has no lattice point yet, in id order and in batches."""
function measure_missing!(s;batch=4096)
    ensure_table!(s)
    cursor=0;measured=0
    while true
        rows=FP._closure_rows(s,"SELECT p.id,p.candidate_id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id>? AND NOT EXISTS(SELECT 1 FROM steering_regions r WHERE r.parent_id=p.id) ORDER BY p.id LIMIT ?",(cursor,batch))
        isempty(rows) && break
        points=Vector{Tuple{Int,Int}}(undef,length(rows))
        Threads.@threads for i in eachindex(rows)
            points[i]=lattice_point(hex2bytes(String(rows[i]["lut_hex"])))
        end
        _write(s) do
            for (row,(two,three)) in zip(rows,points)
                FP._closure_exec(s,"INSERT INTO steering_regions(parent_id,candidate_id,two,three) VALUES(?,?,?,?)",
                    (Int(row["id"]),String(row["candidate_id"]),two,three))
            end
        end
        measured+=length(rows);cursor=Int(last(rows)["id"])
    end
    measured
end

"""
Steered replacement of the FIFO query of `select_parents` for one origin.
Returns rows like `select_parents` (id, source, origin), in ascending id order.
"""
function steered_rows(s,window_size,origin,excluded::AbstractSet{Int},options)
    started=time()
    MEASURED_SINCE_EVENT[]+=measure_missing!(s;batch=options.measure_batch)
    open=FP._closure_rows(s,"SELECT p.id,p.origin,r.two,r.three FROM parents p JOIN steering_regions r ON r.parent_id=p.id WHERE EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND $CONSTRUCTION) ORDER BY p.id")
    admitted=Dict{Tuple{Int,Int},Int}()
    for r in FP._closure_rows(s,"SELECT two,three,COUNT(*) n FROM steering_regions GROUP BY two,three")
        admitted[(Int(r["two"]),Int(r["three"]))]=Int(r["n"])
    end
    sum(values(admitted);init=0)==FP._closure_count(s,"SELECT COUNT(*) n FROM parents") || error("steering table does not cover every parent")
    point=Dict{Int,Tuple{Int,Int}}();available=Dict(p=>0 for p in keys(admitted));frontier=Int[]
    for r in open
        id=Int(r["id"]);id in excluded && continue
        p=(Int(r["two"]),Int(r["three"]));point[id]=p;available[p]+=1
        String(r["origin"])==origin && push!(frontier,id)
    end
    isempty(frontier) && return Any[]
    choice=steer_select(frontier,point,available,admitted,window_size;fifo_share=options.fifo_share,score=options.score)
    rows=FP._closure_rows(s,"SELECT id,source,origin FROM parents WHERE id IN (SELECT value FROM json_each(?)) ORDER BY id",
        (String(FP.JSON3.write(choice.ids)),))
    println(FP.JSON3.write(Dict("event"=>"steering_window","origin"=>origin,"score"=>options.score,
        "fifo_share"=>options.fifo_share,"frontier"=>length(frontier),"measured"=>MEASURED_SINCE_EVENT[],
        "fifo"=>choice.fifo,"steered"=>choice.steered,
        "steered_points"=>[collect(point[id]) for id in choice.steered],
        "lattice_points"=>length(admitted),"seconds"=>round(time()-started;digits=3))));flush(stdout)
    MEASURED_SINCE_EVENT[]=0
    rows
end
end
