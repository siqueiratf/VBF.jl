"""Scientific coverage, bounded plans and failure retention for RAM closure search."""
module RAMClosureSearchTests
using Test,VBF,VBFSearch
include(joinpath(@__DIR__,"..","tools","ram_closure_search.jl"))
const R=RAMClosureSearch
const S=R.RAMClosureStore
const ROOT=hex2bytes("00000079003b96d40083a55feb53d819009efe19a005c814cfd294f084a2491600094b3be0d23d7679f3976472c30ac220b7957b60cc4396968286eb3d12bbed002d13470c1a89e6802e36e167f247ab10a3fd37bc34c7365f6f175e1813c6b404205c01e8f72640fd5a00defa669174348e925178f948b0023b0141a5a7304b00598aaa04661803409a6fccaf4e168e08cf7cc2ac504ecb87c3566bc8b78f890252c3eae68db1a33be85ff534dcc6572ae415a26e9bc74bdc91467273057f700175989509460630c136fd7322ee883d19f37eedb16040e8167fd4c45507012a077ad5d1efa9ab94be40c94ebd785ce03fdc138977afcd6c4929c0d9eab1f5d7")

"""Known VBF-verified fixture identities exercise the pure audited-input boundary."""
function fixture(luts=[ROOT])
    rows=[let p=VBFSearch.properties(lut)
        (lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="ram-fixture:$i",root_index=i)
    end for (i,lut) in enumerate(luts)]
    (;identity=Dict{String,Any}("schema"=>VBFSearch.CLOSURE_SCHEMA,"initial_roots"=>length(rows),
        "qualification_complete"=>true,"inputs"=>Dict{String,Any}(),
        "scientific"=>Dict{String,Any}("n"=>8,"m"=>8,"target_b6"=>52)),roots=rows)
end

"""Keep all fixture tests under small, explicit pool budgets."""
config(workers=1)=Dict{String,Any}("concurrency"=>workers,"precompute_rank_table"=>false,
    "candidate_capacity"=>4096,"class_capacity"=>4096,"comparison_capacity"=>128,
    "comparison_bytes"=>16*1024^2,"evidence_bytes"=>64*1024^2,"plan_bytes"=>128*1024^2,
    "plan_reservation_bytes"=>64*1024^2,"plan_builders"=>workers,"extension_cosets"=>4096,
    "switching_directions"=>32,"window_size"=>2,"reservation_horizon"=>max(4,2workers),
    "rss_limit_bytes"=>2*1024^3,"minimum_available_bytes"=>512*1024^2,"initial_only"=>true,
    "report_interval_seconds"=>Inf)

@testset "Builder defaults fit the active plan reservation budget" begin
    @test R.default_plan_builders(24,2*1024^3,64*1024^2)==24
    @test R.default_plan_builders(24,512*1024^2,64*1024^2)==8
    @test R.default_plan_builders(24,512*1024^2,128*1024^2)==4
    @test R.default_plan_builders(2,2*1024^3,64*1024^2)==2
    @test_throws ArgumentError R.default_plan_builders(24,512*1024^2,0)
end

@testset "Exclusive Walsh leases, idle eviction and joined cleanup" begin
    cfg=config();cfg["plan_bytes"]=192*1024^2
    state=R.initialize(fixture(),cfg)
    for job in 1:3
        @test R.reserve_plan!(state,R.Item(id=job,kind=:plan,job=job))
    end
    buffers=[state.plans[job].walsh_buffer for job in 1:3]
    @test length(unique(objectid.(buffers)))==3
    @test state.plan_bytes==192*1024^2
    @test !R.reserve_plan!(state,R.Item(id=4,kind=:plan,job=4))
    lease=state.plans[1];lease.plan=(;walsh=buffers[1]);lease.remaining=2
    @test_throws ArgumentError R.release_plan!(state,1)
    lease.remaining=1
    @test_throws ArgumentError R.release_plan!(state,1)
    @test isempty(state.walsh_idle)
    for job in 1:3
        state.plans[job].plan=(;walsh=buffers[job]);state.plans[job].remaining=0
        R.release_plan!(state,job)
    end
    @test state.walsh_live_bytes==0
    @test state.plan_bytes==state.walsh_idle_bytes==sum(Base.summarysize, buffers)
    cfg=state.config;cfg["plan_bytes"]=96*1024^2;cfg["plan_reservation_bytes"]=96*1024^2
    @test R.reserve_plan!(state,R.Item(id=4,kind=:plan,job=4))
    @test any(state.plans[4].walsh_buffer===buffer for buffer in buffers)
    @test state.walsh_reuses==1 && state.walsh_evictions==2
    @test state.plan_bytes==96*1024^2 && state.walsh_idle_bytes==0
    # A failed build remains leased until the pool has joined. Cleanup is the
    # sole joined path allowed to discard an unfinished builder/consumer.
    state.contexts[1].v5_plan=state.plans[4]
    @test_throws ArgumentError R.release_plan!(state,4)
    R.cleanup_work!(state)
    @test isempty(state.plans) && isempty(state.walsh_idle) && isempty(state.builders)
    @test state.plan_bytes==state.walsh_live_bytes==state.walsh_idle_bytes==0
    @test all(context.v5_plan===nothing for context in state.contexts)
    @test state.plan_builder_count==1 && R.stats(state).property_cache_released
end

@testset "Copied RAM provenance and bounded shared property cache" begin
    inputs=fixture();inputs.identity["scientific"]["scheduling"]="historical schedule"
    inputs.identity["scientific"]["source_pin"]="unchanged mathematics"
    inputs.identity["root_selection"]=Dict("first"=>1,"last"=>1)
    before=deepcopy(inputs.identity);workers=min(2,Threads.nthreads(:default))
    state=R.initialize(inputs,config(workers))
    @test inputs.identity==before
    @test state.identity["scientific"]["scheduling"]==R.RAM_SCHEDULING
    @test state.identity["scientific"]["execution_backend"]=="ram"
    @test state.identity["scientific"]["source_pin"]=="unchanged mathematics"
    @test state.identity["root_selection"]==before["root_selection"]
    @test all(context.property_cache===state.contexts[1].property_cache for context in state.contexts)
    @test R.property_cache_stats(state)["capacity"]==8192
    @test R.property_cache_stats(state)["caches"]==1
    VBFSearch.DiscoveryEvidence.properties(ROOT;cache=state.contexts[1].property_cache)
    VBFSearch.DiscoveryEvidence.properties(ROOT;cache=state.contexts[end].property_cache)
    cached=R.property_cache_stats(state)
    @test cached["entries"]==1 && cached["hits"]>=1
    R.cleanup_work!(state)
    @test R.property_cache_stats(state)==cached
    @test isempty(state.contexts[1].property_cache.values)
    cfg=config(workers);cfg["shared_property_cache_entries"]=0
    private=R.initialize(inputs,cfg)
    @test R.property_cache_stats(private)["caches"]==workers
    @test R.property_cache_stats(private)["capacity"]==64workers
    R.cleanup_work!(private)
end

@testset "Compressed transport compacts properties and preserves outer witnesses" begin
    properties=VBFSearch.properties(zeros(UInt8,256))
    properties["transport_only_test"]=collect(1:100)
    record=Dict{String,Any}("event"=>"candidate_complete","direction"=>7,
        "cursor"=>"7:2","properties"=>properties,"witness"=>Dict("construction"=>[1,2,3]),
        "other_outer_field"=>Dict("retained"=>true))
    events=Any[Dict("event"=>"direction_complete","direction"=>7),record]
    work=Dict{String,Any}("events"=>events,"proof"=>Dict("coverage"=>"complete"),"done"=>true)
    packet=Dict{String,Any}("kind"=>"switching","job_id"=>1)
    restored=R.decode_frame(R.encode_frame(packet,Dict("work"=>work),1024^2))
    @test restored.work["property_format"]==S.COMPACT_RECORD_PROPERTIES_FORMAT
    @test restored.work["proof"]==work["proof"]
    @test restored.work["events"][1]==events[1]
    compact=restored.work["events"][2]
    @test all(compact[key]==record[key] for key in keys(record) if key!="properties")
    @test !haskey(compact["properties"],"transport_only_test")
    @test compact["properties"]["differential_uniformity"]==properties["differential_uniformity"]
    @test compact["properties"]["non_apn_witness"]==properties["non_apn_witness"]
    @test haskey(record["properties"],"transport_only_test")
end

"""Canonicalize scientific rows independently of task/plan completion order."""
function science(result)
    state=result.state
    candidates=sort!([(r.id,r.lut_hex,r.sigma,r.apn,r.degree) for r in S.candidate_rows(result.store)];by=first)
    groups=Dict{Int,Vector{String}}()
    for row in S.candidate_rows(result.store)
        row.class_id==0 || push!(get!(groups,row.class_id,String[]),row.id)
    end
    partition=sort!([sort!(ids) for ids in values(groups)];by=first)
    paths=Any[];kernels=Dict{Any,Any}();chunks=Any[];directions=Int[]
    for item in R.evidence_frames(state)
        item.applied || continue
        restored=R.decode_frame(item.frame);packet=restored.packet;work=restored.work
        key=packet["job_key"]
        if packet["kind"]=="v5"
            for record in work["records"]
                push!(paths,(key,record["cursor"],record["properties"]["lut_sha256"],VBFSearch._closure_text(record["witness"])))
            end
            if work["ledger"]!==nothing
                row=Dict(String(k)=>v for (k,v) in pairs(work["ledger"]))
                for chunk in VBFSearch._closure_unpack_chunks(row)
                    push!(chunks,(key,chunk["first_x"],chunk["next_x"],chunk["total_x"],chunk["capped"],chunk["evidence"]))
                end
            end
        elseif packet["kind"]=="switching"
            for event in work["events"]
                if event["event"]=="kernel"
                    kernels[(key,event["direction"])]=(event["dimension"],VBFSearch._closure_text(event["evidence"]))
                elseif event["event"]=="candidate_complete"
                    push!(paths,(key,event["cursor"],event["properties"]["lut_sha256"],VBFSearch._closure_text(event["witness"])))
                elseif event["event"]=="direction_complete"
                    push!(directions,event["direction"])
                end
            end
        end
    end
    (;candidates,partition,paths=sort!(paths),kernels,chunks=sort!(chunks),directions=sort!(directions))
end

@testset "RAM search classifies before expansion and reproduces complete root evidence" begin
    inputs=fixture();snapshots=Any[]
    sequential=R.run_inputs(inputs,config();on_progress=x->push!(snapshots,x))
    sequential.state.failure===nothing || (showerror(stderr,sequential.state.failure.error,sequential.state.failure.backtrace);println(stderr))
    @test sequential.report["state"]=="initial_complete"
    @test sequential.report["seed_statistics"]["published_completed_this_session"]==1
    @test sequential.report["seed_statistics"]["construction_completed"]==1
    @test all(row.status=="done" for row in R.job_rows(sequential.state))
    @test isempty(sequential.state.plans) && sequential.state.plan_bytes==0
    @test sequential.state.peak_plan_bytes<=128*1024^2
    @test all(==(1),sequential.state.frame_applied)
    @test sequential.state.evidence_bytes<=64*1024^2
    @test S.stats(sequential.store).full_property_records_retained==0
    @test all(r->!r.apn || r.degree!=2 || r.class_id!=0,S.candidate_rows(sequential.store))
    expected=science(sequential)
    @test expected.directions==collect(1:255)
    @test length(expected.chunks)==14716
    @test [c[2] for c in expected.chunks]==collect(1:14716)
    @test !isempty(expected.paths)
    @test all(j.parent_id==1 for j in R.job_rows(sequential.state))
    workers=min(2,Threads.nthreads(:default))
    parallel=R.run_inputs(inputs,config(workers))
    @test parallel.report["state"]=="initial_complete"
    @test science(parallel)==expected
    @test parallel.state.plan_builds==1
    @test all(c->c.v5_plan===nothing && !islocked(c.guard),parallel.state.contexts)
    @test all(length(c.work.cnt)==1 && length(c.work.g5)==1 for c in parallel.state.contexts)
    @test length(unique(objectid(c.work) for c in parallel.state.contexts))==workers
    @test parallel.report["pool_metric_scope"]=="most recent cohort"
    @test R.stats(parallel.state).property_cache_released
    @test isempty(parallel.state.walsh_idle) && isempty(parallel.state.builders)
    @test !isempty(snapshots)
    @test length(sequential.state.config["ram_controller_sources"])==5
    @test all(length(hash)==64 for hash in values(sequential.state.config["ram_controller_sources"]))
    frame=first(parallel.state.frames)
    changed=copy(frame.bytes);changed[end]⊻=UInt8(1)
    broken=R.EvidenceFrame(frame.job_id,frame.kind,frame.raw_bytes,frame.sha256,changed)
    @test_throws Exception R.decode_frame(broken)
    @test_throws ArgumentError R.decode_frame(frame;max_bytes=1)
end

@testset "Recursive execution expands admitted representatives after published roots" begin
    cfg=config();cfg["initial_only"]=false;cfg["window_size"]=1
    cfg["report_interval_seconds"]=0.0
    snapshots=Any[];stop=Ref(false)
    result=R.run_inputs(fixture(),cfg;stop_requested=()->stop[],on_progress=snapshot->begin
        push!(snapshots,snapshot)
        snapshot.construction_completed>=2 && (stop[]=true)
    end)
    @test result.report["state"] in ("paused_external","exhausted")
    @test result.state.settled_roots==1
    @test any(snapshot.admission_settled==1 for snapshot in snapshots)
    @test all(snapshot.admission_settled==1 for snapshot in snapshots if snapshot.construction_completed>1)
    expanded=Set(job.parent_id for job in R.job_rows(result.state) if job.status!="pending")
    @test all(1<=parent<=S.stats(result.store).class_count for parent in expanded)
    representatives=Set(S.class_record(result.store,parent).candidate_slot for parent in expanded)
    @test all(S.candidate(result.store,slot).class_id in expanded for slot in representatives)
    equivalent=[slot for slot in 1:S.stats(result.store).candidate_count if
        S.candidate(result.store,slot).class_id!=0 &&
        S.class_record(result.store,S.candidate(result.store,slot).class_id).candidate_slot!=slot]
    @test all(!(slot in representatives) for slot in equivalent)
    if S.stats(result.store).class_count>1
        @test result.state.completed_construction>=2
        @test any(>(1),expanded)
    else
        @test result.report["state"]=="exhausted"
    end
end

@testset "Published prefix still preadmits its entire audited comparison registry" begin
    inputs=fixture([ROOT,gold_apn(8).lut])
    cfg=config();cfg["root_limit"]=1
    result=R.run_inputs(inputs,cfg)
    @test result.report["state"]=="initial_complete"
    @test result.report["seed_statistics"]["published_registry"]==2
    @test result.report["seed_statistics"]["published_selected"]==1
    @test S.class_record(result.store,2).candidate_id==inputs.roots[2].lut_sha256
    @test all(j.status=="pending" for j in R.job_rows(result.state) if j.parent_id==2)
    @test result.state.parents[1].settled && !result.state.parents[2].settled
end

@testset "Capacity and external memory stops preserve bounded inspectable state" begin
    inputs=fixture();small=config();small["evidence_bytes"]=1
    result=R.run_inputs(inputs,small)
    @test result.report["state"]=="paused_capacity"
    @test result.state.failure.error isa R.CapacityStop
    @test result.state.failure.error.retained isa R.EvidenceFrame
    @test result.state.evidence_bytes==result.state.drained_bytes>1
    @test !isempty(result.state.frames) && all(==(0),result.state.frame_applied)
    @test isempty(result.state.completed_frames)
    @test isempty(result.state.plans)
    @test all(c->c.v5_plan===nothing && !islocked(c.guard),result.state.contexts)
    stopped=R.run_inputs(inputs,config();stop_requested=()->true)
    @test stopped.report["state"]=="paused_external"
    @test stopped.report["processed_packets"]==0
    @test S.stats(stopped.store).class_count==1
    @test isempty(stopped.state.frames)
    memory=config();memory["rss_limit_bytes"]=1
    protected=R.run_inputs(inputs,memory)
    @test protected.report["state"]=="paused_rss_limit"
    @test protected.report["processed_packets"]==0
    bad=config();bad["plan_bytes"]=1
    @test_throws ArgumentError R.run_inputs(inputs,bad)
end

@testset "Joined application failures retain both independently completed workers" begin
    if Threads.nthreads(:default)>=2
        cfg=config(2);cfg["evidence_bytes"]=1
        state=R.initialize(fixture(),cfg)
        items=[R.Item(id=1,kind=:math,parent=1,job=1),
            R.Item(id=2,kind=:math,parent=1,job=2,first=1,last=1)]
        remaining=copy(items);finished=Channel{Int}(2);release=Channel{Nothing}(2)
        reserve=(limit,excluded)->begin
            n=min(limit,length(remaining));selected=remaining[1:n];deleteat!(remaining,1:n);selected
        end
        compute=(prepared,slot,stop)->begin
            value=R.compute_item(state,prepared,slot,()->false)
            put!(finished,prepared.item.id);take!(release);value
        end
        coordinator=@async try
            R.run_refill_pool!(reserve,(item,ticket,slot)->R.prepare_item(state,item,ticket,slot),compute,
                (prepared,value,seconds,meta)->R.apply_item!(state,prepared,value,seconds,meta);
                concurrency=2,max_pending=2,key=item->item.id)
            nothing
        catch error
            error
        end
        @test timedwait(()->isready(finished)||istaskdone(coordinator),30.0)==:ok
        first=isready(finished) ? take!(finished) : 0
        @test timedwait(()->isready(finished)||istaskdone(coordinator),30.0)==:ok
        second=isready(finished) ? take!(finished) : 0
        @test sort!([first,second])==[1,2]
        @test length(state.completed_frames)==2
        put!(release,nothing);put!(release,nothing)
        @test fetch(coordinator) isa R.CapacityStop
        R.drain_frames!(state)
        @test length(state.frames)==2
        @test state.frame_applied==UInt8[0,0]
        @test sort!(state.frame_tasks)==[1,2]
        @test isempty(state.completed_frames)
        @test all(!get(R.decode_frame(frame).work,"noop",false) for frame in state.frames)
        @test Set(frame.kind for frame in state.frames)==Set([:prepare_v5,:switching])
        @test state.evidence_bytes==state.drained_bytes
    else
        @test_skip Threads.nthreads(:default)>=2
    end
end

@testset "Comparison capacity retains its computed verified witness" begin
    cfg=config();cfg["comparison_capacity"]=0
    state=R.initialize(fixture(),cfg)
    p=VBFSearch.properties(ROOT .⊻ UInt8(1))
    slot,_=S.observe_candidate!(state.store,p;trusted=true)
    @test S.classify_if_empty!(state.store,slot).status==:requires_comparison
    item=R.Item(id=1,kind=:admission,candidate=slot)
    prepared=R.prepare_item(state,item,1,1)
    result=R.compute_item(state,prepared,1,()->false)
    @test length(state.completed_frames)==1
    @test any(c->c["proof"]["status"]=="equivalent_with_verified_witness",result["comparisons"])
    @test_throws S.StoreFull R.apply_item!(state,prepared,result,0.0,(;ticket=1,slot=1,ready_wait_seconds=0.0))
    R.drain_frames!(state)
    @test length(state.frames)==1 && state.frame_applied==UInt8[0]
    @test only(state.frames).kind==:deduplicate
    restored=R.decode_frame(only(state.frames))
    @test restored.work.result["candidate_id"]==p["lut_sha256"]
    proof=only(restored.work.result["comparisons"])["proof"]
    @test VBFSearch.verify_comparison(proof)
end

@testset "Mathematical output limits preserve prior complete-coset evidence" begin
    cfg=config();cfg["max_packet_records"]=0
    result=R.run_inputs(fixture(),cfg)
    @test result.report["state"]=="paused_capacity"
    @test result.state.failure.error isa VBFSearch._ClosureWorkCapacity
    failures=[item for item in R.evidence_frames(result.state) if item.frame.kind==:worker_failure]
    @test !isempty(failures)
    @test all(!item.applied for item in failures)
    retained=R.decode_frame(first(failures).frame).work["retained"]
    @test retained.coset==308
    @test length(retained.chunks)==307
    @test isempty(result.state.completed_frames)
    @test all(c->c.v5_plan===nothing && !islocked(c.guard),result.state.contexts)
end
end
