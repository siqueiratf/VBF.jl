"""Differential function-barrier prototype for the unchanged coordinator checks."""
module CoordinatorApplyBarrier
using VBF,VBFSearch,JSON3,SHA,Dates,Statistics
include("coordinator_apply_profile.jl")
const VS=VBFSearch
const Q=VBF.QuadraticExtensions
const A=CoordinatorApplyProfile

function install(source)
    body=match(r"function _closure_apply!\(.*?(?=\nfunction _closure_prepare!)"s,source)
    body===nothing && error("apply source not found")
    original=String(body.match)
    first=only(findall("            cursor=first_x;count_cosets=0;count_candidates=0;count_du=0;count_completions=0;capped=false",original))
    last=only(findall("            cursor==proof[\"next_x\"] && count_cosets==processed",original))
    loop=original[first.start:prevind(original,last.start)]
    helper="function _analysis_apply_coset_loop!(s,current,expected,work,proof,chunks,first_x,flat_records)\n"*loop*
        "    (cursor,count_cosets,count_candidates,count_du,count_completions,capped)\nend"
    call="            cursor,count_cosets,count_candidates,count_du,count_completions,capped = "*
        "_analysis_apply_coset_loop!(s,current,expected,work,proof,chunks,first_x,flat_records)\n"
    optimized=replace(original,loop=>call;count=1)
    optimized=replace(optimized,"function _closure_apply!("=>"function _analysis_apply_barrier!(";count=1)
    reference=replace(original,"function _closure_apply!("=>"function _analysis_apply_reference!(";count=1)
    clone=replace(original,"function _closure_apply!("=>"function _analysis_apply_clone!(";count=1)
    Core.eval(VS,Meta.parse("begin\n"*helper*"\n"*optimized*"\n"*reference*"\n"*clone*"\nend"))
    (baseline=Base.invokelatest(getfield,VS,:_analysis_apply_reference!),
        clone=Base.invokelatest(getfield,VS,:_analysis_apply_clone!),
        barrier=Base.invokelatest(getfield,VS,:_analysis_apply_barrier!),native=VS._closure_apply!)
end

function run(holdout_path,parents_path,out;repeats=10)
    started=time();mkpath(out)
    native_source=joinpath(dirname(pathof(VS)),"closure_algorithms.jl")
    source_path=get(ENV,"VBF_COORDINATOR_APPLY_BASELINE",native_source)
    source=read(source_path,String);write(joinpath(out,"closure_algorithms-baseline.jl"),source)
    funcs=install(source)
    records=[first(JSON3.read(read(holdout_path,String))["records"])]
    parents=Dict(Int(p["parent_id"])=>p for p in JSON3.read(read(parents_path,String))["parents"])
    s,jobs=A.ClosureWorkerIntegrationAudit.fixture(joinpath(out,"isolated-fixture"),records,parents)
    try
        job=only(jobs);packet=VS._closure_work_packet(s,job)
        context=VS.ClosureWorkContext(;rank_table=Q.PackedPolarRankTable(Q.geometry(8)))
        result=VS._closure_compute(packet;context,seconds=60,evaluations=256)
        base=A.snapshot(s);root=packet["parent"]["lut_sha256"]
        expected=nothing
        for f in values(funcs)
            VS._closure_exec(s.db,"BEGIN IMMEDIATE")
            Base.invokelatest(f,s,job,result)
            observed=A.snapshot(s)
            expected===nothing ? (expected=observed) : isequal(observed,expected) || error("warmup persisted rows differ")
            VS._closure_exec(s.db,"ROLLBACK")
            isequal(A.snapshot(s),base) || error("warmup rollback differs")
        end
        timings=Dict(string(mode)=>Any[] for mode in keys(funcs))
        for rep in 1:repeats
            order=isodd(rep) ? keys(funcs) : reverse(keys(funcs))
            for mode in order
                t=@timed Base.invokelatest(funcs[mode],s,job,result)
                push!(timings[string(mode)],Dict("seconds"=>t.time,"allocated_bytes"=>t.bytes,"gc_seconds"=>t.gctime))
                isequal(A.snapshot(s),expected) || error("atomic persisted rows differ")
                A.reset!(s,job,root);isequal(A.snapshot(s),base) || error("reset differs")
            end
        end
        bad=copy(result);badwork=copy(result["work"]);badwork["done"]=false;bad["work"]=badwork
        for f in values(funcs)
            rejected=false
            try Base.invokelatest(f,s,job,bad) catch e
                occursin("extension completion flag mismatch",sprint(showerror,e)) || rethrow()
                rejected=true
            end
            rejected && isequal(A.snapshot(s),base) || error("late error not atomic")
        end
        summary=Dict(k=>Dict("median_seconds"=>median(r["seconds"] for r in rows),
            "median_allocated_bytes"=>median(r["allocated_bytes"] for r in rows)) for (k,rows) in timings)
        report=Dict("schema"=>"coordinator-apply-barrier-v1","created_utc"=>string(now(UTC))*"Z",
            "source_sha256"=>bytes2hex(sha256(source)),"source_unchanged"=>read(source_path,String)==source,
            "source_path"=>abspath(source_path),"native_source_sha256"=>A.sha(native_source),
            "threads"=>Threads.nthreads(),"processed_cosets"=>length(result["work"]["chunks"]),
            "candidate_records"=>length(result["work"]["records"]),"timings"=>timings,"summary"=>summary,
            "speedup"=>summary["baseline"]["median_seconds"]/summary["barrier"]["median_seconds"],
            "clone_control_speedup"=>summary["clone"]["median_seconds"]/summary["barrier"]["median_seconds"],
            "all_persisted_rows_exact"=>true,"late_failure_atomicity"=>true,"elapsed_seconds"=>time()-started,
            "scope"=>"One existing complete V5 packet; unchanged validation loop moved behind a concrete chunks function barrier; all SQL and checks remain in one WAL/FULL transaction; disposable fixture only.")
        write(joinpath(out,"report.json"),JSON3.write(report));println(JSON3.write(report));flush(stdout)
        report
    finally
        VS._closure_close(s)
    end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==3 || error("usage: coordinator_apply_barrier HOLDOUT PARENTS NEW_OUT")
    run(ARGS...)
end
end
