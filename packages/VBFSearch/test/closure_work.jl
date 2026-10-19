using Test,VBF,VBFSearch,TOML
isdefined(@__MODULE__,:closure_fixture) || include("closure.jl")
const WorkVS=VBFSearch
@testset "Immutable coset views preserve dictionary and transport contracts" begin
    p=WorkVS._ClosureCosetProof((1,3,7,15,31),4,5,10,0,23,2,7,101,false)
    expected=Dict{String,Any}("first_x"=>4,"next_x"=>5,"total_x"=>10,"capped"=>false,
        "candidate_spaces"=>0,"linear_system_candidates"=>23,"du_reject"=>2,
        "completion_spaces"=>7,"coset_representative"=>101,"heuristic_pruning"=>false,
        "V5_forms"=>[1,3,7,15,31],"coset_order"=>WorkVS._CLOSURE_COSET_ORDER)
    @test p==expected
    @test Dict(p)==expected
    @test length(p)==12
    @test haskey(p,"first_x") && !haskey(p,:first_x) && !haskey(p,"unknown")
    @test haskey(p,SubString("first_x")) && p[SubString("first_x")]==4
    @test get(p,"unknown",:missing)===:missing
    @test_throws KeyError p["unknown"]
    @test_throws KeyError p[:first_x]
    forms=p["V5_forms"];forms[1]=999
    @test p["V5_forms"]==[1,3,7,15,31]
    editable=copy(p);editable["first_x"]=999;editable["V5_forms"][1]=999
    @test p==expected
    @test WorkVS._closure_coset_evidence_text(p)==WorkVS._closure_text(expected)
    chunk=WorkVS._ClosureCosetChunk(p,nothing)
    legacy=Dict{String,Any}("proof"=>expected,"records"=>Dict{String,Any}[],"processed_cosets"=>1)
    @test chunk==legacy
    @test collect(chunk["records"])==Dict{String,Any}[]
    @test_throws BoundsError chunk["records"][1]
    @test_throws MethodError push!(chunk["records"],Dict{String,Any}())
    @test WorkVS.JSON3.read(WorkVS.JSON3.write(chunk),Dict{String,Any})==legacy
    editable_chunk=copy(chunk);push!(editable_chunk["records"],Dict("example"=>1))
    @test isempty(chunk["records"])
    @test chunk==legacy
    record=Dict{String,Any}("properties"=>Dict("example"=>1))
    populated=WorkVS._ClosureCosetChunk(p,[record])
    @test populated["records"]==[record]
    @test WorkVS.JSON3.read(WorkVS.JSON3.write(populated),Dict{String,Any})==copy(populated)
end

@testset "Worker contexts share only an explicit read-only rank table" begin
    Q=VBF.QuadraticExtensions;table=Q.PolarRankTable(Q.geometry(4))
    first_context=WorkVS.ClosureWorkContext(;rank_table=table)
    second_context=WorkVS.ClosureWorkContext(;rank_table=table)
    @test first_context.rank_table===second_context.rank_table===table
    @test first_context.guard!==second_context.guard
    @test first_context.work===nothing && second_context.work===nothing
    @test WorkVS.ClosureWorkContext().rank_table===nothing
    geometry=Q.geometry(4);work=Q.V5Work(5,4);guard=ReentrantLock()
    @test WorkVS.ClosureWorkContext(geometry,work).rank_table===nothing
    @test WorkVS.ClosureWorkContext(geometry,work,guard).guard===guard
end
const WORK_PACKET_ROOT="00000001000204070004080d10161c1b00081019202a343f404c5855707e6c63002080a1e8ca6c4f5276daffaa8c260195bd052c5d77c9e287ab1f325f71c3ec00801697ed6fff7cb93da72244c25ed9e36be56c2ea42ca71a961499c749cd42a8083e9fad0f3f9c43e7dd7856f0cc6bde7658f1fb5179d275d9fb5640eeca650050e0b10d5fe9ba3b6fd3862670ca9d520aa2fb7f258bd02975d18c144ae8b7b9c9d9a85c2e384bd0a4b8cd2553493e7e060e77bbc1cfb4572b2f5282fcfe812bfbdd0ccb1939eaa97d5782598fa3749a427ca55a80b8635884b66b885662bd3aca4cbd32c040b3ea1e9461f204887f1ee6788136cc54af8e72e01db648dc23"

@testset "Complete-coset encoding preserves canonical TOML and generic fallbacks" begin
    proof=Dict{String,Any}("V5_forms"=>[134658561,34016355,17372590,10987437,4393092],
        "candidate_spaces"=>0,"capped"=>false,"completion_spaces"=>0,
        "coset_order"=>"increasing nonzero quotient integer with exact bent count","coset_representative"=>29,
        "du_reject"=>1,"first_x"=>1,"heuristic_pruning"=>false,"linear_system_candidates"=>0,"next_x"=>2,"total_x"=>15227)
    variants=Any[proof]
    for (key,value) in (("capped",true),("first_x",0),("linear_system_candidates",typemax(Int)),
        ("coset_representative",typemin(Int)),("V5_forms",[0,1,3,7,typemax(Int)]),
        ("future_field","new \"quoted\" evidence\nwith a second line"),("linear_system_candidates",Int32(17)),
        ("linear_system_candidates",0.25),("linear_system_candidates",true),("capped",0),
        ("heuristic_pruning",true),("V5_forms",Int32[1,2,3,4,5]),("V5_forms",[1,2,3,4]),
        ("coset_order","changed \"order\"\nwith a second line"))
        variant=deepcopy(proof);variant[key]=value;push!(variants,variant)
    end
    missing=deepcopy(proof);delete!(missing,"coset_representative");push!(variants,missing)
    push!(variants,WorkVS.JSON3.read(WorkVS.JSON3.write(proof),Dict{String,Any}))
    for variant in variants
        text=WorkVS._closure_coset_evidence_text(variant)
        @test text==WorkVS._closure_text(variant)
        @test TOML.parse(text)==variant
    end
end

@testset "Transported APN kernels preserve real serial evidence and private scratch" begin
    mktempdir() do directory
        F=SBox{8}(hex2bytes(WORK_PACKET_ROOT))
        run=closure_fixture(directory;F);s=WorkVS._closure_open(run)
        try
            prepare=only(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='prepare_v5'"))
            packet=WorkVS._closure_work_packet(s,prepare)
            @test packet["schema"]=="vbfsearch-closure-work-v1"
            wire=WorkVS.JSON3.read(WorkVS.JSON3.write(packet),Dict{String,Any})
            @test WorkVS._closure_packet_digest(wire)==packet["packet_sha256"]
            before=WorkVS._closure_rows(s.db,"SELECT * FROM jobs ORDER BY id")
            result=WorkVS._closure_compute(wire;seconds=60)
            @test result["work"]["proof"]["five_spaces"]==2
            @test WorkVS._closure_rows(s.db,"SELECT * FROM jobs ORDER BY id")==before
            @test WorkVS._closure_apply!(s,prepare,result)==0
            @test_throws ErrorException WorkVS._closure_apply!(s,prepare,result)
            jobs=WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='v5' ORDER BY id")
            packets=[WorkVS._closure_work_packet(s,j) for j in jobs]
            sequential_context=WorkVS.ClosureWorkContext()
            serial=[WorkVS._closure_compute(p;context=sequential_context,seconds=60) for p in packets]
            contexts=[WorkVS.ClosureWorkContext() for _ in packets]
            parallel=Vector{Any}(undef,length(packets))
            if Threads.nthreads()>1
                Threads.@threads :static for i in eachindex(packets)
                    parallel[i]=WorkVS._closure_compute(packets[i];context=contexts[i],seconds=60)
                end
                @test length(unique(r["worker"]["thread_id"] for r in parallel))==2
            else
                for i in eachindex(packets)
                    parallel[i]=WorkVS._closure_compute(packets[i];context=contexts[i],seconds=60)
                end
            end
            @test contexts[1].work !== contexts[2].work
            @test contexts[1].geometry !== contexts[2].geometry
            @test [r["work"] for r in serial]==[r["work"] for r in parallel]
            @test serial[1]["work"]["proof"]["coset_representative"]==29
            @test serial[1]["work"]["proof"]["du_reject"]==1
            @test serial[2]["work"]["proof"]["coset_representative"]==658
            @test [r["work"]["proof"]["next_x"] for r in parallel]==[2,2]
            for (job,result) in zip(jobs,parallel)
                # Replaying a serialized result exercises the coordinator path
                # for a result that crosses a process boundary.
                wire_result=WorkVS.JSON3.read(WorkVS.JSON3.write(result),Dict{String,Any})
                @test WorkVS._closure_apply!(s,job,wire_result)==result["work"]["evaluations"]
                @test_throws ErrorException WorkVS._closure_apply!(s,job,wire_result)
            end
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM chunks")==2
            @test !closure_snapshot(run)["closure_complete"]
            broken=deepcopy(packet);broken["target_b6"]=54
            @test_throws ErrorException WorkVS._closure_compute(broken)
            context=WorkVS.ClosureWorkContext()
            lock(context.guard)
            try
                task=Threads.@spawn WorkVS._closure_compute(packet;context)
                @test_throws TaskFailedException fetch(task)
            finally
                unlock(context.guard)
            end
        finally
            WorkVS._closure_close(s)
        end
    end
end

@testset "Switching direction batches preserve all serial paths and safe resume cursors" begin
    function switching_fixture(directory;F=gold_apn(8),directions=1)
        p=WorkVS.properties(F.lut)
        rootfile=joinpath(directory,"switching-root.tsv");write(rootfile,p["lut_hex"]*"\n")
        digest=WorkVS.DiscoveryEvidence.filehash(rootfile)
        identity=Dict{String,Any}("schema"=>WorkVS.CLOSURE_SCHEMA,"campaign"=>rootfile,"campaign_sha256"=>digest,
            "roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,"inputs"=>Dict(rootfile=>digest),
            "implementation"=>WorkVS.implementation_fingerprint(),"julia"=>string(VERSION),
            "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"switching_directions"=>directions))
        rows=[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="switching-fixture:1")]
        run=joinpath(directory,"switching-run");WorkVS._closure_initialize(run,identity,rows)
        run
    end
    switching_job(s)=only(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='switching'"))
    mktempdir() do directory
        batchdir=joinpath(directory,"batch");serialdir=joinpath(directory,"serial")
        mkpath(batchdir);mkpath(serialdir)
        batchrun=switching_fixture(batchdir;directions=8)
        serialrun=switching_fixture(serialdir)
        batchstore=WorkVS._closure_open(batchrun);serialstore=WorkVS._closure_open(serialrun)
        try
            batchjob=switching_job(batchstore);packet=WorkVS._closure_work_packet(batchstore,batchjob)
            @test packet["switching_directions"]==8
            serialpacket=WorkVS._closure_work_packet(serialstore,switching_job(serialstore))
            @test serialpacket["switching_directions"]==1
            calls=Ref(0)
            warm=WorkVS._closure_compute(serialpacket;seconds=60,evaluations=256,
                stop_requested=()->(calls[]+=1;false))
            elapsed_batch=@elapsed batch=WorkVS._closure_compute(packet;seconds=60,evaluations=256)
            @test count(e->e["event"]=="direction_complete",batch["work"]["events"])==8
            @test batch["work"]["evaluations"]==8
            @test all(e->e["properties"]["apn"],filter(e->e["event"]=="candidate_complete",batch["work"]["events"]))

            # A forged multi-direction payload cannot bypass the frozen legacy
            # one-direction scope, and its earlier writes roll back together.
            overscope=deepcopy(warm);overscope["work"]=deepcopy(batch["work"])
            @test_throws ErrorException WorkVS._closure_apply!(serialstore,switching_job(serialstore),overscope)
            @test WorkVS._closure_count(serialstore.db,"SELECT COUNT(*) n FROM kernels")==0
            @test WorkVS._closure_count(serialstore.db,"SELECT COUNT(*) n FROM evaluations")==0
            @test WorkVS._closure_count(serialstore.db,"SELECT COUNT(*) n FROM paths")==0

            # Calibrate a cooperative stop immediately after the first complete
            # direction. This retains that complete prefix and no partial work.
            interrupted_calls=Ref(0)
            interrupted=WorkVS._closure_compute(packet;seconds=60,evaluations=256,
                stop_requested=()->(interrupted_calls[]+=1;interrupted_calls[]>calls[]))
            @test interrupted["work"]["events"]==warm["work"]["events"]
            @test interrupted["work"]["proof"]["next_direction"]==2
            @test !interrupted["work"]["done"]

            # Corruption late in a batch must leave every earlier direction,
            # evaluation and path uncommitted.
            corrupt=deepcopy(batch)
            last(filter(e->e["event"]=="candidate_complete",corrupt["work"]["events"]))["properties"]["lut_sha256"]=repeat("0",64)
            @test_throws ErrorException WorkVS._closure_apply!(batchstore,batchjob,corrupt)
            @test WorkVS._closure_count(batchstore.db,"SELECT COUNT(*) n FROM kernels")==0
            @test WorkVS._closure_count(batchstore.db,"SELECT COUNT(*) n FROM paths")==0
            @test WorkVS._closure_apply!(batchstore,batchjob,WorkVS.JSON3.read(WorkVS.JSON3.write(batch),Dict{String,Any}))==8
            @test_throws ErrorException WorkVS._closure_apply!(batchstore,batchjob,batch)

            serial_events=Dict{String,Any}[];elapsed_serial=0.0
            for _ in 1:8
                job=switching_job(serialstore)
                elapsed_serial+=@elapsed one=WorkVS._closure_compute(WorkVS._closure_work_packet(serialstore,job);seconds=60,evaluations=256)
                append!(serial_events,one["work"]["events"])
                WorkVS._closure_apply!(serialstore,job,one)
            end
            @test serial_events==batch["work"]["events"]
            for (table,order) in (("kernels","direction"),("evaluations","direction,combination"),("paths","id"),("candidates","id"))
                @test isequal(WorkVS._closure_rows(batchstore.db,"SELECT * FROM $table ORDER BY $order"),
                    WorkVS._closure_rows(serialstore.db,"SELECT * FROM $table ORDER BY $order"))
            end
            @test switching_job(batchstore)["direction"]==switching_job(serialstore)["direction"]==9
            @test switching_job(batchstore)["combination"]==switching_job(serialstore)["combination"]=="1"
            WorkVS._closure_validate_cursors(batchstore);WorkVS._closure_validate_cursors(serialstore)
            @info "Switching batch parity" directions=8 candidates=8 serial_packets=8 batch_packets=1 elapsed_serial elapsed_batch
            for value in (0,-1,256)
                invalid=deepcopy(packet);invalid["switching_directions"]=value
                invalid["packet_sha256"]=WorkVS._closure_packet_digest(invalid)
                @test_throws ErrorException WorkVS._closure_compute(invalid)
            end
        finally
            WorkVS._closure_close(batchstore);WorkVS._closure_close(serialstore)
        end
    end
    mktempdir() do directory
        # Gold x^9 has a two-dimensional quotient kernel in direction 1, so a
        # one-candidate budget pauses within its three-candidate direction.
        run=switching_fixture(directory;F=gold_apn(8,3),directions=8)
        s=WorkVS._closure_open(run)
        try
            job=switching_job(s);packet=WorkVS._closure_work_packet(s,job)
            initial=WorkVS._closure_compute(packet;seconds=60,evaluations=1)
            @test only(e for e in initial["work"]["events"] if e["event"]=="kernel")["dimension"]==2
            @test initial["work"]["evaluations"]==1
            @test initial["work"]["proof"]["next_direction"]==1
            @test initial["work"]["proof"]["next_combination"]=="2"
            @test WorkVS._closure_apply!(s,job,initial)==1
            WorkVS._closure_validate_cursors(s)
            WorkVS._closure_close(s);s=WorkVS._closure_open(run)
            current=switching_job(s)
            @test current["direction"]==1 && current["combination"]=="2"
            noop=WorkVS._closure_compute(WorkVS._closure_work_packet(s,current);seconds=60,
                stop_requested=()->true)
            @test noop["work"]["noop"]
            @test WorkVS._closure_apply!(s,current,noop)==0
            second=WorkVS._closure_compute(WorkVS._closure_work_packet(s,switching_job(s));seconds=60,evaluations=256)
            @test WorkVS._closure_apply!(s,switching_job(s),second)==second["work"]["evaluations"]
            @test_throws ErrorException WorkVS._closure_apply!(s,current,initial)
            WorkVS._closure_validate_cursors(s)
            evaluations=WorkVS._closure_rows(s.db,"SELECT combination FROM evaluations WHERE direction=1 ORDER BY CAST(combination AS INTEGER)")
            @test [r["combination"] for r in evaluations]==["1","2","3"]
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM kernels WHERE direction<=8")==8
            @test switching_job(s)["direction"]==9 && switching_job(s)["combination"]=="1"
            # Per-path witnesses must identify the same persisted kernel even
            # when the kernel is reconstructed after a mid-direction stop.
            @test all(row->begin
                witness=TOML.parse(row["witness"])
                witness["kernel_direction"]==parse(Int,first(split(row["cursor"],':'))) && witness["kernel_job"]==job["id"]
            end,WorkVS._closure_rows(s.db,"SELECT cursor,witness FROM paths"))
        finally
            WorkVS._closure_close(s)
        end
    end
    mktempdir() do directory
        # The real published root has only trivial switching kernels. One
        # packet must certify every direction, including the final transition,
        # rather than rebuilding all 255 constraint systems 255 times.
        run=switching_fixture(directory;F=SBox{8}(hex2bytes(WORK_PACKET_ROOT)),directions=255)
        s=WorkVS._closure_open(run)
        try
            job=switching_job(s)
            result=WorkVS._closure_compute(WorkVS._closure_work_packet(s,job);seconds=60,evaluations=256)
            @test result["work"]["done"]
            @test result["work"]["proof"]["next_direction"]==256
            @test result["work"]["evaluations"]==0
            @test count(e->e["event"]=="kernel",result["work"]["events"])==255
            @test count(e->e["event"]=="direction_complete",result["work"]["events"])==255
            @test WorkVS._closure_apply!(s,job,result)==0
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM kernels WHERE dimension=0")==255
            @test switching_job(s)["status"]=="done"
            WorkVS._closure_validate_cursors(s)
            @test !closure_snapshot(run)["closure_complete"]
        finally
            WorkVS._closure_close(s)
        end
    end
end

@testset "Pure switching packets buffer bounded candidate events and resume exactly" begin
    mktempdir() do directory
        run=closure_fixture(directory);s=WorkVS._closure_open(run)
        try
            job=only(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='switching'"))
            packet=WorkVS._closure_work_packet(s,job)
            a=WorkVS._closure_compute(packet;seconds=60,evaluations=1)
            b=fetch(Threads.@spawn WorkVS._closure_compute(packet;seconds=60,evaluations=1))
            @test a["work"]==b["work"]
            events=a["work"]["events"]
            @test count(e->e["event"]=="direction_complete",events)<=1
            @test count(e->e["event"]=="candidate_complete",events)==1
            @test all(e->e["direction"]==1,events)
            @test only(e for e in events if e["event"]=="kernel")["dimension"]==1
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM kernels")==0
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM evaluations")==0
            corrupt=deepcopy(a)
            only(e for e in corrupt["work"]["events"] if e["event"]=="candidate_complete")["properties"]["lut_sha256"]=repeat("0",64)
            @test_throws ErrorException WorkVS._closure_apply!(s,job,corrupt)
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM kernels")==0
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM evaluations")==0
            n=WorkVS._closure_apply!(s,job,a)
            @test n==count(e->e["event"]=="candidate_complete",events)
            current=only(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE id=?",(job["id"],)))
            @test current["direction"]==a["work"]["proof"]["next_direction"]
            @test current["combination"]==a["work"]["proof"]["next_combination"]
            resumed=WorkVS._closure_compute(WorkVS._closure_work_packet(s,current);seconds=60,evaluations=1)
            @test WorkVS._closure_apply!(s,current,resumed)>=0
            WorkVS._closure_validate_cursors(s)
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM evaluations")==a["work"]["evaluations"]+resumed["work"]["evaluations"]
            @test !closure_snapshot(run)["closure_complete"]
        finally
            WorkVS._closure_close(s)
        end
    end
end

@testset "Per-coset observers match serial searches and retain duplicate APN paths" begin
    QE=VBF.QuadraticExtensions;G=QE.geometry(4);beta=QE.bent_fourier(G)
    F=gold_apn(4);a=anf(F)
    coeffs=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:3 for j in i+1:3]
    forms=QE.coord_forms(coeffs,4);V=QE.rref(forms[1:1])[1]
    duplicate_paths=false
    for need in 0:2
        events=Any[]
        full=QE.v5_extensions(G,V,need,QE.V5Work(5,4);beta,max_kernel=5,
            coset_observer=event->push!(events,event))
        @test length(events)==full.nX_used==full.nX
        @test sum(length(event.Ss) for event in events;init=0)>=length(full.Ss)
        @test all(S->differential_uniformity(last(QE.function_of(G,S)))==2,full.Ss)
        singles=Any[];scratch=QE.V5Work(5,4)
        for i in 1:full.nX
            single=QE.v5_extensions(G,V,need,scratch;beta,max_kernel=5,max_x=1,start_x=i,
                coset_observer=event->push!(singles,event))
            @test last(singles).Ss==single.Ss
        end
        @test events==singles
        @test sum(event.ncand for event in events;init=0)==full.ncand
        @test sum(event.du_reject for event in events;init=0)==full.du_reject
        @test sum(event.nT for event in events;init=0)==full.nT
        duplicate_paths|=sum(length(event.Ss) for event in events;init=0)>length(full.Ss)
        # Stopping at a boundary returns exactly the complete reported prefix.
        prefix=Any[]
        stopped=QE.v5_extensions(G,V,need,QE.V5Work(5,4);beta,max_kernel=5,
            should_stop=()->length(prefix)>=2,coset_observer=event->push!(prefix,event))
        @test prefix==events[1:min(2,length(events))]
        @test stopped.next_x==1+length(prefix)
    end
    @test duplicate_paths
end

@testset "Batched transport preserves each real coset proof and commits all cursors" begin
    mktempdir() do directory
        F=SBox{8}(hex2bytes(WORK_PACKET_ROOT));p=WorkVS.properties(F.lut)
        rootfile=joinpath(directory,"batch-root.tsv");write(rootfile,p["lut_hex"]*"\n")
        digest=WorkVS.DiscoveryEvidence.filehash(rootfile)
        identity=Dict{String,Any}("schema"=>WorkVS.CLOSURE_SCHEMA,"campaign"=>rootfile,"campaign_sha256"=>digest,
            "roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,"inputs"=>Dict(rootfile=>digest),
            "implementation"=>WorkVS.implementation_fingerprint(),"julia"=>string(VERSION),
            "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>8))
        rows=[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="batch-fixture:1")]
        run=joinpath(directory,"batch-run");WorkVS._closure_initialize(run,identity,rows)
        s=WorkVS._closure_open(run)
        try
            prepare=only(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='prepare_v5'"))
            WorkVS._closure_apply!(s,prepare,WorkVS._closure_compute(WorkVS._closure_work_packet(s,prepare);seconds=60))
            job=first(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='v5' ORDER BY id"))
            packet=WorkVS._closure_work_packet(s,job)
            @test packet["extension_cosets"]==8
            context=WorkVS.ClosureWorkContext()
            batch=WorkVS._closure_compute(packet;context,seconds=60)
            @test length(batch["work"]["chunks"])==batch["work"]["processed_cosets"]==8
            @test all(c->WorkVS._closure_coset_evidence_text(c["proof"])==WorkVS._closure_text(c["proof"]),batch["work"]["chunks"])
            serial=Any[]
            for i in 1:8
                one=deepcopy(packet);one["extension_cosets"]=1;one["direction"]=i
                one["packet_sha256"]=WorkVS._closure_packet_digest(one)
                push!(serial,only(WorkVS._closure_compute(one;context,seconds=60)["work"]["chunks"]))
            end
            @test batch["work"]["chunks"]==serial
            # The native worker envelope is read-only; transport remains the
            # legacy mutable dictionary schema, including corruption checks.
            corrupt=WorkVS.JSON3.read(WorkVS.JSON3.write(batch),Dict{String,Any})
            corrupt["work"]["chunks"][2]["proof"]["first_x"]=99
            @test_throws ErrorException WorkVS._closure_apply!(s,job,corrupt)
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM chunks")==0
            @test WorkVS._closure_apply!(s,job,batch)==batch["work"]["evaluations"]
            stored=WorkVS._closure_rows(s.db,"SELECT * FROM chunks ORDER BY first_x")
            @test length(stored)==1
            stored=reduce(vcat,WorkVS._closure_unpack_chunks.(stored))
            @test [r["first_x"] for r in stored]==collect(1:8)
            @test [r["next_x"] for r in stored]==collect(2:9)
            @test [r["evidence"] for r in stored]==[WorkVS._closure_text(c["proof"]) for c in serial]
            @test [TOML.parse(r["evidence"]) for r in stored]==[c["proof"] for c in serial]
            @test only(WorkVS._closure_rows(s.db,"SELECT direction FROM jobs WHERE id=?",(job["id"],)))["direction"]==9
            WorkVS._closure_validate_cursors(s)
            @test !closure_snapshot(run)["closure_complete"]
            # A known parent-containing coset is outside this short prefix, but
            # gives a positive APN-completion control without an unbounded run.
            control=deepcopy(packet);control["direction"]=3672;control["extension_cosets"]=1
            control["packet_sha256"]=WorkVS._closure_packet_digest(control)
            positive=WorkVS._closure_compute(control;context,seconds=60)
            @test length(positive["work"]["records"])==1
            record=only(positive["work"]["records"])
            @test record["witness"]["eligible_coset_index"]==3672
            @test record["witness"]["coset_representative"]==2487989
            @test record["properties"]["apn"] && record["properties"]["quadratic"]
            @test VBF.sigma_hash(SBox{8}(hex2bytes(record["properties"]["lut_hex"])))==p["sigma_hash"]
        finally
            WorkVS._closure_close(s)
        end
    end
end

function ledger_fixture(directory)
    mkpath(directory)
    F=SBox{8}(hex2bytes(WORK_PACKET_ROOT));p=WorkVS.properties(F.lut)
    rootfile=joinpath(directory,"ledger-root.tsv");write(rootfile,p["lut_hex"]*"\n")
    digest=WorkVS.DiscoveryEvidence.filehash(rootfile)
    identity=Dict{String,Any}("schema"=>WorkVS.CLOSURE_SCHEMA,"campaign"=>rootfile,"campaign_sha256"=>digest,
        "roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,"inputs"=>Dict(rootfile=>digest),
        "implementation"=>WorkVS.implementation_fingerprint(),"julia"=>string(VERSION),
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>8))
    rows=[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="ledger-fixture:1")]
    run=joinpath(directory,"run");WorkVS._closure_initialize(run,identity,rows)
    s=WorkVS._closure_open(run)
    prepare=only(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='prepare_v5'"))
    WorkVS._closure_apply!(s,prepare,WorkVS._closure_compute(WorkVS._closure_work_packet(s,prepare);seconds=60))
    s,first(WorkVS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='v5' ORDER BY id"))
end

@testset "Workers encode the coverage ledger exactly as the coordinator would" begin
    mktempdir() do directory
        s,job=ledger_fixture(joinpath(directory,"in-process"))
        t,wire_job=ledger_fixture(joinpath(directory,"wire"))
        try
            batch=WorkVS._closure_compute(WorkVS._closure_work_packet(s,job);seconds=60)
            ledger=batch["work"]["ledger"]
            @test ledger isa NamedTuple && ledger.job_id==job["id"] && ledger.evidence isa Vector{UInt8}
            @test ledger==WorkVS._closure_ledger_row(job["id"],batch["work"]["chunks"])
            # A wrong envelope is refused before any coverage row is written.
            for field in (:job_id,:first_x,:next_x,:total_x,:capped)
                bad=deepcopy(batch);bad["work"]["ledger"]=merge(ledger,NamedTuple{(field,)}((getfield(ledger,field)+1,)))
                @test_throws ErrorException WorkVS._closure_apply!(s,job,bad)
            end
            @test WorkVS._closure_count(s.db,"SELECT COUNT(*) n FROM chunks")==0
            @test WorkVS._closure_apply!(s,job,batch)==batch["work"]["evaluations"]
            # After JSON transport the row is a Dict, so the coordinator encodes it.
            wire_batch=WorkVS._closure_compute(WorkVS._closure_work_packet(t,wire_job);seconds=60)
            wire=WorkVS.JSON3.read(WorkVS.JSON3.write(wire_batch),Dict{String,Any})
            @test !(wire["work"]["ledger"] isa NamedTuple)
            @test WorkVS._closure_apply!(t,wire_job,wire)==batch["work"]["evaluations"]
            stored(store)=[Tuple(r) for r in WorkVS.DBInterface.execute(store.db,"SELECT * FROM chunks ORDER BY job_id,first_x")]
            @test stored(s)==stored(t)
            @test only(stored(s))[6]==ledger.evidence
        finally
            WorkVS._closure_close(s);WorkVS._closure_close(t)
        end
    end
end

