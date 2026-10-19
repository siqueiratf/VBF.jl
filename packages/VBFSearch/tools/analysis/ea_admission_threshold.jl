"""Source-derived bounded direct-incidence/FWHT crossover experiment.

Only the existing workspace crossover is changed. Native VBF score kernels,
refinement, RNG, backtracking and graph certificate verification are reused.
No production methods are replaced, and no database is opened.
"""
module EAAdmissionThreshold
using VBF,VBFSearch,JSON3,SHA,Statistics,Dates,Random
include("ea_admission_profile.jl")
const FP=VBFSearch
const SEARCH_SHA="ba9597fa150b71288a17ee85ae5c47c58ff89ef48abdde969460f25522cdf3e6"

function once(source,old,new)
    length(findall(old,source))==1 || error("native crossover source changed")
    replace(source,old=>new;count=1)
end

function install(source_path)
    bytes2hex(open(SHA.sha256,source_path))==SEARCH_SHA || error("pinned native reference changed")
    Core.eval(VBF,quote
        function _ea_admission_threshold_workspace(d,npoints,nplanes,threshold;kwargs...)
            w=_PRWorkspace(d,npoints,nplanes;kwargs...)
            fields=ntuple(i->i==11 ? threshold : getfield(w,i),fieldcount(typeof(w)))
            _PRWorkspace(fields...)
        end
    end)
    source=read(source_path,String)
    body=match(r"function partition_refinement_equivalence\(.*?(?=\n\"\"\"Validate an equivalence API)"s,source)
    body===nothing && error("cannot find pinned native solver")
    variant=once(String(body.match),"function partition_refinement_equivalence(","function _ea_admission_threshold_equivalence(")
    variant=once(variant,"threaded::Bool = false,","threaded::Bool = false, direct_threshold::Int = 4096, trace=nothing,")
    variant=once(variant,"work = _PRWorkspace((N+M), length(left), nplanes; threaded, algorithm, rng)",
        "work = _ea_admission_threshold_workspace((N+M), length(left), nplanes, direct_threshold; threaded, algorithm, rng, trace)")
    Core.eval(VBF,Meta.parse(variant));Base.invokelatest(getfield,VBF,:_ea_admission_threshold_equivalence)
end

function outcome(r)
    Dict("kind"=>string(nameof(typeof(r))),"nodes"=>r.nodes_visited,
        "witnesses"=>[Dict("columns"=>Int.(m.linear.cols),"constant"=>Int(m.constant)) for m in r.functions],
        "stop"=>r isa VBF.BudgetHit ? string(r.where_it_stopped.reason) : "none")
end

function tracer()
    ctx=SHA.SHA2_256_CTX();events=Ref(0)
    trace=function(event,pl,pr,hl,hr)
        events[]+=1;SHA.update!(ctx,codeunits(String(event)))
        for p in (pl,pr,hl,hr),a in (p.order,p.starts)
            SHA.update!(ctx,reinterpret(UInt8,Int64[length(a)]));SHA.update!(ctx,reinterpret(UInt8,a))
        end
    end
    trace,()->Dict("events"=>events[],"sha256"=>bytes2hex(SHA.digest!(ctx)))
end

function run(input,source,out;thresholds=(4096,8192,16384,typemax(Int)),repeats=4,max_seconds=90.0)
    started=time();mkpath(out);native=install(source);before=FP.equivalence_solver_fingerprint()
    ps=filter(p->!isempty(p["targets"]),EAAdmissionProfile.packets(input));rows=Any[]
    for p in ps
        time()-started<max_seconds || error("bounded crossover probe expired")
        F=SBox{8,UInt8}(hex2bytes(p["lut_hex"]));G=SBox{8,UInt8}(hex2bytes(first(p["targets"])["lut_hex"]))
        baseline=VBF.partition_refinement_equivalence(F,G;relation=:ea,timeout_seconds=2,max_nodes=100_000)
        expected=outcome(baseline)
        expected["kind"]=="Found" || error("control pair no longer resolves")
        trace_reference=nothing;measurements=Dict{String,Any}()
        for threshold in thresholds
            call=()->Base.invokelatest(native,F,G;relation=:ea,timeout_seconds=2,max_nodes=100_000,direct_threshold=threshold)
            warm=call();outcome(warm)==expected || error("crossover changed native result or node order")
            trace,finish=tracer()
            r=Base.invokelatest(native,F,G;relation=:ea,timeout_seconds=2,max_nodes=100_000,direct_threshold=threshold,trace)
            outcome(r)==expected || error("traced crossover result differs")
            digest=finish()
            trace_reference===nothing ? (trace_reference=digest) : digest==trace_reference || error("ordered partition trace changed")
            all(m->FP.verify_graph_witness(F,G,m;relation=:ea),r.functions) || error("crossover graph witness failed full replay")
            measurements[string(threshold)]=Dict("measurements"=>Any[],
                "partition_trace"=>digest,"exact_status_nodes_witness_partition_parity"=>true)
        end
        # Rotate each threshold through every order position; all paths are
        # compiled and traced before these timed measurements.
        for rep in 1:repeats,threshold in circshift(collect(thresholds),rep-1)
            t=@timed Base.invokelatest(native,F,G;relation=:ea,timeout_seconds=2,max_nodes=100_000,direct_threshold=threshold)
            outcome(t.value)==expected || error("crossover differential mismatch")
            push!(measurements[string(threshold)]["measurements"],
                Dict("seconds"=>t.time,"bytes"=>t.bytes,"gc_seconds"=>t.gctime))
        end
        for entry in values(measurements)
            entry["median_seconds"]=median(t["seconds"] for t in entry["measurements"])
            entry["median_bytes"]=median(t["bytes"] for t in entry["measurements"])
        end
        push!(rows,Dict("candidate_id"=>p["candidate_id"],"native_outcome"=>expected,"thresholds"=>measurements))
        println(JSON3.write(last(rows)));flush(stdout)
    end
    controls=Any[]
    for n in (3,4,5),relation in (:ea,:ccz)
        F=gold_apn(n);G=SBox{n,UInt8}(UInt8.(F.lut) .⊻ UInt8(1))
        for (kind,target) in (("translated",G),("degree_separated",SBox{n,UInt8}(zeros(UInt8,1<<n))))
            expected=outcome(VBF.partition_refinement_equivalence(F,target;relation,timeout_seconds=2,max_nodes=100_000))
            for threshold in (0,256,4096)
                r=Base.invokelatest(native,F,target;relation,timeout_seconds=2,max_nodes=100_000,direct_threshold=threshold)
                outcome(r)==expected || error("general-dimension crossover control differs")
            end
            push!(controls,Dict("n"=>n,"relation"=>String(relation),"kind"=>kind,"outcome"=>expected,"parity"=>true))
        end
    end
    report=Dict("schema"=>"ea-admission-direct-fwht-crossover-v1","created_utc"=>string(now(UTC))*"Z",
        "pinned_search_source_sha256"=>SEARCH_SHA,"input_sha256"=>bytes2hex(open(SHA.sha256,input)),
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "solver_sources_sha256"=>before,"sources_unchanged"=>before==FP.equivalence_solver_fingerprint(),
        "records"=>rows,"general_controls"=>controls,"elapsed_seconds"=>time()-started,"threads"=>Threads.nthreads(),
        "scope"=>"Eight actual positive EA pairs from captured pending jobs; exact native status/nodes/witness and every ordered partition trace. Source-derived constructor-only analysis variant; no production replacement, SQLite access or campaign restart. Thresholds rotate through every order position after warmup and tracing; descriptive controls, not population throughput.")
    write(joinpath(out,"report.json"),JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==3 || error("usage: ea_admission_threshold CAPTURED_INPUTS PINNED_SEARCH_SOURCE NEW_OUTPUT")
    run(ARGS...)
end
end
