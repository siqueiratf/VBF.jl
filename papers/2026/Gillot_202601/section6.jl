# Implements 6 — Switchings; Fact 3.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 6 — Switchings; Fact 3
#
# Pseudocode:
#   1. Audit portable complete switching evidence against its certified 716-representative census.
#   2. Check kernel metadata, every graph witness and selected freshly regenerated parity systems.
# VBF API used: apn_extension_space, apn_extensions, differential_uniformity, rank_f2

if !isdefined(@__MODULE__,:gl_kappa)
    include("helpers.jl")
end

"""Audit portable completed one-coordinate closure evidence, GL Section 6, Fact 3."""
function gl_section6(;checkpoint_path="",census_path="",limit=716,max_evaluations=30000,
    timeout_seconds=60,fresh_samples=2,max_nodes=100000,save_results=false)
    started=time_ns()
    if isempty(checkpoint_path)
        F=gold_apn(4)
        G=VBFTable{4,3}(Int.(F.lut).>>1)
        outcome=apn_extensions(G;max_nodes,max_solutions=max_evaluations,timeout_seconds)
        r=(;parameters=(;limit,max_evaluations,timeout_seconds,fresh_samples,max_nodes,checkpoint_file=checkpoint_path,census_file=census_path),complete=outcome isa Exhausted,processed=length(search_solutions(outcome)),
            loaded=false,scope="one finite four-bit projection",
            nodes=nodes_visited(outcome),elapsed_seconds=(time_ns()-started)*1e-9,
            stop_reason=outcome isa BudgetHit ? outcome.where_it_stopped.reason : :none)
        gl_save("section6_demo",r;save_results)
        return r
    end
    summary=TOML.parsefile(checkpoint_path)
    checkpoint_directory=summary["checkpoint_directory"]
    basename(checkpoint_directory)==checkpoint_directory && checkpoint_directory ∉ (".","..") ||
        throw(ArgumentError("checkpoint directory must be a single local path component"))
    directory=joinpath(dirname(checkpoint_path),checkpoint_directory)
    isempty(census_path) && (census_path=joinpath(dirname(checkpoint_path),"section32.toml"))
    known=gl_load_known_representatives(census_path)
    known.sha256==summary["census_sha256"] || error("checkpoint is bound to a different census")
    hashes=Dict{String,String}()
    rows=NamedTuple[]
    edges=Set{Tuple{Int,Int}}()
    verified_neighbors=0
    directions=0
    basis_count=0
    parents=0
    stage_complete=true
    fresh=NamedTuple[]
    for i in 1:min(limit,get(summary,"parents_processed",0))
        if (time_ns()-started)*1e-9>=timeout_seconds || verified_neighbors>=max_evaluations
            stage_complete=false
            break
        end
        path=joinpath(directory,"parent_$(lpad(i,3,'0')).toml")
        data=TOML.parsefile(path)
        hashes[basename(path)]=bytes2hex(sha256(read(path)))
        data["complete"] && data["constructor_complete"] || (stage_complete=false)
        parent=SBox{6}(data["parent_lut"])
        data["parent_index"]==i && parent==known.representatives[i] || error("checkpoint parent does not match its census index")
        data["census_sha256"]==known.sha256 || error("parent checkpoint has different census provenance")
        source_index=data["source_root_index"]
        1<=source_index<=14 && known.root_order[source_index]==known.root_labels[i] ||
            error("checkpoint parent root index disagrees with the census")
        differential_uniformity(parent)==2 || error("invalid checkpoint APN parent")
        histogram=Dict{Int,Int}()
        Set(d["direction"] for d in data["directions"])==Set(1:63) &&
            length(data["directions"])==63 || error("checkpoint directions do not cover all63 projections")
        length(data["records"])==data["neighbors"]==sum(d["neighbors"] for d in data["directions"]) ||
            error("checkpoint completion counts disagree")
        length(Set(Tuple(r["candidate_lut"]) for r in data["records"]))==length(data["records"]) ||
            error("duplicate checkpoint completions")
        for d in data["directions"]
            raw=d["raw_dimension"]
            quotient=d["quotient_dimension"]
            raw==12+quotient && d["trivial_dimension"]==12 || error("invalid switching kernel metadata")
            0<=quotient<=52 && d["evaluations"]==big(2)^quotient-1 &&
                d["neighbors"]==d["evaluations"] || error("incomplete switching quotient coverage metadata")
            histogram[quotient]=get(histogram,quotient,0)+1
            directions+=1
            basis_count+=quotient
        end
        for record in data["records"]
            if verified_neighbors>=max_evaluations || (time_ns()-started)*1e-9>=timeout_seconds
                stage_complete=false
                break
            end
            record["status"]=="matched" || error("checkpoint contains an unresolved completion")
            w=record["witness"]
            F,G=SBox{6}(w["source_lut"]),SBox{6}(w["target_lut"])
            target_index=record["root_index"]
            1<=target_index<=14 && G==known.roots[known.root_order[target_index]] ||
                error("loaded witness does not target its named census root")
            F.lut==UInt8.(record["candidate_lut"]) || error("candidate and witness disagree")
            A=F2AffineMap{12,UInt32}(w["linear_columns"],w["constant"])
            gl_verify_graph_map(F,G,A;relation=:ccz) || error("invalid loaded switching certificate")
            differential_uniformity(F)==2 || error("loaded completion is not APN")
            differences=unique(xor.(F.lut,parent.lut))
            nonzero=filter(!iszero,differences)
            length(nonzero)==1 && all(v->v==0 || v==first(nonzero),differences) ||
                error("completion is not a one-coordinate switch of its parent")
            source,target=data["source_root_index"],record["root_index"]
            push!(edges,minmax(source,target))
            verified_neighbors+=1
        end
        if length(fresh)<fresh_samples
            remaining=timeout_seconds-(time_ns()-started)*1e-9
            G=VBFTable{6,5}(Int.(parent.lut).>>1)
            outcome=apn_extension_space(G;max_nodes,timeout_seconds=max(0,remaining))
            if outcome isa Exhausted
                space=only(search_solutions(outcome))
                push!(fresh,(;parent=i,complete=true,kernel_dimension=space.kernel_dimension,
                    quotient_dimension=space.normalized_dimension))
            else
                push!(fresh,(;parent=i,complete=false,kernel_dimension=-1,quotient_dimension=-1))
            end
        end
        push!(rows,(;parent=i,source_root=data["source_root_index"],histogram,
            raw_neighbors=data["neighbors"],basis_directions=sum(k*v for (k,v) in histogram)))
        parents+=1
        stage_complete || break
    end
    components=Vector{Int}[]
    unseen=Set(1:14)
    while !isempty(unseen)
        queue=[minimum(unseen)]
        component=Int[]
        while !isempty(queue)
            v=popfirst!(queue)
            v in unseen || continue
            delete!(unseen,v)
            push!(component,v)
            for (a,b) in edges
                a==v && b in unseen && push!(queue,b)
                b==v && a in unseen && push!(queue,a)
            end
        end
        push!(components,sort!(component))
    end
    complete=summary["complete"] && stage_complete && parents==716 && directions==45108 &&
        verified_neighbors==summary["evaluations"]
    r=(;parameters=(;limit,max_evaluations,timeout_seconds,fresh_samples,max_nodes,checkpoint_file=checkpoint_path,census_file=census_path),complete,processed=parents,loaded=true,source_sha256=bytes2hex(sha256(read(checkpoint_path))),
        checkpoint_hashes=hashes,loaded_algorithm_source_hashes=get(summary,"source_hashes",Dict()),
        directions,basis_count,verified_neighbors,rows,fresh,
        graph_edges=[collect(e) for e in sort!(collect(edges))],components,
        loaded_components=summary["components"],graph_components_agree=components==summary["components"],
        coverage_basis="loaded full constructor metadata; every graph witness rechecked; selected parity systems freshly regenerated",
        paper_basis_apn_count=11598,basis_apn_agrees=complete && basis_count==11598,
        class_column_verified=false,class_column_note="basis/particular-solution dependent; full-combination closure is certified",
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :budget)
    gl_save("section6",r;save_results)
    return r
end

function gl_section6_report(io::IO=stdout;kwargs...)
    return gl_report("Section 6 — one-coordinate closure",gl_section6(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_section6_report()
end
