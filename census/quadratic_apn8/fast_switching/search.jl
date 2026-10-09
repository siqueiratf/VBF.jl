"""
Bounded n=8 switching pilot against the independently rebuilt public corpus.
Run from the root project. See README.md for inputs, limits and interpretation.
"""
const FAST_SWITCHING_USAGE = nothing
include("../rebuild_corpus/check_candidates.jl")
using Random

const STUDY_INPUTS = [
    "census/quadratic_apn8/search_b52/results/desk1/found.tsv",
    "census/quadratic_apn8/new_classes_553.tsv",
    "census/quadratic_apn8/new_classes_extra.tsv",
    "census/quadratic_apn8/search_b52/new_classes_trial_773.tsv",
    "census/quadratic_apn8/theory/hyperplane_scan/new_classes_hyperplane.tsv",
]
const SUPPLEMENT = "census/quadratic_apn8/results/literature_20261009/supplemental_luts.tsv"

function options(args)
    opts = Dict("limit"=>"32", "seconds"=>"30", "evaluations"=>"10000",
        "wall-seconds"=>"Inf",
        "workers"=>string(min(Threads.nthreads(),8)), "seed"=>"82026",
        "orbit-seconds"=>"0", "ea-representatives"=>"0",
        "baseline"=>DEFAULT_OUTPUT, "outdir"=>joinpath(@__DIR__,"results","pilot"))
    inputs = String[]
    seed_inputs = String[]
    iseven(length(args)) || error("options require --name VALUE pairs")
    for i in 1:2:length(args)
        startswith(args[i],"--") || error("expected --name VALUE")
        key = args[i][3:end]
        if key == "input"
            push!(inputs,abspath(args[i+1]))
        elseif key == "seed-input"
            push!(seed_inputs,abspath(args[i+1]))
        else
            haskey(opts,key) || error("unknown option: $(args[i])")
            opts[key] = args[i+1]
        end
    end
    opts["input_paths"] = join(inputs,'\n')
    opts["seed_input_paths"] = join(seed_inputs,'\n')
    opts, inputs, seed_inputs
end

# Deterministic reservoir sample per source avoids scanning only the first
# sorted signatures. All previous signatures remain in the exclusion set.
function load_study(paths, per_source, rng)
    seen = Set{String}()
    seeds = Tuple{String,String}[]
    for path in paths
        isfile(path) || error("required comparison input absent: $path")
        hashcol, payloadcol, statuscol = 1, 2, nothing
        pool = Tuple{String,String}[]
        eligible = 0
        for (line_number,line) in enumerate(eachline(path))
            isempty(strip(line)) && continue
            cols = split(line,'\t')
            if line_number == 1 && cols[1] in ("sigma","sigma_hash")
                payloadcol = something(findfirst(c->c in ("coeffs","lut_hex","lut"),cols))
                statuscol = findfirst(==("status"),cols)
                continue
            end
            hash = String(cols[hashcol])
            length(hash) == 64 || error("invalid signature at $path:$line_number")
            push!(seen,hash)
            statuscol === nothing || cols[statuscol] == "new" || continue
            eligible += 1
            j = eligible <= per_source ? eligible : rand(rng,1:eligible)
            j <= per_source || continue
            row = (hash,String(cols[payloadcol]))
            eligible <= per_source ? push!(pool,row) : (pool[j] = row)
        end
        append!(seeds,pool)
    end
    unique!(seeds)
    seen, seeds
end

function main_search(args)
    opts, extra, seed_inputs = options(args)
    limit, workers = parse(Int,opts["limit"]), parse(Int,opts["workers"])
    seconds, evaluations = parse(Float64,opts["seconds"]), parse(Int,opts["evaluations"])
    wall_seconds = parse(Float64,opts["wall-seconds"])
    orbit_seconds, ea_limit = parse(Float64,opts["orbit-seconds"]), parse(Int,opts["ea-representatives"])
    limit > 0 && evaluations > 0 && seconds > 0 && isfinite(seconds) || error("positive finite search limits required")
    wall_seconds > 0 && (isfinite(wall_seconds) || wall_seconds == Inf) || error("invalid total time budget")
    1 <= workers <= Threads.nthreads() || error("workers exceeds Julia thread count")
    ea_limit >= 0 && orbit_seconds >= 0 && isfinite(orbit_seconds) || error("invalid orbit limits")
    ea_limit == 0 || orbit_seconds > 0 || error("EA exploration requires --orbit-seconds")
    baseline, outdir = abspath(opts["baseline"]), abspath(opts["outdir"])
    report = TOML.parsefile(joinpath(baseline,"comparison.toml"))
    report["provenance_complete"] || error("public corpus rebuild is incomplete")
    dbpath = joinpath(baseline,"fresh_union.sqlite")
    baseline_hash = filehash(dbpath)
    baseline_hash == report["fresh_union_sha256"] || error("baseline digest mismatch")
    paths = unique(vcat([joinpath(REPO,p) for p in vcat(STUDY_INPUTS,[SUPPLEMENT])],extra,seed_inputs))
    input_hashes = Dict(p=>filehash(p) for p in paths)
    known, seeds = load_study(paths,max(1,cld(limit,length(paths))),Xoshiro(parse(Int,opts["seed"])))
    if !isempty(seed_inputs)
        _, seeds = load_study(seed_inputs,max(1,cld(limit,length(seed_inputs))),Xoshiro(parse(Int,opts["seed"])))
    end
    w = Workspace()
    gold = gold_apn(8)
    pushfirst!(seeds,(bytes2hex(signature(w,gold.lut)),bytes2hex(gold.lut)))
    unique!(seeds)
    resize!(seeds,min(length(seeds),limit))
    isdir(outdir) && !isempty(readdir(outdir)) && error("choose a fresh --outdir; previous evidence is never overwritten")
    mkpath(outdir)
    novel = Set{String}()
    guard = ReentrantLock()
    rows = Dict{String,Any}[]
    next_seed = Threads.Atomic{Int}(1)
    started = time_ns()
    remaining() = max(0.0,wall_seconds-(time_ns()-started)*1e-9)
    code_paths = [@__FILE__,
        joinpath(REPO,"packages/VBF/src/constructions/switching_neighbors.jl"),
        joinpath(REPO,"packages/VBF/src/constructions/ea_class_orbits.jl"),
        joinpath(@__DIR__,"../rebuild_corpus/check_candidates.jl"),
        joinpath(@__DIR__,"../rebuild_corpus/signature.jl")]
    code_hashes = Dict(p=>filehash(p) for p in code_paths)
    metadata = Dict("schema"=>"vbf-n8-switching-pilot-v2","options"=>opts,
        "input_sha256"=>input_hashes,"baseline_sha256"=>baseline_hash,
        "code_sha256"=>code_hashes,"seeds"=>length(seeds),"workers"=>workers,
        "started_utc"=>string(Dates.now(Dates.UTC)),
        "study_signatures"=>length(known))
    open(io->TOML.print(io,metadata;sorted=true),joinpath(outdir,"run.toml"),"w")
    println("Starting $(length(seeds)) seeds on $workers workers; total search budget $wall_seconds s; results $outdir")
    flush(stdout)
    open(joinpath(outdir,"new_classes.tsv"),"w") do io
        println(io,"sigma_hash\tlut_hex\tparent_sigma\tea_representative\tswitch_direction\tcoeffs")
        Threads.@threads :static for worker in 1:workers
            db = readonly(dbpath)
            stmt = DBI.prepare(db,"SELECT 1 FROM signatures WHERE sigma_hash=? LIMIT 1")
            workspace = Workspace()
            try
                while remaining() > 0
                    index = Threads.atomic_add!(next_seed,1)
                    index <= length(seeds) || break
                    parent, payload = seeds[index]
                    lut = candidate_lut(payload)
                    bytes2hex(signature(workspace,lut)) == parent || error("seed signature mismatch: $parent")
                    F = SBox{8,UInt8}(lut)
                    counters = Dict("neighbors"=>0,"quadratic"=>0,"nonquadratic"=>0,
                        "public_matches"=>0,"study_matches"=>0,"new_classes"=>0)
                    parents = [F]
                    maps = F2AffineMap{16,UInt32}[identity_affine_map(16,UInt32)]
                    orbit_complete, orbit_stop = false, "disabled"
                    orbit_available = 0
                    if ea_limit > 0
                        orbit = ea_class_representatives(F; prefer_permutations=false,
                            subspace_algorithm=:optimized,timeout_seconds=min(orbit_seconds,remaining()))
                        orbit_complete, orbit_stop = orbit.complete, string(orbit.stop_reason)
                        orbit_available = length(orbit.representatives)
                        # Original F is always searched; the budget only limits
                        # additional EA representatives inside its CCZ class.
                        for (j,G) in enumerate(orbit.representatives)
                            # Quadratic representatives inside one quadratic
                            # APN CCZ class all belong to the same EA class.
                            algebraic_degree(G) == 2 && continue
                            push!(parents,G)
                            push!(maps,orbit.mappings[j])
                            length(parents)-1 >= ea_limit && break
                        end
                    end
                    outcomes = Dict{String,Any}[]
                    for (representative,P) in enumerate(parents)
                        remaining() > 0 || break
                        observer = function (event,G)
                            event === :apn || return
                            counters["neighbors"] += 1
                            if algebraic_degree(G) != 2
                                counters["nonquadratic"] += 1
                                return
                            end
                            counters["quadratic"] += 1
                            hash = bytes2hex(signature(workspace,G.lut))
                            if !isempty(collect(DBI.execute(stmt,(hash,))))
                                counters["public_matches"] += 1
                            elseif hash in known
                                counters["study_matches"] += 1
                            else
                                lock(guard) do
                                    hash in novel && return
                                    push!(novel,hash)
                                    counters["new_classes"] += 1
                                    direction = only(unique(filter(!iszero,G.lut .⊻ P.lut)))
                                    a = anf(G)
                                    coeffs = bytes2hex(UInt8[a[((1<<i)|(1<<j))+1] for i in 0:7 for j in (i+1):7])
                                    # This compact encoding drops affine terms;
                                    # verify that normalization preserves sigma.
                                    bytes2hex(signature(workspace,candidate_lut(coeffs))) == hash || error("normalization changed signature")
                                    println(io,hash,'\t',bytes2hex(G.lut),'\t',parent,'\t',representative,'\t',Int(direction),'\t',coeffs)
                                    flush(io)
                                end
                            end
                        end
                        r = switching_neighbors_bounded(P;max_evaluations=evaluations,
                            timeout_seconds=min(seconds,remaining()),observer)
                        push!(outcomes,Dict("representative"=>representative,
                            "parent_lut_hex"=>bytes2hex(P.lut),
                            "ccz_columns"=>Int.(maps[representative].linear.cols),
                            "ccz_constant"=>Int(maps[representative].constant),
                            "complete"=>r isa Exhausted,"evaluations"=>nodes_visited(r),
                            "seconds"=>elapsed_seconds(r),
                            "stop"=>r isa BudgetHit ? string(r.where_it_stopped.reason) : "none"))
                    end
                    row = Dict("index"=>index,"parent_sigma"=>parent,
                        "parent_lut_hex"=>bytes2hex(F.lut),"counts"=>counters,
                        "orbit_complete"=>orbit_complete,"orbit_stop"=>orbit_stop,
                        "orbit_representatives_available"=>orbit_available,
                        "orbit_representative_cap"=>ea_limit,"switching"=>outcomes,
                        "parent_search_complete"=>length(outcomes)==length(parents) && all(s["complete"] for s in outcomes))
                    checkpoint = joinpath(outdir,"parent_$(index).toml")
                    open(io->TOML.print(io,row;sorted=true),checkpoint*".tmp","w")
                    mv(checkpoint*".tmp",checkpoint)
                    lock(guard) do
                        push!(rows,row)
                        println("parent $index/$(length(seeds)): $(counters["neighbors"]) APNs, $(counters["quadratic"]) quadratic, $(counters["new_classes"]) additional signatures")
                        progress = Dict("processed_seeds"=>length(rows),"new_classes"=>length(novel),
                            "elapsed_seconds"=>(time_ns()-started)*1e-9,"remaining_seconds"=>remaining())
                        open(io->TOML.print(io,progress;sorted=true),joinpath(outdir,"progress.toml.tmp"),"w")
                        mv(joinpath(outdir,"progress.toml.tmp"),joinpath(outdir,"progress.toml");force=true)
                        flush(stdout)
                    end
                end
            finally
                DBI.close!(stmt)
                SQL.close(db)
            end
        end
    end
    all(filehash(p)==h for (p,h) in input_hashes) || error("comparison inputs changed during search")
    sort!(rows;by=r->r["index"])
    summary = merge(metadata,Dict("new_classes"=>length(novel),
        "processed_seeds"=>length(rows),
        "complete"=>length(rows)==length(seeds) && all(r["parent_search_complete"] for r in rows),
        "stop"=>remaining()==0 ? "time" : "seed_pool_exhausted",
        "elapsed_seconds"=>(time_ns()-started)*1e-9,"parents"=>rows,
        "novelty_scope"=>"different verified quadratic signatures absent from the rebuilt public baseline, public supplement, and supplied study inputs; not a claim of literature completeness")
    )
    open(io->TOML.print(io,summary;sorted=true),joinpath(outdir,"summary.toml"),"w")
    println("Finished: $(length(novel)) additional signatures; $(summary["elapsed_seconds"]) seconds. Evidence: $outdir")
    summary
end

abspath(PROGRAM_FILE) == (@__FILE__) && main_search(ARGS)
