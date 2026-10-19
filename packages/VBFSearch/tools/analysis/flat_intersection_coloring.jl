"""Replayable three-color obstructions to two-coordinate APN completion.

Let C be all decomposable flats annihilating U6. A completion adds two linear
functionals on C, whose joint values must be nonzero elements of F2^2. If two flats meet
in an input point, their sum is a third flat in C. Equal nonzero joint values
on the first two would give zero on the third. Hence the intersection graph
of C must be three-colorable. A verified exhaustive coloring contradiction is
therefore a necessary-condition certificate excluding the entire U6.

Removing vertices of degree at most two preserves three-colorability. The
remaining graph is tested by bounded deterministic DSATUR. Every reported
contradiction includes a branching proof: all currently allowed colors are
covered, and each leaf exhibits an uncolored vertex with all three colors
already present among its neighbors. A separate proof replayer checks it.
Budget exhaustion is explicitly unknown. A successful coloring is no claim
that the two functionals exist: this graph test omits other linear relations.
"""
module FlatIntersectionColoring
using VBF, JSON3, SHA, Random, Dates
include("u6_obstructions.jl")
const O=U6Obstructions
const Q=VBF.QuadraticExtensions

"Construct the exact residual-flat intersection graph from VBF incidences."
function intersection_graph(G,indices)
    points=[Int[] for _ in 1:1<<G.n]
    for (vertex,fi) in enumerate(indices),p in G.flatpts[fi]
        push!(points[p+1],vertex)
    end
    adjacency=[Int[] for _ in indices]
    for vertices in points,i in 1:length(vertices)-1,j in i+1:length(vertices)
        a,b=vertices[i],vertices[j]
        push!(adjacency[a],b);push!(adjacency[b],a)
    end
    foreach(sort!,adjacency)
    adjacency
end

"Peel the two-degenerate part; an unsatisfiable induced core suffices."
function three_core(adjacency)
    degrees=length.(adjacency);alive=trues(length(adjacency))
    queue=findall(<=(2),degrees);cursor=1
    while cursor<=length(queue)
        v=queue[cursor];cursor+=1
        alive[v] || continue
        alive[v]=false
        for neighbor in adjacency[v]
            alive[neighbor] || continue
            degrees[neighbor]-=1
            degrees[neighbor]==2 && push!(queue,neighbor)
        end
    end
    findall(alive)
end

"Allowed colors under one partial proper coloring."
function allowed_colors(adjacency,colors,v)
    mask=UInt8(7)
    for neighbor in adjacency[v]
        color=colors[neighbor]
        color==0 || (mask&=~(UInt8(1)<<(color-1)))
    end
    Int[c for c in 1:3 if !iszero(mask&(UInt8(1)<<(c-1)))]
end

"Replay every branch and blocked-vertex leaf without using DSATUR decisions."
function replay_unsat(adjacency,vertices,seeds,proof)
    colors=zeros(Int,length(adjacency));allowed_vertices=Set(vertices)
    function walk(node)
        vertex=Int(node["vertex"])
        vertex in allowed_vertices && colors[vertex]==0 || return false
        allowed=allowed_colors(adjacency,colors,vertex)
        if node["kind"]=="blocked"
            return isempty(allowed)
        end
        node["kind"]=="branch" || return false
        Int.(node["colors"])==allowed || return false
        length(node["children"])==length(allowed) || return false
        for (color,child) in zip(allowed,node["children"])
            colors[vertex]=color
            ok=walk(child)
            colors[vertex]=0
            ok || return false
        end
        true
    end
    # A single vertex may be fixed to color one by permutation symmetry. Its
    # neighbor may additionally be fixed to color two by swapping colors 2/3.
    length(seeds)==2 || return false
    first,second=seeds
    first[1] in allowed_vertices && second[1] in allowed_vertices || return false
    first[1]!=second[1] && first[2]==1 && second[2]==2 || return false
    second[1] in adjacency[first[1]] || return false
    colors[first[1]]=1;colors[second[1]]=2
    walk(proof)
end

"Bounded exact search; unknown never establishes an obstruction."
function coloring_obstruction(adjacency;max_nodes=10_000,max_seconds=0.02)
    vertices=three_core(adjacency)
    isempty(vertices) && return (;status="two_degenerate",vertices,seeds=Tuple{Int,Int}[],
        proof=nothing,nodes=0,seconds=0.0)
    colors=zeros(Int,length(adjacency));start=time_ns();nodes=Ref(0)
    seedvertex=vertices[argmax(length(adjacency[v]) for v in vertices)]
    second=first(v for v in adjacency[seedvertex] if v in vertices)
    seeds=[(seedvertex,1),(second,2)]
    colors[seedvertex]=1;colors[second]=2
    function visit()
        nodes[]>=max_nodes && return ("unknown_nodes",nothing)
        (nodes[]&63)==0 && (time_ns()-start)*1e-9>=max_seconds && return ("unknown_time",nothing)
        nodes[]+=1
        chosen=0;best_saturation=-1;best_degree=-1;chosen_allowed=Int[]
        for v in vertices
            colors[v]==0 || continue
            allowed=allowed_colors(adjacency,colors,v)
            isempty(allowed) && return ("unsat",Dict("kind"=>"blocked","vertex"=>v))
            saturation=3-length(allowed);degree=length(adjacency[v])
            if saturation>best_saturation || saturation==best_saturation && degree>best_degree
                chosen=v;best_saturation=saturation;best_degree=degree;chosen_allowed=allowed
            end
        end
        chosen==0 && return ("colorable",nothing)
        children=Any[]
        for color in chosen_allowed
            colors[chosen]=color
            status,proof=visit()
            colors[chosen]=0
            status=="unsat" || return (status,proof)
            push!(children,proof)
        end
        ("unsat",Dict("kind"=>"branch","vertex"=>chosen,
            "colors"=>chosen_allowed,"children"=>children))
    end
    status,proof=visit()
    status=="unsat" && !replay_unsat(adjacency,vertices,seeds,proof) &&
        error("coloring contradiction failed independent proof replay")
    (;status,vertices,seeds,proof,nodes=nodes[],seconds=(time_ns()-start)*1e-9)
end

"Repeat the existing Fano pilot's probability sampling for a direct comparison."
function pilot(samplepath,oldpilotpath,output;max_seconds=90.0)
    source=read(samplepath);parentsdoc=JSON3.read(String(copy(source)),Dict{String,Any})
    previous=JSON3.read(read(oldpilotpath,String),Dict{String,Any})
    previous["sample_sha256"]==bytes2hex(sha256(source)) || error("pilot input mismatch")
    parents=[p for p in parentsdoc["parents"] if p["uniform_parent_sample"] && p["queued_parent"]]
    rng=Xoshiro(previous["seed"]);shuffle!(rng,parents)
    resize!(parents,min(previous["requested_parents"],length(parents)))
    G=Q.geometry(8);rank_table=Q.PolarRankTable(G);buf=Int32[]
    coloring_obstruction([[j for j in 1:4 if i!=j] for i in 1:4];max_seconds=Inf)
    records=Dict{String,Any}[];start=time_ns()
    for (pi,parent) in enumerate(parents)
        (time_ns()-start)*1e-9>=max_seconds && break
        spaces=parent["maximizing_v5_forms"];vi=rand(rng,1:length(spaces))
        V=UInt32.(spaces[vi]);need=Int(parent["need"])
        old=previous["records"][pi]
        parent["parent_id"]==old["parent_id"] && vi==old["sampled_v5_index"] || error("sampling plan drift")
        r=Q.coset_bent_counts!(buf,G,V,Q.BETA8;rank_table)
        X=UInt32[i-1 for i in 2:length(buf) if buf[i]==need*r.scale]
        chosen=randperm(rng,length(X))[1:min(old["sampled_cosets"],length(X))]
        C=O.flat_indices(G,V);outcomes=Dict{String,Int}();certificates=Any[]
        core_nonempty=0;search_nodes=0;color_seconds=0.0
        for xi in chosen
            x=Q.lift(X[xi],r.Qmask);U=first(Q.rref(vcat(V,x)))
            indices=[fi for fi in C if !Q.par(G.flats[fi]&x)]
            oldresult=O.inspect(G,U,indices)
            if oldresult.status=="existing_du_obstruction"
                outcomes["existing_du_obstruction"]=get(outcomes,"existing_du_obstruction",0)+1
                continue
            end
            adjacency=intersection_graph(G,indices)
            result=coloring_obstruction(adjacency)
            isempty(result.vertices) || (core_nonempty+=1)
            search_nodes+=result.nodes;color_seconds+=result.seconds
            label=result.status=="unsat" ?
                oldresult.status=="singular_three_space" ? "fano_and_graph_unsat" : "additional_graph_unsat" : result.status
            outcomes[label]=get(outcomes,label,0)+1
            if result.status=="unsat"
                push!(certificates,Dict("U"=>Int.(U),"coset_index"=>xi,
                    "flat_geometry_indices"=>indices,"core_vertices"=>result.vertices,
                    "seeds"=>result.seeds,"proof"=>result.proof,"label"=>label,
                    "nodes"=>result.nodes))
            elseif oldresult.status=="singular_three_space"
                error("known Fano obstruction was not proved by bounded coloring")
            end
        end
        push!(records,Dict("parent_id"=>parent["parent_id"],"sampled_v5_index"=>vi,
            "sampled_cosets"=>length(chosen),"outcomes"=>outcomes,
            "nonempty_three_cores"=>core_nonempty,"search_nodes"=>search_nodes,
            "coloring_seconds"=>color_seconds,"certificates"=>certificates))
        println(JSON3.write(Dict(k=>v for (k,v) in last(records) if k!="certificates")))
    end
    aggregate=Dict{String,Int}()
    for record in records,(key,value) in record["outcomes"]
        aggregate[key]=get(aggregate,key,0)+value
    end
    report=Dict("schema"=>"flat-intersection-coloring-pilot-v1",
        "sample_sha256"=>bytes2hex(sha256(source)),"tool_sha256"=>bytes2hex(open(sha256,@__FILE__)),
        "old_pilot_sha256"=>bytes2hex(open(sha256,oldpilotpath)),
        "created_utc"=>string(Dates.now(Dates.UTC)),"parents"=>length(records),
        "complete"=>length(records)==length(parents),"outcomes"=>aggregate,
        "seconds"=>(time_ns()-start)*1e-9,"records"=>records,
        "scope"=>"Exactly the existing64-parent256-coset pilot; no APN completions or campaign writes")
    mkpath(dirname(output));open(output,"w") do io;JSON3.pretty(io,report);end
    println(JSON3.write(Dict(k=>v for (k,v) in report if k!="records")))
    report
end
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    length(ARGS)==3 || error("expected parents.json oldpilot.json output.json")
    FlatIntersectionColoring.pilot(ARGS...)
end
