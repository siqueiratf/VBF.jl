"""Certified reuse of maximizing V5 jobs under automorphisms of their full parent.

Run with two threads and a bounded wall budget. This does not run extensions:
  julia --project=docs/inspector --threads=2 v5_parent_orbit_audit.jl \
    --input broad-symmetry --output broad-symmetry/parent-orbits --phase all

`--phase controls` checks the parents with known nontrivial V5 stabilizers first.
A partial native automorphism group still certifies its subgroup's reuse;
timeouts never prove that no further reuse exists.
"""
module V5ParentOrbitAudit
using VBF, JSON3, SHA, Statistics, Dates
include("v5_frontier_symmetry_audit.jl")
const FSA=V5FrontierSymmetryAudit
const Q=VBF.QuadraticExtensions

function configuration(args)
    opts=Dict("phase"=>"all","max-seconds"=>"300","solver-seconds"=>"1.0",
        "solver-nodes"=>"10000","solver-memory-mib"=>"512")
    iseven(length(args)) || throw(ArgumentError("expected --option value pairs"))
    for i in 1:2:length(args)
        startswith(args[i],"--") || throw(ArgumentError("expected --option"))
        key=args[i][3:end]
        key in ("input","output",keys(opts)...) || throw(ArgumentError("unknown option $key"))
        opts[key]=args[i+1]
    end
    all(k->haskey(opts,k),("input","output")) || throw(ArgumentError("missing --input or --output"))
    opts["phase"] in ("controls","all") || throw(ArgumentError("unknown phase"))
    config=(; input=abspath(opts["input"]),output=abspath(opts["output"]),phase=opts["phase"],
        max_seconds=parse(Float64,opts["max-seconds"]),solver_seconds=parse(Float64,opts["solver-seconds"]),
        solver_nodes=parse(Int,opts["solver-nodes"]),memory=parse(Int,opts["solver-memory-mib"])*1024^2)
    config.max_seconds>0 && config.solver_seconds>=0 && config.solver_nodes>=0 && config.memory>=0 ||
        throw(ArgumentError("invalid budget"))
    return config
end

"Full component space in the existing square-free VBF coordinates."
function component_space(G,F)
    a=anf(F)
    coefficients=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:G.n-1 for j in i+1:G.n-1]
    return first(Q.rref(Q.coord_forms(coefficients,G.n)))
end

"Exact subgroup orbits, with a replayed source-to-every-target input map."
function parent_space_orbits(G,parent_space,spaces,generators)
    S=first(Q.rref(UInt32.(parent_space)))
    domain=[first(Q.rref(UInt32.(V))) for V in spaces]
    isempty(domain) && throw(ArgumentError("maximizing-space domain must be nonempty"))
    d=length(first(domain))
    all(V->length(V)==d && first(Q.rref(vcat(S,V)))==S,domain) ||
        throw(ArgumentError("spaces must have equal dimensions and belong to the parent"))
    index=Dict(Tuple(V)=>i for (i,V) in enumerate(domain))
    length(index)==length(domain) || throw(ArgumentError("space domain must be distinct"))
    checked=Vector{UInt16}[];permutations=Vector{Int}[]
    for columns in generators
        verify_quadratic_space_transporter(G,S,S,columns) ||
            throw(ArgumentError("generator does not stabilize the full parent"))
        A=UInt16.(columns)
        A in checked && continue
        permutation=Int[]
        for V in domain
            image=transform_quadratic_space(G,V,A)
            target=get(index,Tuple(image),0)
            target>0 || throw(ArgumentError("maximizing-space domain is not closed"))
            push!(permutation,target)
        end
        length(unique(permutation))==length(domain) || error("nonbijective input action")
        push!(checked,A);push!(permutations,permutation)
    end
    roots=zeros(Int,length(domain));tree_parent=zeros(Int,length(domain));tree_generator=zeros(Int,length(domain))
    representatives=Int[];queue=Int[]
    for root in eachindex(domain)
        roots[root]==0 || continue
        push!(representatives,root);roots[root]=root
        empty!(queue);push!(queue,root);head=1
        while head<=length(queue)
            current=queue[head];head+=1
            for (g,permutation) in enumerate(permutations)
                child=permutation[current]
                roots[child]==0 || continue
                roots[child]=root;tree_parent[child]=current;tree_generator[child]=g
                push!(queue,child)
            end
        end
    end
    witnesses=Vector{UInt16}[]
    for target in eachindex(domain)
        path=Int[];i=target
        while tree_parent[i]!=0
            push!(path,tree_generator[i]);i=tree_parent[i]
        end
        columns=identity_linear_map(G.n,UInt16).cols
        for g in reverse(path)
            previous=F2LinearMap{G.n,UInt16}(columns)
            columns=UInt16[previous(c) for c in checked[g]]
        end
        verify_quadratic_space_transporter(G,domain[roots[target]],domain[target],columns) ||
            error("composed V5 orbit witness failed exact replay")
        verify_quadratic_space_transporter(G,S,S,columns) || error("composed parent witness failed replay")
        push!(witnesses,columns)
    end
    return (; representatives,representative_for=roots,input_columns_from_representative=witnesses,
        generators=checked,saved_jobs=length(domain)-length(representatives))
end

function audit_parent(G,parent,config;remaining_seconds=config.solver_seconds)
    M=Int(parent["maximizing_v5_count"])
    record=Dict{String,Any}("parent_id"=>parent["parent_id"],"origin"=>parent["origin"],
        "queue_state"=>parent["queue_state"],"uniform_parent_sample"=>parent["uniform_parent_sample"],
        "b5"=>parent["b5"],"need"=>parent["need"],"maximizing_v5_count"=>M)
    started=time_ns()
    F=SBox{8,UInt8}(hex2bytes(parent["lut_hex"]))
    S=component_space(G,F)
    if M==1
        # Regardless of the automorphism group there are no two distinct
        # maximizing spaces to identify. No automorphism search is necessary.
        generators=Vector{UInt16}[];group_complete=false;coverage_complete=true
        reason="single_maximizing_space";nodes=0
    else
        result=quadratic_space_stabilizers(G,S;max_nodes=config.solver_nodes,
            timeout_seconds=min(config.solver_seconds,max(0.0,remaining_seconds)),
            max_memory_bytes=config.memory)
        generators=result.generators;group_complete=result.complete;coverage_complete=result.complete
        reason=String(result.stop_reason);nodes=result.nodes_visited
    end
    orbits=parent_space_orbits(G,S,parent["maximizing_v5_forms"],generators)
    record["generator_count"]=length(generators)
    record["generators"]=[Int.(A) for A in generators]
    record["group_complete"]=group_complete
    record["reuse_calculation_complete"]=coverage_complete
    record["stop_reason"]=reason
    record["nodes_visited"]=nodes
    record["orbit_count"]=length(orbits.representatives)
    record["saved_jobs_certified"]=orbits.saved_jobs
    record["representative_v5_indices"]=orbits.representatives
    record["representative_for_v5_index"]=orbits.representative_for
    record["input_columns_from_representative"]=[Int.(A) for A in orbits.input_columns_from_representative]
    record["elapsed_seconds"]=(time_ns()-started)*1e-9
    return record
end

function rates(frame,records;queue_only=false)
    chosen=[r for r in records if r["uniform_parent_sample"] && (!queue_only || r["queue_state"]!="complete")]
    N=queue_only ? sum(Int(v) for (k,v) in frame["population_strata"] if occursin("/queued_",k)) :
        Int(frame["population_parents"])
    n=length(chosen)
    known=count(r->r["saved_jobs_certified"]>0,chosen)
    unknown=count(r->r["saved_jobs_certified"]==0 && !r["reuse_calculation_complete"],chosen)
    upper=FSA.population_success_upper(N,n,known+unknown;alpha=0.025)
    lower=N-FSA.population_success_upper(N,n,n-known;alpha=0.025)
    total=sum(r["maximizing_v5_count"] for r in chosen)
    saved=sum(r["saved_jobs_certified"] for r in chosen)
    extra=sum((r["reuse_calculation_complete"] ? 0 : r["orbit_count"]-1) for r in chosen)
    return Dict("population_parents"=>N,"uniform_sampled_parents"=>n,
        "parents_with_certified_v5_job_reuse"=>known,"parents_with_unknown_possible_reuse"=>unknown,
        "parent_prevalence_identified_estimate"=>[known/n,(known+unknown)/n],
        "parent_prevalence_exact_finite_population_95pct_interval"=>[lower/N,upper/N],
        "sampled_v5_jobs"=>total,"saved_v5_jobs_certified"=>saved,
        "possible_additional_savings_if_unknown_groups_complete"=>extra,
        "v5_job_weighted_cluster_ratio_identified_estimate"=>[saved/total,(saved+extra)/total],
        "parent_weighted_mean_v5_saving_fraction"=>mean(r["saved_jobs_certified"]/r["maximizing_v5_count"] for r in chosen),
        "scope"=>"Orbits under verified full-parent input automorphisms. Does not exclude additional GL equivalences between V5 spaces not extending to a parent automorphism.",
        "confidence"=>"Exact SRS parent hypergeometric inversion with partial-group cases conservatively unknown. Sibling V5 jobs are clusters; no independent-job confidence claim.")
end

function main(args=ARGS)
    config=configuration(args);mkpath(config.output)
    FSA.require_provenance_validation((;output=config.input))
    impl=FSA.implementation()
    tool_sha=FSA.file_sha(@__FILE__)
    mkpath(joinpath(config.output,"used-code"))
    cp(@__FILE__,joinpath(config.output,"used-code","source-"*tool_sha*".jl");force=true)
    frame=FSA.read_json(joinpath(config.input,"frame.json"))
    parents=FSA.read_json(joinpath(config.input,"parents.json"))["parents"]
    stabilizers=FSA.read_json(joinpath(config.input,"stabilizers.json"))["spaces"]
    controls=Set(Int(s["parent_id"]) for s in stabilizers if s["generator_count"]>0)
    sort!(parents;by=p->(!(p["parent_id"] in controls),p["parent_id"]))
    config.phase=="controls" && filter!(p->p["parent_id"] in controls,parents)
    bindings=Dict(name=>FSA.file_sha(joinpath(config.input,name)) for name in
        ("frame.json","parents.json","stabilizers.json","provenance-validation.json"))
    G=Q.geometry(8)
    records=Vector{Any}(undef,length(parents));started=time()
    slots=min(2,Threads.nthreads(),length(parents))
    @sync for slot in 1:slots
        Threads.@spawn for i in slot:slots:length(parents)
            remaining=config.max_seconds-(time()-started)
            # Running with zero remaining time returns no generators and an
            # explicit unknown group, preserving every unexamined parent.
            records[i]=audit_parent(G,parents[i],config;remaining_seconds=max(0.0,remaining))
            i%32 in (0,1) && begin
                println(JSON3.write(Dict("event"=>"parent_audited","index"=>i,
                    "total"=>length(parents),"elapsed_seconds"=>time()-started)));flush(stdout)
            end
        end
    end
    report=Dict{String,Any}("schema"=>"vbfsearch-parent-v5-orbit-audit-v1",
        "phase"=>config.phase,"implementation"=>impl,"tool_sha256"=>tool_sha,
        "input_bindings"=>bindings,"created_utc"=>string(now(UTC))*"Z",
        "selected_parents"=>length(parents),"known_v5_positive_control_parents"=>length(controls),
        "native_parent_groups_complete"=>count(r->r["group_complete"],records),
        "single_space_parents"=>count(r->r["maximizing_v5_count"]==1,records),
        "reuse_calculations_complete"=>count(r->r["reuse_calculation_complete"],records),
        "parents_with_certified_reuse"=>count(r->r["saved_jobs_certified"]>0,records),
        "all_v5_jobs"=>sum(r["maximizing_v5_count"] for r in records),
        "all_saved_v5_jobs_certified"=>sum(r["saved_jobs_certified"] for r in records),
        "elapsed_seconds"=>time()-started,
        "complete"=>all(r->r["reuse_calculation_complete"],records),
        "limitations"=>[
            "A complete parent-automorphism orbit calculation is only a lower bound on arbitrary GL equivalences among its V5 spaces.",
            "Partial automorphism groups supply valid reuse maps, never negative evidence.",
            "One V5 job per representative is sufficient only after its full uncapped completion search is certified and every target output is transported.",
            "No campaign jobs are executed or marked covered."])
    if config.phase=="all"
        report["population_rates"]=rates(frame,records)
        report["remaining_queue_rates"]=rates(frame,records;queue_only=true)
    end
    for (name,digest) in bindings
        FSA.file_sha(joinpath(config.input,name))==digest || error("input $name changed during audit")
    end
    FSA.implementation()["sha256"]==impl["sha256"] || error("mathematical implementation changed during audit")
    FSA.write_json(joinpath(config.output,"records.json"),Dict("records"=>records))
    report["records_sha256"]=FSA.file_sha(joinpath(config.output,"records.json"))
    FSA.write_json(joinpath(config.output,"report.json"),report)
    println(JSON3.write(report));flush(stdout)
    return report
end
end

abspath(PROGRAM_FILE)==(@__FILE__) && V5ParentOrbitAudit.main()
