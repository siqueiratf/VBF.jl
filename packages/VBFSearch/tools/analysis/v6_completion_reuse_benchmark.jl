"""Bounded real-data parity and cost measurements for the exact-U prototype.

Uses only saved, validated sampled parents and existing VBF APIs. Includes
parent-containing U states as positive completion controls; these controls
are explicitly selected and do not estimate population reuse prevalence.
"""
module V6CompletionReuseBenchmark

using VBF, JSON3, SHA, Dates
include("v6_completion_reuse.jl")
using .V6CompletionReuse
const Q=VBF.QuadraticExtensions

"""Reduce a form to the canonical quotient representative modulo R."""
function quotient_representative(form,R,pivots)
    x=UInt32(form)
    for (r,p) in zip(R,pivots)
        (x>>p)&1==1 && (x ⊻= r)
    end
    x
end

"""Measure four explicit descriptive strata under hard work-count limits."""
function run(input_directory,output_file;max_seconds=180.0,max_cosets=12)
    started=time(); G=Q.geometry(8)
    source=joinpath(input_directory,"parents.json")
    source_sha256=bytes2hex(open(SHA.sha256,source))
    parents=JSON3.read(read(source,String))["parents"]
    chosen=Any[]
    for b in (28,30), queued in (false,true)
        p=first(p for p in parents if p["b5"]==b && p["queued_parent"]==queued)
        push!(chosen,p)
    end
    jobs=Any[];allparity=true;positive=0;direct_count=0
    for p in chosen
        time()-started<max_seconds || break
        need=Int(p["need"])
        lut=UInt16[parse(UInt16,p["lut_hex"][2i-1:2i];base=16) for i in 1:256]
        parent=anf(SBox{8}(UInt8.(lut)))
        coeffs=UInt16[parent[((1<<i)|(1<<j))+1] for i in 0:7 for j in i+1:7]
        S=first(Q.rref(Q.coord_forms(coeffs,8)))
        length(S)==8 || error("parent output rank")
        comp=Q.comp_forms(S);bent=Q.bent_mask(G,comp)
        target_spaces=Q.subspaces_of_comp(comp,bent,6;keep=b->b==52)
        chosen_v5=findfirst(p["maximizing_v5_forms"]) do candidate
            any(u->Q.span_dim(vcat(UInt32.(candidate),u.forms))==6,target_spaces)
        end
        chosen_v5===nothing && error("parent lacks a target U containing a maximizing V5")
        V=UInt32.(p["maximizing_v5_forms"][chosen_v5])
        R,piv=Q.rref(V)
        setup=time()
        work=Q.V5Work(23,8)
        r=Q.coset_bent_counts!(work.cnt,G,V,Q.BETA8)
        X=UInt32[i-1 for i in 2:length(work.cnt) if work.cnt[i]==need*r.scale]
        parent_reps=Set(quotient_representative(q,R,piv) for q in Q.comp_forms(S))
        parent_indices=[i for i in eachindex(X) if Q.lift(X[i],r.Qmask) in parent_reps]
        isempty(parent_indices) && error("published-profile parent lacks an eligible U")
        indices=sort!(unique(vcat(collect(1:min(4,length(X))),parent_indices)))
        length(indices)<=max_cosets || error("explicit coset cap exceeded")
        setup_seconds=time()-setup
        events=Any[]
        batch_started=time()
        batch=Q.v5_extensions(G,V,need,work;beta=Q.BETA8,max_kernel=23,
            selected_coset_indices=indices,coset_observer=e->push!(events,e))
        batch_seconds=time()-batch_started
        states=Any[]
        for event in events
            time()-started<max_seconds || break
            U=first(Q.rref(vcat(V,event.representative)))
            oracle=V6CompletionReuse.complete_state(G,U;max_kernel=23,max_T=100_000)
            direct_count+=1
            equal=oracle.Ss==event.Ss
            certified=oracle.complete && !event.capped
            allparity &= equal && certified
            ispositive=event.index in parent_indices
            ispositive && (positive+=1)
            ispositive && !(S in oracle.Ss) && error("positive U failed to recover its known APN parent")
            push!(states,Dict("index"=>event.index,"forms"=>Int.(U),
                "known_parent_control"=>ispositive,"exact_completion_sets_equal"=>equal,
                "both_complete"=>certified,"completion_count"=>length(oracle.Ss),
                "v5_candidates"=>event.ncand,"standalone_candidates"=>oracle.work.ncand,
                "du_reject"=>event.du_reject,"standalone_seconds"=>oracle.elapsed_seconds))
        end
        # Timing intervals after the first event exclude the shared Fourier
        # setup; every subsequent callback includes the preceding coset work.
        ticks=UInt64[];du_ticks=UInt64[];nondu_ticks=UInt64[];previous=UInt64(0)
        full_started=time()
        full=Q.v5_extensions(G,V,need,work;beta=Q.BETA8,max_kernel=23,
            should_stop=()->time()-started>=max_seconds,
            coset_observer=e->begin
                tick=time_ns()
                if previous!=0
                    delta=tick-previous
                    push!(ticks,delta)
                    push!(e.du_reject==1 ? du_ticks : nondu_ticks,delta)
                end
                previous=tick
            end)
        full_seconds=time()-full_started
        push!(jobs,Dict("parent_id"=>p["parent_id"],"b5"=>p["b5"],
            "queue_state"=>p["queue_state"],"forms"=>Int.(V),"need"=>need,
            "nX"=>batch.nX,"selected_indices"=>indices,"selected_cosets"=>length(events),
            "eligibility_setup_seconds"=>setup_seconds,"v5_batch_seconds"=>batch_seconds,
            "v5_candidates"=>batch.ncand,"v5_completion_count"=>length(batch.Ss),
            "full_v5_seconds"=>full_seconds,"full_v5_complete"=>!full.capped && full.nX_used==full.nX,
            "full_v5_cosets"=>full.nX_used,"full_v5_candidates"=>full.ncand,
            "full_v5_completion_count"=>length(full.Ss),
            "post_first_coset_seconds_including_observer"=>sum(ticks)*1e-9,
            "post_first_du_coset_seconds_including_observer"=>sum(du_ticks)*1e-9,
            "post_first_nondu_coset_seconds_including_observer"=>sum(nondu_ticks)*1e-9,
            "post_first_nondu_coset_count"=>length(nondu_ticks),
            "states"=>states))
    end
    # A nontrivial input-map control is measured on a real positive state.
    control=nothing
    for job in jobs
        state=findfirst(s->s["known_parent_control"],job["states"])
        state===nothing && continue
        U=UInt32.(job["states"][state]["forms"])
        A=UInt16[1<<i for i in 0:7];A[1] ⊻= A[2]
        W=transform_quadratic_space(G,U,A)
        W==U && continue
        cache=V6CompletionReuse.CompletionCache(max_entries=2)
        source_result=V6CompletionReuse.cached_state!(cache,G,U;max_T=100_000)
        source_result.complete || error("uncertified positive source")
        V6CompletionReuse.cached_state!(cache,G,W;source_index=1,input_columns=A,max_T=100_000)
        hits=Float64[]
        for _ in 1:100
            t=time_ns();V6CompletionReuse.cached_state!(cache,G,W;source_index=1,input_columns=A,max_T=100_000)
            push!(hits,(time_ns()-t)*1e-9)
        end
        t=time();hit=V6CompletionReuse.cached_state!(cache,G,W;source_index=1,input_columns=A,max_T=100_000)
        reuse_seconds=time()-t
        oracle=V6CompletionReuse.complete_state(G,W;max_T=100_000)
        allparity &= oracle.complete && hit.Ss==oracle.Ss
        control=Dict("source_forms"=>Int.(U),"target_forms"=>Int.(W),
            "input_columns"=>Int.(A),"map_replayed"=>verify_quadratic_space_transporter(G,U,W,A),
            "exact_completion_sets_equal"=>hit.Ss==oracle.Ss,
            "source_complete"=>source_result.complete,"target_complete"=>oracle.complete,
            "completion_count"=>length(hit.Ss),"reuse_seconds"=>reuse_seconds,
            "warm_reuse_seconds_median"=>sort!(hits)[51],
            "warm_reuse_seconds_minimum"=>minimum(hits),
            "standalone_target_seconds"=>oracle.elapsed_seconds)
        break
    end
    report=Dict("schema"=>"vbfsearch-v6-reuse-kernel-benchmark-v1",
        "created_utc"=>string(now(UTC)),"input"=>abspath(source),
        "input_sha256"=>source_sha256,
        "input_unchanged"=>source_sha256==bytes2hex(open(SHA.sha256,source)),
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "prototype_sha256"=>bytes2hex(open(SHA.sha256,joinpath(@__DIR__,"v6_completion_reuse.jl"))),
        "quadratic_extensions_sha256"=>bytes2hex(open(SHA.sha256,joinpath(@__DIR__,"..","..","..","VBF","src","constructions","quadratic_extensions.jl"))),
        "julia_version"=>string(VERSION),"threads"=>Threads.nthreads(),
        "max_seconds"=>max_seconds,"max_selected_cosets_per_job"=>max_cosets,
        "max_kernel"=>23,"standalone_max_T"=>100_000,
        "elapsed_seconds"=>time()-started,"parity_complete"=>allparity && length(jobs)==4 &&
            direct_count==sum(length(j["selected_indices"]) for j in jobs) && control!==nothing &&
            all(j->j["full_v5_complete"],jobs),
        "direct_state_comparisons"=>direct_count,"known_positive_controls"=>positive,
        "jobs"=>jobs,"real_GL_transport_control"=>control,
        "scope"=>"Descriptive implementation parity controls, not a population reuse estimate; campaign unchanged")
    mkpath(dirname(output_file));write(output_file,JSON3.write(report))
    println(JSON3.write(Dict("output"=>output_file,"parity_complete"=>report["parity_complete"],
        "states"=>direct_count,"positive_controls"=>positive,"seconds"=>time()-started)))
    report
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("usage: v6_completion_reuse_benchmark.jl INPUT_DIRECTORY OUTPUT_JSON")
    run(ARGS[1],ARGS[2])
end
end
