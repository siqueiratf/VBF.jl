"""Build cached, deterministic class-graph layouts from read-only closure snapshots.

Run in docs/inspector's environment with --run PATH [--every-seeds 500]
[--min-seconds 600] [--once]. The watcher reads progress.toml between builds;
HTTP requests never trigger SQL or layout work.
"""
module APNClosureGraph
using Dates, Graphs, JSON3, LinearAlgebra, SHA, SQLite, TOML
const SQL=SQLite.DBInterface
const SCHEMA="vbfsearch-class-graph-v1"
atomic_json(path,value)=begin
    open(io->JSON3.write(io,value),path*".tmp","w")
    mv(path*".tmp",path;force=true)
end

"""Return the committed completion counter without opening the ledger."""
completion_count(run)=Int(get(TOML.parsefile(joinpath(run,"progress.toml")),"completed_parents",0))

"""Require both the completion increment and the minimum age before rebuilding."""
function refresh_due(output,completed;every_seeds=500,min_seconds=600,now_seconds=time())
    path=joinpath(output,"current.json")
    isfile(path) || return true
    previous=JSON3.read(read(path,String),Dict{String,Any})
    completed-previous["completed_parents"]>=every_seeds && now_seconds-stat(path).mtime>=min_seconds
end

"""Landmark-distance projection with deterministic tie breaking and bounded work."""
function project_component(graph;landmarks=12)
    n=nv(graph)
    n==1 && return zeros(Float32,1,2)
    count=min(n,landmarks);X=Matrix{Float32}(undef,n,count)
    nearest=fill(typemax(Int),n);pivot=1
    for j in 1:count
        distances=gdistances(graph,pivot)
        for i in 1:n
            d=distances[i];d==typemax(Int) && error("disconnected layout component")
            X[i,j]=d;nearest[i]=min(nearest[i],d)
        end
        pivot=argmax(nearest)
    end
    for j in axes(X,2)
        X[:,j].-=sum(@view X[:,j])/n
    end
    E=eigen(Symmetric(X'X))
    axes2=E.vectors[:,end:-1:max(1,end-1)]
    Y=X*axes2
    size(Y,2)==1 && (Y=hcat(Y,zeros(Float32,n)))
    # Fix PCA's arbitrary signs. Coordinates are visual, not a mathematical invariant.
    for j in 1:2
        i=argmax(abs.(@view Y[:,j]));Y[i,j]<0 && (Y[:,j].*=-1)
    end
    Y
end

"""Pack every connected component in its own rectangle, proportional to its size."""
function component_boxes(components)
    weights=Float64[max(length(c),4) for c in components];prefix=cumsum(weights)
    boxes=Vector{NTuple{4,Float64}}(undef,length(components))
    function divide(first,last,x,y,w,h)
        if first==last
            boxes[first]=(x,y,w,h);return
        end
        before=first==1 ? 0.0 : prefix[first-1];total=prefix[last]-before
        split=clamp(searchsortedfirst(prefix,before+total/2),first,last-1)
        ratio=(prefix[split]-before)/total
        if w>=h
            divide(first,split,x,y,w*ratio,h)
            divide(split+1,last,x+w*ratio,y,w*(1-ratio),h)
        else
            divide(first,split,x,y,w,h*ratio)
            divide(split+1,last,x,y+h*ratio,w,h*(1-ratio))
        end
    end
    divide(1,length(components),-1.6,-1.0,3.2,2.0)
    boxes
end

"""Stable integer mixing for small coordinate jitter at overlapping projections."""
function noise(id,salt)
    x=UInt64(id)⊻salt;x=(x⊻(x>>30))*0xbf58476d1ce4e5b9
    x=(x⊻(x>>27))*0x94d049bb133111eb;x⊻=x>>31
    Float64(x&0xffffff)/0xffffff-0.5
end

"""Write little-endian binary arrays consumed directly by the WebGL viewer."""
function write_binary(path,array)
    open(path,"w") do io
        write(io,htol.(array))
    end
end

"""Export one consistent snapshot, finish its layout, then publish it atomically."""
function build(run,output;every_seeds=500,min_seconds=600)
    started=time();mkpath(output);completed=completion_count(run)
    for name in readdir(output)
        occursin(r"^\.building-\d{8}T\d{6}-\d+-\d+$",name) && isdir(joinpath(output,name)) && rm(joinpath(output,name);recursive=true)
    end
    db=SQLite.DB("file:"*abspath(joinpath(run,"closure.sqlite"))*"?mode=ro")
    parents=Any[];pairs=Dict{UInt64,Tuple{Int,Int}}();pending=0;paths=0;collisions=0
    snapshot=""
    try
        SQL.execute(db,"PRAGMA query_only=ON");SQL.execute(db,"BEGIN")
        parents=[(id=Int(r.id),seed=String(r.origin)=="root",source=String(r.source),sha=String(r.candidate_id))
            for r in SQL.execute(db,"SELECT id,candidate_id,origin,source FROM parents ORDER BY id")]
        collisions=only([Int(r.n) for r in SQL.execute(db,"SELECT COUNT(*) AS n FROM (SELECT sigma FROM parents GROUP BY sigma HAVING COUNT(*)>1)")])
        snapshot=string(now(UTC))*"Z"
        for row in SQL.execute(db,"SELECT p.parent_id,c.class_id,p.method FROM paths p JOIN candidates c ON c.id=p.child_id")
            paths+=1
            if ismissing(row.class_id);pending+=1;continue;end
            u=Int(row.parent_id);v=Int(row.class_id);key=(UInt64(u)<<32)|UInt64(v)
            a,b=get(pairs,key,(0,0));pairs[key]=row.method=="v5" ? (a+1,b) : (a,b+1)
        end
        SQL.execute(db,"COMMIT")
    finally
        SQLite.close(db)
    end
    sql_seconds=time()-started
    isempty(parents) && error("no admitted class nodes")
    n=length(parents);all(parents[i].id==i for i in 1:n) || error("class IDs are not dense")
    graph=SimpleDiGraph(n);undirected=SimpleGraph(n)
    links=UInt32[];self_v5=zeros(UInt32,n);self_switching=zeros(UInt32,n)
    unique_v5=0;unique_switching=0
    for key in sort!(collect(keys(pairs)))
        u=Int(key>>32);v=Int(key&0xffffffff);a,b=pairs[key]
        if u==v
            self_v5[u]=a;self_switching[u]=b;continue
        end
        add_edge!(graph,u,v);add_edge!(undirected,u,v)
        both=a>0 && b>0 ? UInt32(0x40000000) : UInt32(0)
        if a>0;append!(links,(UInt32(u-1),UInt32(v-1)|both));unique_v5+=1;end
        if b>0;append!(links,(UInt32(u-1),UInt32(v-1)|both|0x80000000));unique_switching+=1;end
    end
    empty!(pairs)
    components=connected_components(undirected);sort!(components;by=c->(-length(c),first(c)))
    boxes=component_boxes(components);positions=zeros(Float32,2,n)
    component_id=zeros(UInt32,n)
    for (index,vertices) in enumerate(components)
        sort!(vertices);localgraph,_=induced_subgraph(undirected,vertices)
        coordinates=project_component(localgraph)
        x,y,w,h=boxes[index];margin=0.04
        for axis in 1:2
            low,high=extrema(@view coordinates[:,axis]);span=max(high-low,1f-4)
            for (j,id) in enumerate(vertices)
                t=(coordinates[j,axis]-low)/span
                jitter=noise(id,axis==1 ? 0x123456789abcdef0 : 0xfedcba9876543210)*min(0.04,0.5/sqrt(length(vertices)))
                t=clamp(margin+(1-2margin)*t+jitter,0.01,0.99)
                positions[axis,id]=axis==1 ? x+w*t : y+h*t
                component_id[id]=index
            end
        end
    end
    strong=strongly_connected_components(graph);strong_sizes=sort!(length.(strong);rev=true)
    version=Dates.format(now(UTC),"yyyymmddTHHMMSS")*"-"*string(completed)*"-"*string(paths)
    staging=joinpath(output,".building-"*version);mkpath(staging)
    write_binary(joinpath(staging,"positions.bin"),vec(positions))
    write_binary(joinpath(staging,"edges.bin"),links)
    write_binary(joinpath(staging,"flags.bin"),UInt8[p.seed for p in parents])
    in_count=UInt32.(indegree(graph));out_count=UInt32.(outdegree(graph));chunk_size=2048
    for chunk_first in 1:chunk_size:n
        chunk_last=min(n,chunk_first+chunk_size-1)
        data=[Dict("id"=>p.id,"is_seed"=>p.seed,"source"=>p.source,"sha256"=>p.sha,
            "incoming"=>in_count[p.id],"outgoing"=>out_count[p.id],"component"=>component_id[p.id],
            "v5_returns"=>self_v5[p.id],"switching_returns"=>self_switching[p.id]) for p in parents[chunk_first:chunk_last]]
        atomic_json(joinpath(staging,"nodes-"*string((chunk_first-1)÷chunk_size)*".json"),data)
    end
    summary=Dict{String,Any}("schema"=>SCHEMA,"version"=>version,"snapshot_utc"=>snapshot,
        "builder_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "built_utc"=>string(now(UTC))*"Z","completed_parents"=>completed,"nodes"=>n,
        "seeds"=>count(p->p.seed,parents),"v5_edges"=>unique_v5,"switching_edges"=>unique_switching,
        "directed_pairs"=>ne(graph),"observations"=>paths,"pending_observations"=>pending,
        "components"=>length(components),"largest_component"=>length(first(components)),
        "signature_collision_buckets"=>collisions,
        "largest_strong_component"=>first(strong_sizes),"metadata_chunk_size"=>chunk_size,
        "layout"=>"deterministic landmark-distance projection, PCA, and separate component rectangles",
        "layout_seconds"=>time()-started-sql_seconds,"sql_seconds"=>sql_seconds,
        "refresh_every_completions"=>every_seeds,"minimum_refresh_seconds"=>min_seconds,
        "run"=>abspath(run),"semantics"=>"Observed construction graph of quadratic APN CCZ/EA classes; incomplete coverage.")
    atomic_json(joinpath(staging,"manifest.json"),summary)
    final=joinpath(output,version);mv(staging,final)
    summary["compute_seconds"]=time()-started
    summary["payload_bytes"]=sum(stat(joinpath(final,name)).size for name in ("positions.bin","edges.bin","flags.bin"))
    atomic_json(joinpath(output,"current.json"),summary)
    snapshots=sort!([name for name in readdir(output) if occursin(r"^\d{8}T\d{6}-\d+-\d+$",name) && isdir(joinpath(output,name))])
    for old in snapshots[1:max(0,length(snapshots)-3)]
        rm(joinpath(output,old);recursive=true)
    end
    println(JSON3.write(summary));flush(stdout)
    summary
end

function main(args=ARGS)
    options=Dict("--every-seeds"=>"500","--min-seconds"=>"600");once=false;i=1
    while i<=length(args)
        if args[i]=="--once";once=true;i+=1;continue;end
        args[i] in ("--run","--output","--every-seeds","--min-seconds") || error("unknown option")
        i<length(args) || error("missing option value");options[args[i]]=args[i+1];i+=2
    end
    run=abspath(options["--run"]);output=abspath(get(options,"--output",joinpath(run,"graph")))
    every=parse(Int,options["--every-seeds"]);minimum=parse(Int,options["--min-seconds"])
    every>0 && minimum>=0 || error("invalid refresh policy")
    mkpath(output)
    while true
        try
            due=refresh_due(output,completion_count(run);every_seeds=every,min_seconds=minimum)
            (once || due) && build(run,output;every_seeds=every,min_seconds=minimum)
            isfile(joinpath(output,"worker-error.json")) && rm(joinpath(output,"worker-error.json"))
        catch error
            atomic_json(joinpath(output,"worker-error.json"),Dict("utc"=>string(now(UTC))*"Z","error"=>sprint(showerror,error)))
            @error "graph snapshot failed; retaining previous snapshot" exception=(error,catch_backtrace())
            once && rethrow()
        end
        once && break
        sleep(30)
    end
end
end
if abspath(PROGRAM_FILE)==@__FILE__;APNClosureGraph.main();end
