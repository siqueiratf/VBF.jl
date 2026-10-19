"""Measure method connectivity and directed reachability of a frozen graph export.

Reads the inspector's immutable binary snapshot, without opening the campaign
ledger. Nodes are admitted classes; these are observed construction relations,
not equivalence edges. No APN algorithm is implemented here.
"""
module ConstructionConnectivity
using Graphs, JSON3, SHA, Dates

function representative!(parents, x)
    while parents[x] != x
        parents[x] = parents[parents[x]]
        x = Int(parents[x])
    end
    x
end

function merge!(parents, sizes, u, v)
    a, b = representative!(parents,u), representative!(parents,v)
    a == b && return false
    sizes[a] < sizes[b] && ((a,b)=(b,a))
    parents[b] = a
    sizes[a] += sizes[b]
    true
end

function weak_summary(parents,sizes,seeds)
    roots=findall(i->parents[i]==i,eachindex(parents))
    largest=roots[argmax(sizes[roots])]
    seed_counts=Dict{Int,Int}()
    for i in eachindex(seeds)
        seeds[i]==0 && continue
        r=representative!(parents,i)
        seed_counts[r]=get(seed_counts,r,0)+1
    end
    Dict("components"=>length(roots),"largest_component"=>Int(sizes[largest]),
         "seeds_in_largest"=>get(seed_counts,largest,0),
         "components_containing_seeds"=>length(seed_counts),
         "largest_sizes"=>sort!(Int.(sizes[roots]);rev=true)[1:min(10,length(roots))])
end

function analyze(snapshot)
    manifest=JSON3.read(read(joinpath(snapshot,"manifest.json"),String),Dict{String,Any})
    n=Int(manifest["nodes"])
    edge_bytes=read(joinpath(snapshot,"edges.bin"));edges=ltoh.(reinterpret(UInt32,edge_bytes))
    seeds=read(joinpath(snapshot,"flags.bin"))
    length(seeds)==n && length(edges)%2==0 || error("invalid binary snapshot")
    parents=UInt32.(1:n);sizes=ones(UInt32,n)
    switching=Tuple{Int,Int}[];outgoing=falses(n)
    graph=SimpleDiGraph(n)
    for i in 1:2:length(edges)
        u=Int(edges[i])+1;v=Int(edges[i+1]&0x3fffffff)+1
        1<=u<=n && 1<=v<=n || error("invalid edge node")
        outgoing[u]=true
        add_edge!(graph,u,v)
        if edges[i+1]&0x80000000==0
            merge!(parents,sizes,u,v)
        else
            push!(switching,(u,v))
        end
    end
    v5_only=weak_summary(parents,sizes,seeds)
    essential_switches=0
    for (u,v) in switching
        essential_switches+=merge!(parents,sizes,u,v)
    end
    combined=weak_summary(parents,sizes,seeds)
    combined["components"]==manifest["components"] || error("component count differs from published graph")
    components=strongly_connected_components(graph)
    largest=components[argmax(length.(components))]
    length(largest)==manifest["largest_strong_component"] || error("strong component differs from published graph")
    first_seed=findfirst(!iszero,seeds)
    distances=gdistances(graph,first_seed)
    reached=distances .!= typemax(Int)
    reached_seeds=count(i->seeds[i]!=0 && reached[i],eachindex(seeds))
    reachable_distances=distances[reached]
    report=Dict("schema"=>"vbfsearch-construction-connectivity-v1",
        "generated_utc"=>string(now(UTC))*"Z","graph_snapshot"=>manifest,
        "edges_sha256"=>bytes2hex(SHA.sha256(edge_bytes)),
        "analysis_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "nodes"=>n,"seeds"=>count(!iszero,seeds),"v5_only"=>v5_only,"combined"=>combined,
        "switching_component_merges"=>essential_switches,
        "nodes_with_observed_outgoing_edges"=>count(outgoing),
        "strong_components"=>length(components),"largest_strong_component"=>length(largest),
        "seeds_in_largest_strong_component"=>count(i->seeds[i]!=0,largest),
        "first_seed_reachability"=>Dict("seed_id"=>first_seed,"classes"=>count(reached),
            "seeds"=>reached_seeds,"maximum_observed_shortest_path"=>maximum(reachable_distances)),
        "scope"=>"Frozen observed graph, including published roots and catalog-matching classes; incomplete expansion. Weak connectivity ignores arrow directions. Reachability inserts recorded equivalences between representatives where required.")
    report
end
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    length(ARGS)==2 || error("usage: construction_connectivity.jl SNAPSHOT_DIRECTORY OUTPUT_JSON")
    report=ConstructionConnectivity.analyze(abspath(ARGS[1]))
    open(io->ConstructionConnectivity.JSON3.write(io,report),ARGS[2],"w")
    println(ConstructionConnectivity.JSON3.write(report))
end
