"""Bounded, read-only pilot of equivalence reuse among prepared V5 jobs.

Run from the repository root, for example:
  julia --project=docs/inspector --threads=1 packages/VBFSearch/tools/analysis/v5_redundancy.jl \
    --database PATH/closure.sqlite --output PATH/evidence \
    --sample-per-stratum 32 --max-pairs 64 --pair-seconds 0.5

Only the job roster is scanned; no new parents are prepared and no construction
search is run. Necessary invariants never authorize a coverage skip. Every
positive equivalence is replayed using the VBF transporter verifier. The input
digest binds the ordered V5 job roster, not unrelated bytes of the campaign DB.
"""
module V5RedundancyPilot

using VBF, VBFSearch, SQLite, DBInterface, JSON3, SHA, TOML, Dates
const QE = VBF.QuadraticExtensions

function configuration(args)
    opts = Dict{String,String}(
        "sample-per-stratum"=>"32", "max-pairs"=>"64", "pair-seconds"=>"0.5",
        "pair-nodes"=>"10000", "pair-memory-mib"=>"128", "max-seconds"=>"180",
        "siblings-per-stratum"=>"0", "max-spaces-per-parent"=>"32")
    iseven(length(args)) || throw(ArgumentError("options require --name value pairs"))
    for i in 1:2:length(args)
        startswith(args[i],"--") || throw(ArgumentError("expected --option"))
        name = args[i][3:end]
        name in ("database", "output", keys(opts)...) || throw(ArgumentError("unknown option $name"))
        opts[name] = args[i+1]
    end
    for name in ("database", "output")
        haskey(opts,name) || throw(ArgumentError("missing --$name"))
    end
    n = parse(Int,opts["sample-per-stratum"]); n > 0 || throw(ArgumentError("sample must be positive"))
    return (; database=abspath(opts["database"]), output=abspath(opts["output"]), sample=n,
        max_pairs=parse(Int,opts["max-pairs"]), pair_seconds=parse(Float64,opts["pair-seconds"]),
        pair_nodes=parse(Int,opts["pair-nodes"]), memory_bytes=parse(Int,opts["pair-memory-mib"])*1024^2,
        max_seconds=parse(Float64,opts["max-seconds"]),
        sibling_parents=parse(Int,opts["siblings-per-stratum"]),
        max_spaces_per_parent=parse(Int,opts["max-spaces-per-parent"]))
end

"Expand a bounded set of sampled parents to inspect sibling-space reuse."
function sibling_jobs(database,initial; parents_per_stratum=2,max_spaces_per_parent=32)
    parents_per_stratum>0 && max_spaces_per_parent>0 || throw(ArgumentError("invalid sibling sample bounds"))
    parents = Dict{Tuple{String,Int},Vector{Int}}()
    for r in initial.selected
        key=(r["origin"],r["b5"]); chosen=get!(()->Int[],parents,key)
        length(chosen)<parents_per_stratum && !(r["parent_id"] in chosen) && push!(chosen,r["parent_id"])
    end
    db=SQLite.DB("file:"*abspath(database)*"?mode=ro")
    DBInterface.execute(db,"PRAGMA query_only=ON")
    selected=Dict{String,Any}[]; ctx=SHA.SHA2_256_CTX(); total=0
    try
        for key in sort!(collect(keys(parents))), parent in parents[key]
            chosen=Dict{String,Any}[]
            for row in DBInterface.execute(db,"SELECT id,payload,status,result FROM jobs WHERE parent_id=? AND kind='v5' ORDER BY id",(parent,))
                payload=String(row.payload); p=TOML.parse(payload)
                Int(p["b5"])==key[2] || error("parent has mixed maximal-b5 job parameters")
                total+=1
                SHA.update!(ctx,codeunits(JSON3.write([Int(row.id),parent,key[1],payload,String(row.status),String(row.result)])*"\n"))
                priority=bytes2hex(SHA.sha256(string("vbf-v5-sample-v1:",row.id,':',parent,':',payload)))
                push!(chosen,Dict{String,Any}("job_id"=>Int(row.id),"parent_id"=>parent,"origin"=>key[1],
                    "b5"=>key[2],"need"=>Int(p["need"]),"forms"=>Int.(p["forms"]),"status"=>String(row.status),
                    "sampling_priority"=>priority,"result"=>TOML.parse(String(row.result))))
            end
            sort!(chosen;by=r->r["sampling_priority"])
            append!(selected,chosen[1:min(length(chosen),max_spaces_per_parent)])
        end
    finally
        close(db)
    end
    strata=[merge(s,Dict("sampled"=>count(r->r["origin"]==s["origin"] && r["b5"]==s["b5"],selected),
        "sampled_parent_ids"=>parents[(s["origin"],s["b5"])])) for s in initial.strata]
    return (; selected,strata,initial.total,initial.identity,initial.roster_sha256,
        sibling_roster_sha256=bytes2hex(SHA.digest!(ctx)),sibling_population_jobs=total)
end

"Deterministic minimum-hash sampling within each (origin,b5) stratum."
function sample_jobs(database; per_stratum=32)
    per_stratum > 0 || throw(ArgumentError("sample size must be positive"))
    db = SQLite.DB("file:"*abspath(database)*"?mode=ro")
    DBInterface.execute(db,"PRAGMA query_only=ON")
    DBInterface.execute(db,"PRAGMA cache_size=-8192")
    ctx = SHA.SHA2_256_CTX()
    buckets = Dict{Tuple{String,Int},Vector{Dict{String,Any}}}()
    counts = Dict{Tuple{String,Int},Int}()
    identity = ""
    total = 0
    try
        for row in DBInterface.execute(db,"SELECT value FROM metadata WHERE key='identity'")
            identity = String(row.value)
        end
        query = """SELECT j.id,j.parent_id,p.origin,j.payload,j.status,j.result
            FROM jobs j JOIN parents p ON p.id=j.parent_id WHERE j.kind='v5' ORDER BY j.id"""
        for row in DBInterface.execute(db,query)
            total += 1
            payload = String(row.payload); origin = String(row.origin)
            m = match(r"(?m)^b5\s*=\s*(\d+)\s*$",payload)
            m === nothing && error("job $(row.id) has no b5 field")
            b5 = parse(Int,m.captures[1]); key = (origin,b5)
            counts[key] = get(counts,key,0)+1
            roster = JSON3.write([Int(row.id),Int(row.parent_id),origin,payload,String(row.status),String(row.result)])*"\n"
            SHA.update!(ctx,codeunits(roster))
            priority = bytes2hex(SHA.sha256(string("vbf-v5-sample-v1:",row.id,':',row.parent_id,':',payload)))
            chosen = get!(()->Dict{String,Any}[],buckets,key)
            if length(chosen)<per_stratum || priority<chosen[end]["sampling_priority"]
                p = TOML.parse(payload)
                record = Dict{String,Any}("job_id"=>Int(row.id),"parent_id"=>Int(row.parent_id),
                    "origin"=>origin,"b5"=>b5,"need"=>Int(p["need"]),"forms"=>Int.(p["forms"]),
                    "status"=>String(row.status),"sampling_priority"=>priority,
                    "result"=>TOML.parse(String(row.result)))
                push!(chosen,record); sort!(chosen;by=x->x["sampling_priority"])
                length(chosen)>per_stratum && pop!(chosen)
            end
        end
    finally
        close(db)
    end
    keys_sorted = sort!(collect(keys(buckets)))
    selected = reduce(vcat,(buckets[k] for k in keys_sorted); init=Dict{String,Any}[])
    strata = [Dict("origin"=>k[1],"b5"=>k[2],"population"=>counts[k],"sampled"=>length(buckets[k])) for k in keys_sorted]
    return (; selected,strata,total,identity,
        roster_sha256=bytes2hex(SHA.digest!(ctx)))
end

"Necessary rank and differential spectra; equality is never equivalence."
function invariant_record(G,forms,need)
    V = QE.rref(UInt32.(forms))[1]
    length(V)==5 || error("sample is not a five-space")
    coeffs = QE.forms_to_coeffs(V,G.N)
    F = SBox{8,UInt8}(UInt8.(QE.lut_from_coeffs(G,coeffs)))
    rank_histogram = VBF.quadratic_space_rank_signature(G,V)
    differential_histogram = [collect(p) for p in VBF.sorted_pairs(differential_spectrum(F))]
    # A GL(8) input action and a GL(5) component-basis action are EA actions on
    # this zero-padded SBox; its differential spectrum is therefore invariant.
    return Dict("rank_histogram"=>rank_histogram,
        "differential_histogram"=>differential_histogram,"need"=>need)
end

function collision_summary(records,key)
    sizes = Dict{String,Int}()
    for r in records
        k = String(r[key]); sizes[k] = get(sizes,k,0)+1
    end
    n = length(records); b = length(sizes)
    return Dict("sampled_jobs"=>n,"distinct_buckets"=>b,
        "maximum_possible_reused_jobs"=>n-b,
        "maximum_possible_reuse_fraction"=>n==0 ? 0.0 : (n-b)/n,
        "bucket_sizes_descending"=>sort!(collect(values(sizes));rev=true),
        "meaning"=>"Upper bound within this sample only; equal invariant buckets do not prove equivalence")
end

"Choose candidate pairs deterministically, preferring different origins/parents."
function candidate_pairs(records,max_pairs;within_parent=false)
    max_pairs >= 0 || throw(ArgumentError("max_pairs must be nonnegative"))
    pairs = Tuple{Int,Int}[]
    for i in 1:length(records), j in i+1:length(records)
        records[i]["invariant_key"]==records[j]["invariant_key"] || continue
        records[i]["exact_key"]==records[j]["exact_key"] && continue
        push!(pairs,(i,j))
    end
    sort!(pairs;by=p->(within_parent ? records[p[1]]["parent_id"]!=records[p[2]]["parent_id"] : records[p[1]]["origin"]==records[p[2]]["origin"],
        within_parent ? records[p[1]]["origin"]==records[p[2]]["origin"] : records[p[1]]["parent_id"]==records[p[2]]["parent_id"],
        bytes2hex(SHA.sha256(string(records[p[1]]["job_id"],':',records[p[2]]["job_id"])))))
    return pairs[1:min(length(pairs),max_pairs)]
end

function main(args=ARGS)
    config = configuration(args)
    config.max_seconds > 0 && config.pair_seconds >= 0 && config.pair_nodes >= 0 &&
        config.memory_bytes>=0 && config.max_pairs>=0 && config.sibling_parents>=0 &&
        config.max_spaces_per_parent>0 ||
        throw(ArgumentError("invalid time/node budgets"))
    isfile(config.database) || error("missing input database")
    mkpath(config.output)
    implementation = Dict{String,Any}("analysis_tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "transporter_source_sha256"=>bytes2hex(open(SHA.sha256,joinpath(pkgdir(VBF),"src/constructions/quadratic_space_equivalence.jl"))),
        "vbf_solver_implementation_sha256"=>VBFSearch.equivalence_solver_fingerprint(),
        "julia_version"=>string(VERSION))
    before_stat = stat(config.database)
    started = time(); sampled = sample_jobs(config.database;per_stratum=config.sample)
    if config.sibling_parents>0
        sampled=sibling_jobs(config.database,sampled;parents_per_stratum=config.sibling_parents,
            max_spaces_per_parent=config.max_spaces_per_parent)
    end
    records = sampled.selected; G = QE.geometry(8)
    println(JSON3.write(Dict("event"=>"sampled","jobs_scanned"=>sampled.total,"strata"=>sampled.strata))); flush(stdout)
    for r in records
        V = QE.rref(UInt32.(r["forms"]))[1]
        r["exact_key"] = join(V,',')*":"*string(r["need"])
        r["invariant"] = invariant_record(G,V,r["need"])
        r["b5"]+r["need"]==52 && r["invariant"]["rank_histogram"][G.n+1]==r["b5"] ||
            error("job parameters disagree with exact bent count or target b6=52")
        r["rank_key"] = JSON3.write([r["need"],r["invariant"]["rank_histogram"]])
        r["invariant_key"] = JSON3.write([r["need"],r["invariant"]["rank_histogram"],r["invariant"]["differential_histogram"]])
    end
    invariant_seconds = time()-started
    planned_pairs = candidate_pairs(records,config.max_pairs;within_parent=config.sibling_parents>0)
    witnesses = Dict{String,Any}[]; comparisons = Dict{String,Any}[]
    verified_groups = collect(1:length(records))
    root(i) = verified_groups[i]==i ? i : (verified_groups[i]=root(verified_groups[i]))
    for i in 1:length(records), j in i+1:length(records)
        records[i]["exact_key"]==records[j]["exact_key"] && (verified_groups[root(j)]=root(i))
    end
    for (i,j) in planned_pairs
        time()-started >= config.max_seconds && break
        a,b = records[i],records[j]
        before = time()
        result = VBF.quadratic_space_transporter(G,UInt32.(a["forms"]),UInt32.(b["forms"]);
            max_nodes=config.pair_nodes,timeout_seconds=min(config.pair_seconds,max(0.0,config.max_seconds-(time()-started))),
            max_memory_bytes=config.memory_bytes)
        elapsed = time()-before
        status = result isa Found ? "equivalent_witness_replayed" : result isa Exhausted ? "inequivalent_exhaustive" : "unknown_budget_hit"
        record = Dict{String,Any}("source_job_id"=>a["job_id"],"target_job_id"=>b["job_id"],
            "source_parent_id"=>a["parent_id"],"target_parent_id"=>b["parent_id"],
            "cross_origin"=>a["origin"]!=b["origin"],"b5"=>a["b5"],"status"=>status,
            "elapsed_seconds"=>elapsed,"nodes_visited"=>VBF.nodes_visited(result))
        if result isa Found
            columns = only(VBF.search_solutions(result))
            VBF.verify_quadratic_space_transporter(G,UInt32.(a["forms"]),UInt32.(b["forms"]),columns) || error("invalid transporter witness")
            record["input_columns"] = Int.(columns)
            push!(witnesses,record); verified_groups[root(j)]=root(i)
        end
        push!(comparisons,record)
        println(JSON3.write(merge(Dict("event"=>"comparison"),record))); flush(stdout)
    end
    component_sizes = Dict{Int,Int}()
    for i in eachindex(records); k=root(i);component_sizes[k]=get(component_sizes,k,0)+1;end
    source_stat = stat(config.database)
    before_stat.size==source_stat.size && before_stat.mtime==source_stat.mtime || error("input database changed during analysis")
    implementation["source_files_unchanged_during_analysis"] =
        implementation["analysis_tool_sha256"]==bytes2hex(open(SHA.sha256,@__FILE__)) &&
        implementation["vbf_solver_implementation_sha256"]==VBFSearch.equivalence_solver_fingerprint()
    identity_hash = bytes2hex(SHA.sha256(sampled.identity))
    report = Dict{String,Any}(
        "schema"=>"vbfsearch-v5-redundancy-pilot-v1","created_utc"=>string(now(UTC))*"Z",
        "implementation"=>implementation,
        "database"=>config.database,"database_bytes"=>source_stat.size,"database_mtime_unix"=>source_stat.mtime,
        "campaign_identity_sha256"=>identity_hash,"ordered_v5_job_roster_sha256"=>sampled.roster_sha256,
        "input_digest_scope"=>"All V5 jobs ordered by id: id,parent_id,origin,payload,status,result, encoded as JSON arrays with newline. Does not hash unrelated campaign database bytes.",
        "sampling"=>"SHA256(vbf-v5-sample-v1:job_id:parent_id:payload), smallest hashes separately in each (origin,b5) stratum",
        "strata"=>sampled.strata,"population_v5_jobs"=>sampled.total,"sampled_v5_jobs"=>length(records),
        "sample_sha256"=>bytes2hex(SHA.sha256(JSON3.write(records))),
        "configuration"=>Dict(string(k)=>v for (k,v) in Base.pairs(config)),
        "exact_duplicates"=>collision_summary(records,"exact_key"),
        "rank_invariant_collisions"=>collision_summary(records,"rank_key"),
        "rank_and_differential_invariant_collisions"=>collision_summary(records,"invariant_key"),
        "pair_selection"=>config.sibling_parents>0 ? "Same invariant, unequal exact key; same parent preferred, SHA256(job ids) order; capped independently of outcomes" : "Same invariant, unequal exact key; different origins then different parents preferred, SHA256(job ids) order; capped independently of outcomes",
        "comparison_pairs_planned"=>length(planned_pairs),"comparison_pairs_attempted"=>length(comparisons),
        "within_parent_pairs_attempted"=>count(r->r["source_parent_id"]==r["target_parent_id"],comparisons),
        "comparison_elapsed_seconds_sum"=>sum((r["elapsed_seconds"] for r in comparisons);init=0.0),
        "verified_equivalent_pairs"=>length(witnesses),
        "proven_inequivalent_pairs"=>count(r->r["status"]=="inequivalent_exhaustive",comparisons),
        "unknown_pairs"=>count(r->r["status"]=="unknown_budget_hit",comparisons),
        "sample_reused_jobs_proved"=>length(records)-length(component_sizes),
        "verified_sample_group_sizes"=>sort!(collect(values(component_sizes));rev=true),
        "sample_preparation_seconds"=>invariant_seconds,"elapsed_seconds"=>time()-started,
        "limitations"=>[
            "Only prepared V5 jobs are sampled; the unprepared million-parent frontier is outside this population.",
            "Equal-size strata intentionally oversample discovered/b5=30; pooled fractions are not population estimates.",
            "Zero collisions in a small sample do not bound global reuse: many repeated orbits dispersed over a large population can evade the sample (birthday effect).",
            "Invariant collisions are only candidate reuse and never coverage certificates.",
            "A transporter certifies equivalent complete extension searches only when the construction parameters match; this tool does not mark campaign jobs covered.",
            "Old result operation counts are not historical wall-clock times; no campaign completion speedup is extrapolated.",
            "Time limits are cooperative and Julia compilation can add initial overhead."])
    if config.sibling_parents>0
        report["sibling_sampling"]=Dict("selection"=>"First distinct parents in the initial stratum's minimum-job-hash sample; then minimum-job-hash spaces within each selected parent. Deliberately biased toward parents with many V5 spaces.",
            "initial_sample_per_stratum"=>config.sample,"max_parents_per_stratum"=>config.sibling_parents,
            "max_spaces_per_parent"=>config.max_spaces_per_parent,"parent_roster_jobs"=>sampled.sibling_population_jobs,
            "parent_roster_sha256"=>sampled.sibling_roster_sha256)
    end
    open(io->JSON3.pretty(io,records),joinpath(config.output,"sample.json"),"w")
    open(io->JSON3.pretty(io,comparisons),joinpath(config.output,"comparisons.json"),"w")
    open(io->JSON3.pretty(io,report),joinpath(config.output,"report.json"),"w")
    println(JSON3.write(report)); flush(stdout)
    return report
end

end

abspath(PROGRAM_FILE)==(@__FILE__) && V5RedundancyPilot.main()
