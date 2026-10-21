"""Export source-bound profile categories and folded stacks from a warm replay.

Usage: julia --project=<profiled frozen project> closure_profile_categories.jl SUMMARY.json
Uses Julia's installed Profile metadata layout and rejects unsupported layouts.
Categories count sampled stacks containing a frame; their inclusive shares overlap.
These are sample proportions, not replacements for Linux CPU accounting.
"""
module ClosureProfileCategories
using VBFSearch,Profile,Serialization,JSON3,SHA
const summary_path=abspath(only(ARGS))
const summary=JSON3.read(read(summary_path,String),Dict{String,Any})
VBFSearch.code_identity()==summary["implementation"] || error("profile implementation differs")
string(VERSION)==summary["julia"] || error("profile Julia version differs")
Profile.nmeta==4 || error("unsupported Julia profile metadata layout")
const profile_path=summary_path*".cpu-profile.jls"
const saved_profile=deserialize(profile_path)
const data=saved_profile[1]
const lidict=saved_profile[2]
const categories=Dict{String,Function}(
    "ea_packet_preparation"=>s->occursin("_closure_equivalence_packet",s),
    "ea_result_application"=>s->occursin("_closure_equivalence_apply!",s),
    "construction_result_application"=>s->occursin("_closure_apply!",s),
    "candidate_insertion"=>s->occursin("_closure_normalized_candidate",s)||occursin("_closure_record_v5_candidates!",s),
    "sql_binding_or_execution"=>s->occursin("SQLite",s)||occursin("sqlite3_",s),
    "sql_statement_preparation"=>s->occursin("sqlite3_prepare",s)||occursin("sqlite3Prepare",s)||occursin("prepare_stmt_wrapper",s)||occursin("prepare_next (",s)||occursin("sqlite3LockAndPrepare",s),
    "sql_statement_finalization"=>s->occursin("sqlite3_finalize",s)||occursin("sqlite3VdbeDelete",s),
    "toml_parsing"=>s->occursin("toml",lowercase(s))&&occursin("pars",lowercase(s)),
    "toml_printing"=>s->occursin("toml/printer",s),
    "completion_tracking"=>s->occursin("closure_completion.jl",s),
    "reservation"=>s->occursin("reserve_more!",s),
    "publication"=>s->occursin("publish!",s),
    "worker_construction"=>s->occursin("_closure_compute",s),
    "worker_equivalence"=>s->occursin("_closure_equivalence_compute",s),
    "gc_or_allocator"=>s->occursin("gc_",lowercase(s))||occursin("jl_gc",s))
const counts=Dict{Int,Dict{String,Int}}()
const phase_counts=Dict{String,Dict{String,Int}}()
const phase_totals=Dict{String,Int}()
const phase_frames=Dict{String,Dict{String,Int}}()
const totals=Dict{Int,Int}()
const sleeping=Dict{Int,Int}()
const folded=Dict{String,Int}()
const main_folded=Dict{String,Int}()
const frame_cache=Dict{UInt64,Vector{String}}()
function frames(ip)
    get!(frame_cache,ip) do
        value=get(lidict,ip,nothing)
        value===nothing && return String[]
        found=value isa AbstractVector ? value : [value]
        [replace(string(frame.func)*" ("*string(frame.file)*":"*string(frame.line)*")",';'=>',','\n'=>' ') for frame in found]
    end
end
block_start=1
for index in eachindex(data)
    Profile.is_block_end(data,index) || continue
    thread=Int(data[index-Profile.META_OFFSET_THREADID])
    state=data[index-Profile.META_OFFSET_SLEEPSTATE]
    totals[thread]=get(totals,thread,0)+1
    if state==2
        sleeping[thread]=get(sleeping,thread,0)+1
    else
        stack=String[]
        for offset in block_start:index-(Profile.nmeta+2)
            append!(stack,frames(data[offset]))
        end
        text=join(stack,"\n")
        tc=get!(counts,thread,Dict{String,Int}())
        for (name,predicate) in categories
            predicate(text) && (tc[name]=get(tc,name,0)+1)
        end
        if thread==1
            for phase in ("ea_packet_preparation","ea_result_application","construction_result_application")
                categories[phase](text) || continue
                phase_totals[phase]=get(phase_totals,phase,0)+1
                pc=get!(phase_counts,phase,Dict{String,Int}())
                for (name,predicate) in categories
                    predicate(text) && (pc[name]=get(pc,name,0)+1)
                end
                pf=get!(phase_frames,phase,Dict{String,Int}())
                for frame in Set(stack)
                    pf[frame]=get(pf,frame,0)+1
                end
            end
        end
        key=join(reverse(stack),';')
        folded[key]=get(folded,key,0)+1
        thread==1 && (main_folded[key]=get(main_folded,key,0)+1)
    end
    global block_start=index+1
end
function table(threads)
    shots=sum(get(totals,t,0)-get(sleeping,t,0) for t in threads)
    Dict("awake_stacks"=>shots,"sleeping_stacks"=>sum(get(sleeping,t,0) for t in threads),
        "categories"=>Dict(name=>begin
            number=sum(get(get(counts,t,Dict{String,Int}()),name,0) for t in threads)
            Dict("inclusive_stacks"=>number,"awake_stack_fraction"=>shots==0 ? 0.0 : number/shots)
        end for name in keys(categories)))
end
for (suffix,values) in (("all",folded),("coordinator",main_folded))
    open(summary_path*".cpu-profile.$suffix.folded","w") do io
        for (stack,count) in sort!(collect(values);by=first)
            println(io,stack," ",count)
        end
    end
end
result=Dict("all_threads"=>table(keys(totals)),"coordinator_thread_1"=>table([1]),
    "per_thread"=>Dict(string(t)=>table([t]) for t in sort!(collect(keys(totals)))),
    "scope"=>"Inclusive sampled stacks by category; awake metadata excludes Profile-marked sleeping threads, but does not prove running CPU. Categories overlap. Thread 1 is the top-level controller thread used by this replay. Folded stacks contain awake samples only. Linux OS CPU deltas remain authoritative.",
    "coordinator_phase_categories"=>Dict(phase=>Dict("awake_stacks"=>phase_totals[phase],
        "categories"=>Dict(name=>Dict("inclusive_stacks"=>get(phase_counts[phase],name,0),
            "awake_stack_fraction"=>get(phase_counts[phase],name,0)/phase_totals[phase]) for name in keys(categories)),
        "top_inclusive_frames"=>[Dict("frame"=>frame,"stacks"=>number) for (frame,number) in
            first(sort!(collect(phase_frames[phase]);by=pair->-last(pair)),min(200,length(phase_frames[phase])))])
        for phase in keys(phase_totals)),
    "implementation"=>summary["implementation"],"julia"=>string(VERSION),
    "profile_sha256"=>bytes2hex(SHA.sha256(read(profile_path))),
    "tool_sha256"=>bytes2hex(SHA.sha256(read(@__FILE__))))
open(summary_path*".cpu-profile.categories.json","w") do io;JSON3.pretty(io,result);end
println(JSON3.write(result["coordinator_thread_1"]))
end
