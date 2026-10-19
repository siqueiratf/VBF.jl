"""Read-only exact incidence audit of saved maximizing component subspaces.

No APN extensions are enumerated. Each output state is a canonical (k+1)-space
inside the declared parent component space, and every containment is replayed.
"""
module FrontierIncidenceAudit
using VBF, JSON3, SHA, Dates, Statistics
include(joinpath(@__DIR__, "v5_frontier_symmetry_audit.jl"))
const QE=VBF.QuadraticExtensions
const FSA=V5FrontierSymmetryAudit

"All distinct one-dimensional extensions of V inside S, using VBF elimination."
function internal_extensions(S::Vector{UInt32},V::Vector{UInt32})
    S=first(QE.rref(S));V=first(QE.rref(V))
    length(V)<length(S) || throw(ArgumentError("extension needs a strict subspace"))
    first(QE.rref(vcat(S,V)))==S || throw(ArgumentError("space is outside parent"))
    extended=copy(V);complement=UInt32[]
    for s in S
        next=first(QE.rref(vcat(extended,s)))
        if length(next)>length(extended)
            push!(complement,s);extended=next
        end
    end
    length(extended)==length(S) || error("incomplete quotient complement")
    result=[first(QE.rref(vcat(V,q))) for q in QE.comp_forms(complement)[2:end]]
    length(unique(Tuple.(result)))==2^(length(S)-length(V))-1 || error("duplicate quotient line")
    return result
end

"Exact sibling incidence, optionally restricted to a bent count at dimension k+1."
function incidence_records(G,S,spaces;target_bent=nothing)
    S=first(QE.rref(S));components=QE.comp_forms(S)
    bent=Dict(q=>QE.form_rank(G,q)==G.n for q in components)
    state_spaces=Dict{Tuple,Vector{Int}}()
    all_states=Set{Tuple}()
    incidence=0
    for (i,V) in enumerate(spaces)
        for U in internal_extensions(S,UInt32.(V))
            key=Tuple(U);push!(all_states,key)
            count_bent=count(q->bent[q],QE.comp_forms(U))
            target_bent===nothing || count_bent==target_bent || continue
            push!(get!(state_spaces,key,Int[]),i);incidence+=1
        end
    end
    per_space_savings=zeros(Int,length(spaces))
    for inds in values(state_spaces),i in inds[2:end]
        per_space_savings[i]+=1
    end
    return (;state_spaces,all_states,incidence,per_space_savings,
        distinct_states=length(state_spaces),
        repeated_incidence=incidence-length(state_spaces),
        shared_states=count(v->length(v)>1,values(state_spaces)),
        coincident_sibling_pairs=sum(v->binomial(length(v),2),values(state_spaces);init=0))
end

function parent_space(G,parent)
    F=SBox{G.n,UInt8}(hex2bytes(parent["lut_hex"]))
    a=anf(F)
    coefficients=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:G.n-1 for j in i+1:G.n-1]
    return first(QE.rref(QE.coord_forms(coefficients,G.n)))
end

function totals(records)
    fields=("parents","v5_spaces","eligible_internal_u6_incidence","distinct_internal_u6",
        "repeated_internal_u6_incidence","shared_internal_u6","coincident_v5_pairs")
    result=Dict(k=>0 for k in fields)
    result["parents"]=length(records)
    for record in records,k in fields[2:end]
        result[k]+=record[k]
    end
    return result
end

"Find every exact shared U6 among supplied V5s via their common V4 hyperplanes."
function shared_extensions(G,spaces;target_bent=52,max_seconds=300.0)
    started=time();basis_to_indices=Dict{NTuple{5,UInt32},Vector{Int}}()
    for (i,record) in enumerate(spaces)
        key=Tuple(UInt32.(record["forms"]))
        length(key)==5 || error("expected dimension five")
        push!(get!(basis_to_indices,key,Int[]),i)
    end
    bases=sort!(collect(keys(basis_to_indices)))
    first_owner=Dict{NTuple{4,UInt32},Int}()
    collisions=Dict{NTuple{4,UInt32},Vector{Int}}()
    completed=0
    for (i,basis) in enumerate(bases)
        time()-started<max_seconds || break
        comp=QE.comp_forms(collect(basis))
        hyperplanes=QE.subspaces_of_comp(comp,falses(32),4;keep=nb->true)
        length(hyperplanes)==31 || error("V5 must have 31 hyperplanes")
        for record in hyperplanes
            key=Tuple(first(QE.rref(record.forms)))
            if haskey(first_owner,key)
                owners=get!(collisions,key) do; [first_owner[key]]; end
                push!(owners,i)
            else
                first_owner[key]=i
            end
        end
        completed=i
    end
    indexed_seconds=time()-started
    states=Dict{NTuple{6,UInt32},Set{Int}}();pairs=0
    for owners in values(collisions)
        for a in 1:length(owners)-1,b in a+1:length(owners)
            pairs+=1;i=owners[a];j=owners[b]
            U=first(QE.rref(vcat(collect(bases[i]),collect(bases[j]))))
            length(U)==6 || error("distinct V5 hyperplanes must span U6")
            count(q->QE.form_rank(G,q)==G.n,QE.comp_forms(U))==target_bent || continue
            inds=get!(states,Tuple(U),Set{Int}());push!(inds,i);push!(inds,j)
        end
    end
    rows=Dict{String,Any}[];cross_states=0;cross_pairs=0
    for (key,inds) in states
        originals=sort!(reduce(vcat,(basis_to_indices[bases[i]] for i in inds)))
        parents=unique(spaces[i]["parent_id"] for i in originals)
        across=length(parents)>1;cross_states+=across
        # Count distinct V5 pairs whose declared-parent owner sets differ.
        for i in inds,j in inds
            i<j || continue
            pi=Set(spaces[k]["parent_id"] for k in basis_to_indices[bases[i]])
            pj=Set(spaces[k]["parent_id"] for k in basis_to_indices[bases[j]])
            any(a!=b for a in pi,b in pj) && (cross_pairs+=1)
        end
        push!(rows,Dict("forms"=>Int.(collect(key)),"v5_indices"=>originals,
            "distinct_v5_count"=>length(inds),"parent_ids"=>sort!(collect(parents)),"cross_parent"=>across))
    end
    sort!(rows;by=r->Tuple(r["forms"]))
    return Dict("complete"=>completed==length(bases),"input_spaces"=>length(spaces),
        "distinct_exact_v5_spaces"=>length(bases),"indexed_v5_spaces"=>completed,
        "v4_incidence"=>completed*31,"distinct_v4_spaces"=>length(first_owner),
        "shared_v4_spaces"=>length(collisions),"intersecting_v5_pairs"=>pairs,
        "eligible_shared_u6"=>length(states),"eligible_shared_u6_across_parents"=>cross_states,
        "eligible_cross_parent_v5_pairs"=>cross_pairs,"states"=>rows,
        "index_seconds"=>indexed_seconds,"elapsed_seconds"=>time()-started)
end

function shared_audit(input,output;max_seconds=300.0)
    parents=FSA.read_json(joinpath(input,"parents.json"))["parents"]
    G=QE.geometry(8)
    for parent in parents;FSA.validate_prepared_parent(G,parent);end
    path=joinpath(input,"spaces.json");source=FSA.read_json(path)
    source["parents_sha256"]==FSA.file_sha(joinpath(input,"parents.json")) || error("parent binding mismatch")
    spaces=source["spaces"]
    by_parent=Dict(p["parent_id"]=>p for p in parents)
    for record in spaces
        parent=by_parent[record["parent_id"]]
        record["forms"]==parent["maximizing_v5_forms"][record["parent_v5_index"]] || error("space has wrong declared parent")
    end
    result=shared_extensions(G,spaces;max_seconds)
    result["schema"]="vbfsearch-frontier-v4-incidence-v1"
    result["spaces_sha256"]=FSA.file_sha(path)
    result["parents_sha256"]=FSA.file_sha(joinpath(input,"parents.json"))
    result["tool_sha256"]=FSA.file_sha(@__FILE__)
    result["all_declared_parent_containments_replayed"]=true
    result["coverage_claim"]="Exact shared U6 identity only; completed search coverage is not claimed."
    FSA.write_json(joinpath(output,"v4-incidence.json"),result)
    return result
end

function audit(input,output;max_seconds=300.0)
    started=time();mkpath(output)
    source=joinpath(input,"parents.json")
    saved=FSA.read_json(source);saved["complete"] || error("incomplete source")
    parents=saved["parents"];G=QE.geometry(8)
    records=Dict{String,Any}[]
    state_parents=Dict{Tuple,Vector{Tuple{Int,Int}}}()
    proxy_path=joinpath(input,"report.json")
    proxies=FSA.read_json(proxy_path)["work_proxies"]
    proxy_dict=Dict((p["parent_id"],p["parent_v5_index"])=>p for p in proxies)
    proxy_results=Dict{String,Any}[]
    for parent in parents
        time()-started<max_seconds || break
        FSA.validate_prepared_parent(G,parent)
        S=parent_space(G,parent)
        result=incidence_records(G,S,parent["maximizing_v5_forms"];target_bent=52)
        record=Dict{String,Any}(k=>parent[k] for k in
            ("parent_id","origin","b5","queue_state","uniform_parent_sample","sample_designs"))
        record["v5_spaces"]=length(parent["maximizing_v5_forms"])
        record["internal_u6_before_bent_filter"]=length(result.all_states)
        record["eligible_internal_u6_incidence"]=result.incidence
        record["distinct_internal_u6"]=result.distinct_states
        record["repeated_internal_u6_incidence"]=result.repeated_incidence
        record["shared_internal_u6"]=result.shared_states
        record["coincident_v5_pairs"]=result.coincident_sibling_pairs
        record["saved_cosets_by_v5_index"]=result.per_space_savings
        for (key,inds) in result.state_spaces
            push!(get!(state_parents,key,Tuple{Int,Int}[]),(parent["parent_id"],length(inds)))
        end
        for i in eachindex(result.per_space_savings)
            key=(parent["parent_id"],i);haskey(proxy_dict,key) || continue
            proxy=proxy_dict[key]
            push!(proxy_results,merge(Dict{String,Any}(proxy),Dict(
                "internal_sibling_cosets_saved"=>result.per_space_savings[i],
                "maximum_possible_shared_cosets"=>7,
                "internal_sibling_fraction_of_all_eligible_cosets"=>result.per_space_savings[i]/proxy["eligible_cosets"],
                "universal_internal_overlap_upper_fraction"=>7/proxy["eligible_cosets"])))
        end
        push!(records,record)
        if length(records)%128==0
            println(JSON3.write(Dict("event"=>"incidence_parents","completed"=>length(records),"elapsed_seconds"=>time()-started)));flush(stdout)
        end
    end
    uniform=[r for r in records if r["uniform_parent_sample"]]
    queued=[r for r in uniform if r["queue_state"]!="complete"]
    cross=[Dict("forms"=>Int.(collect(key)),"parent_incidence"=>[collect(p) for p in owners])
        for (key,owners) in state_parents if length(owners)>1]
    sort!(cross;by=r->Tuple(r["forms"]))
    result=Dict("schema"=>"vbfsearch-frontier-internal-incidence-v1",
        "created_utc"=>string(now(UTC)),"complete"=>length(records)==length(parents),
        "elapsed_seconds"=>time()-started,"parents_sha256"=>FSA.file_sha(source),
        "source"=>abspath(input),"tool_sha256"=>FSA.file_sha(@__FILE__),
        "implementation"=>FSA.implementation(),
        "all_parent_containments_and_bent_profiles_replayed"=>true,
        "internal_extensions_per_v5"=>7,
        "all_sampled_parents"=>totals(records),"uniform_parent_sample"=>totals(uniform),
        "uniform_queued_parent_sample"=>totals(queued),
        "distinct_u6_across_all_sampled_parents"=>length(state_parents),
        "u6_shared_between_sampled_parents"=>length(cross),
        "additional_cross_parent_repeated_u6"=>sum(r->length(r["parent_incidence"])-1,cross;init=0),
        "work_proxies"=>proxy_results,"parents"=>records,
        "limitations"=>["Only states inside sampled parent component spaces are covered; external U6 states are excluded.",
            "Bent count 52 and shared containment certify identical state identity, not completed search coverage.",
            "Eligible cosets are a work proxy, not measured CPU time. The 16 proxy spaces are a separate two-stage subsample.",
            "All maximizing spaces within a parent are clustered observations. Supplements are descriptive and excluded from uniform estimates."])
    FSA.write_json(joinpath(output,"report.json"),result)
    FSA.write_json(joinpath(output,"cross-parent-u6.json"),Dict("parents_sha256"=>FSA.file_sha(source),"states"=>cross))
    return result
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS) in (2,3,4) || error("expected INPUT OUTPUT [MAX_SECONDS] [siblings|shared]")
    mode=length(ARGS)==4 ? ARGS[4] : "siblings"
    mode in ("siblings","shared") || error("unknown mode")
    action=mode=="siblings" ? audit : shared_audit
    result=action(ARGS[1],ARGS[2];max_seconds=length(ARGS)>=3 ? parse(Float64,ARGS[3]) : 300.0)
    println(JSON3.write(Dict(k=>result[k] for k in ("complete","elapsed_seconds"))))
end
end
