"""
Read-only live view of a literature-root quadratic APN closure.

Run from the repository root:
  julia --threads=1,1 --project=docs/inspector docs/inspector/closure_monitor.jl \\
    --campaign packages/VBFSearch/data/search/literature-b52-closure-20261014 \\
    --host 0.0.0.0 --port 8766

The controller owns closure.sqlite and progress.toml. This server only reads
VBFSearch.closure_progress, verifies the pinned initial-root file, and serves the
approved figures. With --structure JSON it also serves that precomputed report
at /structure. A completed parent has exhausted both construction methods.
"""
module APNClosureMonitor

using Dates, HTTP, JSON3, SHA, TOML
import VBFSearch

const PAGE = joinpath(@__DIR__, "..", "src", "assets", "apn-closure-monitor.html")
const GRAPH_PAGE = joinpath(@__DIR__, "..", "src", "assets", "apn-closure-graph.html")
const GRAPH_SCRIPT = joinpath(@__DIR__, "..", "src", "assets", "apn-closure-graph.js")
const STRUCTURE_PAGE = joinpath(@__DIR__, "..", "src", "assets", "apn-closure-structure.html")
const STRUCTURE_SCRIPT = joinpath(@__DIR__, "..", "src", "assets", "apn-closure-structure.js")
const CONTENT_TYPES = Dict(
    ".html" => "text/html; charset=utf-8", ".svg" => "image/svg+xml",
    ".png" => "image/png", ".pdf" => "application/pdf",
    ".dot" => "text/plain; charset=utf-8", ".zip" => "application/zip",
)

mutable struct Monitor
    campaign::String
    run::String
    figures::String
    upstream::String
    comparison::String
    graph::String
    structure::String
    read_run::Function
    guard::ReentrantLock
    root_stamp::Any
    roots::Dict{String,Any}
    sampled_at::Float64
    snapshot::Dict{String,Any}
    samples::Vector{Tuple{Float64,Int,Int}}
    cpu_samples::Vector{Tuple{Float64,Int,Float64}}
end

function controller_snapshot(directory)
    isdefined(VBFSearch, :closure_progress) || error("restart with the current recursive controller installed")
    result=VBFSearch.closure_progress(directory)
    metrics_path=joinpath(directory,"process_metrics.json")
    sessions=get(result,"sessions",Any[])
    if get(result,"running",false) && !isempty(sessions) && isfile(metrics_path)
        metrics=JSON3.read(read(metrics_path,String),Dict{String,Any})
        if get(metrics,"schema","")=="vbfsearch-process-metrics-v1" &&
            get(metrics,"pid",nothing)==get(first(sessions),"pid",nothing)
            result["process_metrics"]=metrics
        end
    end
    result
end

"""Relay a remote monitor's committed snapshot without sharing its SQLite files."""
function upstream_snapshot(url)
    startswith(url, "http://") || startswith(url, "https://") || error("upstream must be an HTTP URL")
    reply = HTTP.get(url; connect_timeout=5, request_timeout=12)
    data = JSON3.read(String(reply.body), Dict{String,Any})
    get(data, "schema", "") == "vbfsearch-closure-monitor-v1" || error("unsupported upstream monitor")
    execution = data["execution"]
    get(execution, "attached", false) || error("upstream controller is not initialized")
    haskey(data,"discoveries") && (execution["relayed_discoveries"]=data["discoveries"])
    execution
end

function Monitor(campaign; run=joinpath(campaign, "run"),
                 figures=joinpath(campaign, "diagrams", "gallery"), read_run=controller_snapshot, upstream="",comparison="",
                 graph=joinpath(run,"graph"),structure="")
    campaign = abspath(campaign)
    isfile(joinpath(campaign, "campaign.toml")) || error("missing campaign.toml")
    reader = isempty(upstream) ? read_run : _ -> upstream_snapshot(upstream)
    Monitor(campaign, abspath(run), abspath(figures), upstream, comparison, abspath(graph),
            isempty(structure) ? "" : abspath(structure), reader, ReentrantLock(), nothing,
            Dict{String,Any}(), 0.0, Dict{String,Any}(), Tuple{Float64,Int,Int}[], Tuple{Float64,Int,Float64}[])
end

"""Expose confirmed discovery scopes; hide comparisons that no longer match the run."""
function discovery_summary(execution,comparison)
    result=Dict{String,Any}("discovered_classes"=>execution["promoted_parents"],
        "total_classes"=>execution["total_parents"],"new_vs_earlier"=>nothing,
        "comparison_status"=>"unavailable","literature_novelty"=>"unresolved")
    if isempty(comparison)
        relayed=get(execution,"relayed_discoveries",nothing)
        return relayed===nothing ? result : Dict{String,Any}(relayed)
    end
    isfile(comparison) || return result
    saved=JSON3.read(read(comparison,String),Dict{String,Any})
    evidence=get(saved,"ea_comparison_summary",Dict{String,Any}())
    proofs=get(get(evidence,"status_counts",Dict{String,Any}()),"equivalent_with_verified_witness",0)
    current=get(saved,"current_run","")==get(execution,"directory",nothing) &&
        get(saved,"current_class_representatives",-1)==execution["total_parents"] &&
        get(saved,"published_current_roots",-1)==execution["initial_roots"] &&
        get(saved,"unresolved_cross_dataset_pairs",-1)==0 &&
        get(evidence,"all_positive_witnesses_replayed",false) &&
        get(saved,"verified_ea_class_overlap",-1)==proofs+get(saved,"exact_lut_confirmed_overlap",0) &&
        get(execution,"unresolved_equivalence",-1)==0
    result["comparison_status"]=current ? "current" : "outdated"
    if current
        value=Int(saved["current_discovered_classes_absent_from_old_dataset_and_published_roots"])
        0<=value<=execution["promoted_parents"] || error("comparison discovery count is inconsistent")
        result["new_vs_earlier"]=value
        result["earlier_classes"]=saved["old_class_representatives"]
        result["overlap_classes"]=saved["verified_ea_class_overlap"]
        result["combined_classes"]=saved["combined_ea_classes"]
        result["comparison_utc"]=saved["completed_utc"]
    end
    result
end

"""Catalog-relative evidence for this exact admitted class set, read from its audit cache.

Signature absence certifies a lower bound. Matching signatures remain pending
until a positive witness or an exhaustive separation has been recorded.
"""
function catalog_summary(execution,path)
    result=Dict{String,Any}("status"=>"unavailable","confirmed_absent_classes"=>nothing)
    isfile(path) || return result
    saved=JSON3.read(read(path,String),Dict{String,Any})
    get(saved,"schema","")=="vbfsearch-catalog-comparison-v1" || return result
    bound=get(saved,"current_run","")==get(execution,"directory",nothing) &&
        0<=get(saved,"current_classes",-1)<=execution["total_parents"] &&
        get(saved,"initial_roots",-1)==execution["initial_roots"] &&
        get(saved,"catalog_snapshot_validated",false) &&
        get(saved,"all_catalog_entries_covered",false)
    bound || return merge(result,Dict("status"=>"outdated"))
    count=Int(saved["confirmed_absent_classes"])
    current_count=Int(saved["current_confirmed_absent_classes"])
    earlier_only=Int(saved["earlier_only_confirmed_absent_classes"])
    0<=current_count<=execution["total_parents"] && earlier_only>=0 &&
        current_count+earlier_only==count || error("inconsistent catalog comparison counts")
    complete=get(saved,"complete",false) && get(saved,"all_positive_witnesses_replayed",false) &&
        get(saved,"remaining_pairs",-1)==0 &&
        get(saved,"verified_catalog_pairs",-1)==get(saved,"total_catalog_pairs",-2)
    newer=execution["total_parents"]-Int(saved["current_classes"])
    newer>0 && !complete && return merge(result,Dict("status"=>"outdated"))
    merge(result,saved,Dict("status"=>newer>0 ? "snapshot" : complete ? "complete" : "verifying",
        "audited_current_classes"=>Int(saved["current_classes"]),"unaudited_classes"=>newer))
end

"""Expose the current campaign's signature-separation lower bound from its worker."""
function live_catalog_summary(execution,path)
    unavailable=Dict{String,Any}("status"=>"unavailable","confirmed_absent_classes"=>nothing)
    isfile(path) || return unavailable
    saved=JSON3.read(read(path,String),Dict{String,Any})
    get(saved,"schema","")=="vbfsearch-live-catalog-comparison-v1" || return unavailable
    get(saved,"current_run","")==get(execution,"directory",nothing) &&
        get(saved,"initial_roots",-1)==execution["initial_roots"] &&
        get(saved,"catalog_snapshot_validated",false) || return merge(unavailable,Dict("status"=>"outdated"))
    checked=Int(saved["classes_checked"]);absent=Int(saved["confirmed_absent_classes"])
    0<=absent<=checked<=execution["total_parents"] &&
        absent+saved["matching_signature_classes"]==checked && saved["parent_cutoff"]==checked ||
        error("inconsistent live catalog comparison")
    merge(saved,Dict("status"=>"snapshot","audited_current_classes"=>checked,
        "unaudited_classes"=>execution["total_parents"]-checked))
end

"""Expose the direct published-root result separately from recursive campaign totals."""
function published_root_summary(execution,path)
    unavailable=Dict{String,Any}("status"=>"unavailable")
    isfile(path) || return unavailable
    saved=JSON3.read(read(path,String),Dict{String,Any})
    get(saved,"schema","")=="vbfsearch-published-root-comparison-v1" || return unavailable
    n=get(saved,"published_seed_count",-1)
    bound=get(saved,"campaign_run","")==get(execution,"directory",nothing) &&
        get(saved,"roots_sha256","")==get(execution,"roots_sha256",nothing) &&
        n==execution["initial_roots"] &&
        get(get(execution,"seed_progress",Dict()),"completed",-2)==n &&
        get(saved,"scope","")=="direct_published_root_outputs" &&
        get(saved,"reference_excludes_private_discoveries",false) &&
        get(saved,"unresolved_root_outputs",-1)==0
    bound || return Dict{String,Any}("status"=>"outdated")
    total=Int(saved["direct_output_classes"])
    absent=Int(saved["literature_absent_classes"])
    matches=Int(saved["literature_matching_pairs"])
    recovered=Int(saved["historical_verified_overlap"])
    0<=absent<=total<=execution["total_parents"] && absent+matches==total &&
        0<=recovered<=saved["historical_candidate_overlap"]<=saved["historical_total_classes"] ||
        error("inconsistent published-root comparison counts")
    complete=get(saved,"complete",false) && get(saved,"all_positive_witnesses_replayed",false) &&
        get(saved,"literature_verified_matches",-1)==matches &&
        recovered==saved["historical_candidate_overlap"] && get(saved,"unresolved_pairs",-1)==0
    merge(saved,Dict("status"=>complete ? "complete" : "verifying"))
end

"""Recursive parents: admitted classes beyond the published seeds, and how many are expanded.

Each admitted parent receives its construction jobs at admission, so a parent
counts as complete only after both construction methods are exhausted.
"""
function recursive_summary(execution)
    seeds=Int(get(get(execution,"seed_progress",Dict{String,Any}()),"completed",0))
    admitted=Int(execution["promoted_parents"])
    completed=Int(execution["completed_parents"])-seeds
    0<=completed<=admitted || error("recursive parent counts are inconsistent")
    Dict{String,Any}("admitted"=>admitted,"completed"=>completed,"waiting"=>admitted-completed)
end

"""Show a complete direct-root report of an earlier run as history, never as live counts."""
function previous_campaign_summary(execution,path)
    unavailable=Dict{String,Any}("status"=>"unavailable")
    isfile(path) || return unavailable
    saved=JSON3.read(read(path,String),Dict{String,Any})
    get(saved,"schema","")=="vbfsearch-published-root-comparison-v1" &&
        get(saved,"complete",false) && get(saved,"all_positive_witnesses_replayed",false) &&
        get(saved,"unresolved_pairs",-1)==0 || return unavailable
    get(saved,"campaign_run","")==get(execution,"directory",nothing) && return unavailable
    fields=("published_seed_count","direct_output_classes","literature_reference_classes","literature_absent_classes",
        "historical_total_classes","historical_verified_overlap","absent_from_literature_and_historical","completed_utc")
    merge(Dict{String,Any}(k=>saved[k] for k in fields),Dict{String,Any}("status"=>"previous","run"=>basename(saved["campaign_run"])))
end

"""User and system CPU seconds of a local process, or nothing when it has ended."""
function process_cpu_seconds(pid)
    stat=try read("/proc/$pid/stat",String) catch; return nothing end
    fields=split(stat[findlast(')',stat)+2:end])
    (parse(Int,fields[12])+parse(Int,fields[13]))/100
end

"""Mean CPU cores of the controller over about 30 s, sampled when the controller writes none."""
function sample_process_metrics!(monitor,execution,now_seconds)
    haskey(execution,"process_metrics") && return
    sessions=get(execution,"sessions",Any[])
    pid=get(execution,"running",false) && !isempty(sessions) ? get(first(sessions),"pid",nothing) : nothing
    if !(pid isa Integer) || !occursin("julia",try read("/proc/$pid/cmdline",String) catch; "" end)
        empty!(monitor.cpu_samples);return
    end
    cpu=process_cpu_seconds(pid);cpu===nothing && return
    !isempty(monitor.cpu_samples) && last(monitor.cpu_samples)[2]!=pid && empty!(monitor.cpu_samples)
    push!(monitor.cpu_samples,(now_seconds,Int(pid),cpu))
    filter!(sample->now_seconds-sample[1]<=35,monitor.cpu_samples)
    oldest=first(monitor.cpu_samples);elapsed=now_seconds-oldest[1]
    elapsed>=5 || return
    execution["process_metrics"]=Dict{String,Any}("schema"=>"vbfsearch-process-metrics-v1","pid"=>pid,
        "utc"=>string(Dates.now(Dates.UTC))*"Z","mean_cpu_cores"=>Dict("30"=>(cpu-oldest[3])/elapsed),
        "compute_threads"=>Sys.CPU_THREADS,"source"=>"monitor sampling of /proc")
end

"""Check the initial EA-class count against the completed, digest-bound seed audit."""
function root_summary!(monitor)
    plan_path = joinpath(monitor.campaign, "campaign.toml")
    plan = TOML.parsefile(plan_path)
    config = plan["roots"]
    roots_path = joinpath(monitor.campaign, config["qualified_root_file"])
    evidence_path = joinpath(monitor.campaign, config["equivalence_evidence"])
    stamp = [(stat(path).mtime, stat(path).size) for path in (plan_path, roots_path, evidence_path)]
    stamp == monitor.root_stamp && return monitor.roots
    evidence = TOML.parsefile(evidence_path)
    get(evidence, "complete", false) || error("initial-root equivalence audit is incomplete")
    get(evidence, "all_encoded_positive_witnesses_replayed", false) ||
        error("initial-root equivalence witnesses have not all been replayed")
    digest = bytes2hex(open(SHA.sha256, roots_path))
    digest == evidence["verified_roots_sha256"] || error("initial-root file digest changed")
    records = count(_ -> true, eachline(roots_path)) - 1
    count_expected = Int(config["qualified_root_count"])
    records == count_expected == Int(evidence["verified_seed_classes"]) ||
        error("initial-root count disagrees with its audit")
    monitor.roots = Dict{String,Any}(
        "count" => count_expected, "verified" => true,
        "sha256" => digest, "campaign_sha256" => bytes2hex(open(SHA.sha256, plan_path)),
        "profile_b6" => config["profile_b6"], "profile_order" => config["profile_order"],
        "b5_28" => get(config, "qualified_b5_28_classes", nothing),
        "b5_30" => get(config, "qualified_b5_30_classes", nothing),
        "source_count" => length(config["sources"]),
    )
    monitor.root_stamp = stamp
    monitor.roots
end

function empty_execution(roots)
    methods = Dict(name => Dict{String,Any}(
        "parents_completed" => 0, "jobs_done" => nothing, "jobs_pending" => nothing,
        "jobs_running" => 0, "jobs_paused" => 0, "candidates" => 0,
    ) for name in ("v5", "switching"))
    Dict{String,Any}(
        "state" => "not_started", "running" => false, "attached" => false,
        "initial_roots" => roots["count"], "promoted_parents" => 0,
        "total_parents" => roots["count"], "completed_parents" => 0,
        "active_parents" => 0, "queued_parents" => nothing, "blocked_parents" => 0,
        "unresolved_equivalence" => 0, "nonquadratic_apn_luts" => 0,
        "exact_luts" => 0, "signature_buckets" => 0, "construction_paths" => 0,
        "closure_complete" => false, "heartbeat_utc" => nothing,
        "methods" => methods, "sessions" => Any[],
        "seed_progress"=>Dict("total"=>roots["count"],"completed"=>0,
            "v5_completed"=>0,"switching_completed"=>0,"focus_available"=>false),
    )
end

"""Sample committed controller counters; repeated browser polls share a short cache."""
function snapshot(monitor; force=false, now_seconds=time())
    lock(monitor.guard) do
        !force && now_seconds - monitor.sampled_at < 2 && !isempty(monitor.snapshot) &&
            return monitor.snapshot
        roots = root_summary!(monitor)
        database_exists = isfile(joinpath(monitor.run, "closure.sqlite"))
        attached = !isempty(monitor.upstream) || (database_exists && isfile(joinpath(monitor.run, "progress.toml")))
        execution = if attached
            result = Dict{String,Any}(monitor.read_run(monitor.run))
            result["roots_sha256"] == roots["sha256"] || error("runner uses a different initial-root set")
            result["campaign_sha256"] == roots["campaign_sha256"] || error("runner uses a different campaign")
            qualified = get(result, "qualified_roots", result["initial_roots"])
            qualified == roots["count"] || error("runner qualified-root count disagrees")
            root_first = get(result, "root_first", 1)
            root_last = get(result, "root_last", qualified)
            1 <= root_first <= root_last <= qualified || error("runner root interval is invalid")
            result["initial_roots"] == root_last-root_first+1 || error("runner assigned-root count disagrees")
            get(result, "root_order", "forward") in ("forward", "reverse") || error("runner root order is invalid")
            result["attached"] = true
            result
        else
            result = empty_execution(roots)
            database_exists && (result["state"] = "initializing")
            result
        end
        promoted = Int(execution["promoted_parents"])
        completed = Int(execution["completed_parents"])
        previous_execution = get(monitor.snapshot, "execution", Dict{String,Any}())
        get(previous_execution, "attached", false) != execution["attached"] && empty!(monitor.samples)
        if !isempty(monitor.samples) &&
           (promoted < last(monitor.samples)[2] || completed < last(monitor.samples)[3])
            empty!(monitor.samples)
        end
        push!(monitor.samples, (now_seconds, promoted, completed))
        filter!(sample -> now_seconds - sample[1] <= 120, monitor.samples)
        first_sample = first(monitor.samples)
        elapsed = now_seconds - first_sample[1]
        rates = Dict(
            "promoted_per_minute" => elapsed >= 20 ? 60 * (promoted-first_sample[2])/elapsed : nothing,
            "completed_per_minute" => elapsed >= 20 ? 60 * (completed-first_sample[3])/elapsed : nothing,
        )
        execution["attached"] && sample_process_metrics!(monitor, execution, now_seconds)
        monitor.snapshot = Dict{String,Any}(
            "schema" => "vbfsearch-closure-monitor-v1",
            "checked_utc" => string(Dates.now(Dates.UTC)) * "Z",
            "campaign" => basename(monitor.campaign), "roots" => roots,
            "execution" => execution, "rates" => rates,
            "discoveries" => discovery_summary(execution,monitor.comparison),
            "catalog_comparison" => isfile(joinpath(monitor.run,"reports","catalog.json")) ?
                live_catalog_summary(execution,joinpath(monitor.run,"reports","catalog.json")) :
                catalog_summary(execution,joinpath(monitor.campaign,"current-catalog-comparison.json")),
            "published_root_comparison" => published_root_summary(execution,joinpath(monitor.campaign,"current-published-root-comparison.json")),
            "previous_campaign" => previous_campaign_summary(execution,joinpath(monitor.campaign,"current-published-root-comparison.json")),
            "recursive" => recursive_summary(execution),
            "remaining_parents" => execution["total_parents"] - completed,
            "completion_fraction" => completed / max(1, execution["total_parents"]),
        )
        monitor.sampled_at = now_seconds
        monitor.snapshot
    end
end

response(status, payload) = HTTP.Response(status,
    ["Content-Type" => "application/json; charset=utf-8", "Cache-Control" => "no-store"],
    JSON3.write(payload))

function figure_response(monitor, path)
    relative = HTTP.unescapeuri(path)
    parts = String.(split(relative, '/'; keepempty=false))
    any(part -> part in (".", "..") || occursin('\\', part) || occursin('\0', part), parts) &&
        return response(400, Dict("error" => "invalid figure path"))
    isempty(parts) && push!(parts, "index.html")
    file = joinpath(monitor.figures, parts...)
    isfile(file) || return response(404, Dict("error" => "figure not found"))
    resolved = relpath(realpath(file), realpath(monitor.figures))
    (resolved == ".." || startswith(resolved, "../")) &&
        return response(400, Dict("error" => "invalid figure path"))
    mime = get(CONTENT_TYPES, lowercase(splitext(file)[2]), nothing)
    mime === nothing && return response(404, Dict("error" => "figure not found"))
    HTTP.Response(200, ["Content-Type" => mime, "Cache-Control" => "no-cache"], read(file))
end

"""Serve only published graph files, never querying the live search ledger."""
function graph_response(monitor,path)
    parts=String.(split(HTTP.unescapeuri(path),'/';keepempty=false))
    length(parts)==2 || return response(400,Dict("error"=>"invalid graph path"))
    occursin(r"^\d{8}T\d{6}-\d+-\d+$",parts[1]) || return response(400,Dict("error"=>"invalid graph snapshot"))
    occursin(r"^(positions\.bin|edges\.bin|flags\.bin|nodes-\d+\.json)$",parts[2]) || return response(400,Dict("error"=>"invalid graph asset"))
    file=joinpath(monitor.graph,parts...)
    isfile(file) || return response(404,Dict("error"=>"graph snapshot expired; reload the graph"))
    relative=relpath(realpath(file),realpath(monitor.graph))
    (relative==".." || startswith(relative,"../")) && return response(400,Dict("error"=>"invalid graph path"))
    mime=endswith(file,".json") ? "application/json; charset=utf-8" : "application/octet-stream"
    HTTP.Response(200,["Content-Type"=>mime,"Cache-Control"=>"public, max-age=86400, immutable"],read(file))
end

function handle(monitor, request)
    request.method == "GET" || return response(405, Dict("error" => "read-only monitor"))
    path = HTTP.URI(request.target).path
    try
        path in ("/", "/index.html") && return HTTP.Response(200,
            ["Content-Type" => "text/html; charset=utf-8", "Cache-Control" => "no-cache"], read(PAGE))
        path == "/api/progress" && return response(200, snapshot(monitor))
        path in ("/graph","/graph/","/graph.html") && return HTTP.Response(200,
            ["Content-Type"=>"text/html; charset=utf-8","Cache-Control"=>"no-cache"],read(GRAPH_PAGE))
        path == "/graph.js" && return HTTP.Response(200,
            ["Content-Type"=>"application/javascript; charset=utf-8","Cache-Control"=>"no-cache"],read(GRAPH_SCRIPT))
        if path == "/api/graph"
            file=joinpath(monitor.graph,"current.json")
            return isfile(file) ? HTTP.Response(200,["Content-Type"=>"application/json; charset=utf-8","Cache-Control"=>"no-store"],read(file)) :
                response(503,Dict("state"=>"preparing","error"=>"The first graph snapshot is being prepared."))
        end
        startswith(path,"/graph-data/") && return graph_response(monitor,path[length("/graph-data/")+1:end])
        path in ("/structure","/structure/","/structure.html") && return HTTP.Response(200,
            ["Content-Type"=>"text/html; charset=utf-8","Cache-Control"=>"no-cache"],read(STRUCTURE_PAGE))
        path == "/structure.js" && return HTTP.Response(200,
            ["Content-Type"=>"application/javascript; charset=utf-8","Cache-Control"=>"no-cache"],read(STRUCTURE_SCRIPT))
        if path == "/api/structure"
            isempty(monitor.structure) && return response(404,Dict("error"=>"No structure report is configured; start the monitor with --structure PATH."))
            isfile(monitor.structure) || return response(404,Dict("error"=>"The configured structure report is missing."))
            return HTTP.Response(200,["Content-Type"=>"application/json; charset=utf-8","Cache-Control"=>"no-cache"],read(monitor.structure))
        end
        path == "/diagram.svg" && return figure_response(monitor, "slide_pipeline.svg")
        path == "/figures" && return HTTP.Response(302, ["Location" => "/figures/"])
        startswith(path, "/figures/") && return figure_response(monitor, path[length("/figures/")+1:end])
        response(404, Dict("error" => "not found"))
    catch error
        @error "closure monitor read failed" exception=(error, catch_backtrace())
        response(503, Dict("error" => sprint(showerror, error), "checked_utc" => string(Dates.now(Dates.UTC))*"Z"))
    end
end

function main(args=ARGS)
    options = Dict("--host" => "127.0.0.1", "--port" => "8766")
    iseven(length(args)) || error("expected --campaign PATH [--run PATH] [--structure JSON] [--host HOST] [--port PORT]")
    for i in 1:2:length(args)
        args[i] in ("--campaign", "--run", "--host", "--port", "--figures", "--upstream", "--comparison", "--structure") || error("unknown option: $(args[i])")
        options[args[i]] = args[i+1]
    end
    haskey(options, "--campaign") || error("--campaign PATH is required")
    campaign = abspath(options["--campaign"])
    monitor = Monitor(campaign; run=get(options, "--run", joinpath(campaign,"run")),
        figures=get(options, "--figures", joinpath(campaign,"diagrams","gallery")),
        upstream=get(options, "--upstream", ""),comparison=get(options,"--comparison",""),
        structure=get(options,"--structure",""))
    snapshot(monitor; force=true)
    @info "Read-only APN closure monitor" host=options["--host"] port=options["--port"] campaign run=monitor.run
    HTTP.serve(request -> handle(monitor, request), options["--host"], parse(Int, options["--port"]))
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    APNClosureMonitor.main()
end
