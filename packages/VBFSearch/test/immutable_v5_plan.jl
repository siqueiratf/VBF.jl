"""Exact Fourier-plan parity, publication ownership and disjoint-consumer checks."""
module ImmutableV5PlanTests
using Test,VBF,SHA
const Q=VBF.QuadraticExtensions

"""Retain original callback records to compare every completion and counter."""
function observed(G,V,need,work;beta,kwargs...)
    events=Any[]
    result=Q.v5_extensions(G,V,need,work;beta,kwargs...,coset_observer=e->push!(events,e))
    (;result,events)
end

"""Hash owned plan arrays before/after consumers and builder reuse."""
function plan_hash(plan)
    ctx=SHA.SHA2_256_CTX()
    for field in (:basis,:beta,:eligible_cosets,:constraints,:constraint_flat_indices,:walsh,:flat_counts)
        SHA.update!(ctx,reinterpret(UInt8,getproperty(plan,field)))
    end
    bytes2hex(SHA.digest!(ctx))
end

@testset "Prepared V5 plans exactly match unplanned small domains" begin
    G=Q.geometry(4);beta=Q.bent_fourier(G)
    for V in (UInt32[1],UInt32[0x21],UInt32[0x3f]),need in (0,1,2,99)
        builder=Q.V5Work(5,4)
        plan=Q.prepare_v5_plan(G,V,need;beta,work=builder)
        original_hash=plan_hash(plan)
        @test plan.geometry===G && plan.beta==beta && plan.basis==first(Q.rref(V))
        @test Q.v5_plan_bytes(plan)>sizeof(plan.walsh)
        @test plan.walsh!==builder.g5
        fill!(builder.cnt,-1);fill!(builder.g5,-1);empty!(builder.flat_histogram)
        @test plan_hash(plan)==original_hash
        for du_filter in (false,true),mode in (:none,:bitsets,:triangles,:auto),cap in (0,8),
                limits in ((;),(;max_x=0),(;max_x=2),(;start_x=length(plan.eligible_cosets)+1))
            expected=observed(G,V,need,Q.V5Work(5,4);beta,du_filter,du7_filter=mode,max_kernel=cap,limits...)
            small=Q.V5Work(0,4)
            actual=observed(G,V,need,small;beta,du_filter,du7_filter=mode,max_kernel=cap,plan,limits...)
            @test actual==expected
            @test length(small.cnt)==length(small.g5)==1
        end
        selected=collect(1:2:length(plan.eligible_cosets))
        expected=observed(G,V,need,Q.V5Work(5,4);beta,selected_coset_indices=selected)
        actual=observed(G,V,need,Q.V5Work(0,4);beta,selected_coset_indices=selected,plan)
        @test actual==expected
        @test observed(G,V,need,Q.V5Work(0,4);beta,plan,should_skip=_->true)==
            observed(G,V,need,Q.V5Work(5,4);beta,should_skip=_->true)
        for active_plan in (nothing,plan)
            seen=Ref(0);events=Any[]
            stopped=Q.v5_extensions(G,V,need,Q.V5Work(active_plan===nothing ? 5 : 0,4);beta,plan=active_plan,
                should_stop=()->seen[]>=1,coset_observer=e->begin push!(events,e);seen[]+=1 end)
            if active_plan===nothing
                expected=(;result=stopped,events)
            else
                @test (;result=stopped,events)==expected
            end
        end
        @test plan_hash(plan)==original_hash
    end
end

@testset "Transferred Walsh capacity preserves ownership and exact mathematics" begin
    G=Q.geometry(4);V=UInt32[0x21];beta=Q.bent_fourier(G);need=1
    builder=Q.V5Work(0,4);buffer=fill(Int16(123),1<<(G.N-1))
    original_pointer=pointer(buffer)
    plan=Q.prepare_v5_plan(G,V,need;beta,work=builder,walsh_buffer=buffer)
    owned=Q.prepare_v5_plan(G,V,need;beta)
    @test plan.walsh===buffer && pointer(plan.walsh)==original_pointer
    @test plan_hash(plan)==plan_hash(owned)
    @test Q.v5_plan_bytes(plan)==Q.v5_plan_bytes(owned)
    @test owned.walsh!==buffer && plan.walsh!==builder.g5
    expected=observed(G,V,need,Q.V5Work(5,4);beta,max_kernel=8,du7_filter=:bitsets)
    snapshot=plan_hash(plan)
    pieces=Vector{Any}(undef,2)
    midpoint=length(plan.eligible_cosets)÷2
    @sync for index in 1:2
        Threads.@spawn begin
            first=index==1 ? 1 : midpoint+1
            count=index==1 ? midpoint : length(plan.eligible_cosets)-midpoint
            pieces[index]=observed(G,V,need,Q.V5Work(0,4);beta,plan,max_kernel=8,
                du7_filter=:bitsets,start_x=first,max_x=count)
        end
    end
    @test vcat(pieces[1].events,pieces[2].events)==expected.events
    @test union(pieces[1].result.Ss,pieces[2].result.Ss)==expected.result.Ss
    fill!(builder.cnt,-1);fill!(builder.g5,-1);empty!(builder.flat_histogram)
    @test plan_hash(plan)==snapshot

    # The previous consumers have joined and that plan's lifetime ends here.
    # A new plan may now take the same physical capacity; no stale plan is used.
    plan=nothing
    next_V=UInt32[1]
    recycled=Q.prepare_v5_plan(G,next_V,need;beta,work=builder,walsh_buffer=buffer)
    @test recycled.walsh===buffer && pointer(recycled.walsh)==original_pointer
    @test observed(G,next_V,need,Q.V5Work(0,4);beta,plan=recycled,max_kernel=8)==
        observed(G,next_V,need,Q.V5Work(5,4);beta,max_kernel=8)
    @test plan_hash(owned)==snapshot

    wrong=fill(Int16(41),length(buffer)-1);before=copy(wrong)
    @test_throws ArgumentError Q.prepare_v5_plan(G,V,need;beta,work=builder,walsh_buffer=wrong)
    @test wrong==before
    alias_builder=Q.V5Work(5,4);fill!(alias_builder.cnt,-9);fill!(alias_builder.g5,13)
    @test_throws ArgumentError Q.prepare_v5_plan(G,V,need;beta,work=alias_builder,walsh_buffer=alias_builder.g5)
    @test all(==(-9),alias_builder.cnt) && all(==(13),alias_builder.g5)
    @test_throws TypeError Q.prepare_v5_plan(G,V,need;beta,walsh_buffer=view(buffer,:))
end

@testset "Plan bindings reject stale domains and accept canonical equivalent bases" begin
    G=Q.geometry(4);V=UInt32[1,2];beta=Q.bent_fourier(G)
    plan=Q.prepare_v5_plan(G,V,1;beta)
    @test Q.v5_extensions(G,UInt32[3,2],1,Q.V5Work(0,4);beta,plan)==
        Q.v5_extensions(G,V,1,Q.V5Work(4,4);beta)
    @test_throws ArgumentError Q.v5_extensions(Q.geometry(4),V,1,Q.V5Work(0,4);beta,plan)
    @test_throws ArgumentError Q.v5_extensions(G,V,2,Q.V5Work(0,4);beta,plan)
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(0,4);beta=beta.*2,plan)
    @test_throws ArgumentError Q.v5_extensions(G,UInt32[1],1,Q.V5Work(0,4);beta,plan)
    table=Q.PolarRankTable(G)
    table_plan=Q.prepare_v5_plan(G,V,1;beta,rank_table=table)
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(0,4);beta,plan=table_plan)
    @test Q.v5_extensions(G,V,1,Q.V5Work(0,4);beta,rank_table=table,plan=table_plan)==
        Q.v5_extensions(G,V,1,Q.V5Work(4,4);beta,rank_table=table)
    @test Q.v5_plan_bytes(table_plan)==Q.v5_plan_bytes(plan)
    @test_throws ErrorException Q.v5_extensions(G,V,1,Q.V5Work(0,4);beta,plan,start_x=0)
    @test_throws ArgumentError Q.v5_extensions(G,V,1,Q.V5Work(0,4);beta,plan,selected_coset_indices=[1,1])
end

@testset "Output resource limits interrupt before completing a growing coset" begin
    G=Q.geometry(4);V=UInt32[0x21];beta=Q.bent_fourier(G);need=1
    plan=Q.prepare_v5_plan(G,V,need;beta)
    expected=observed(G,V,need,Q.V5Work(5,4);beta,max_kernel=8)
    outputs=sum(length(event.Ss) for event in expected.events)
    @test outputs>1
    for active_plan in (nothing,plan),limit in (0,1,outputs-1)
        events=Any[]
        problem=try
            Q.v5_extensions(G,V,need,Q.V5Work(active_plan===nothing ? 5 : 0,4);beta,
                plan=active_plan,max_kernel=8,max_output_spaces=limit,coset_observer=e->push!(events,e))
            nothing
        catch error
            error
        end
        @test problem isa Q.V5OutputLimit
        @test problem.limit==problem.output_spaces==limit
        @test all(e->e.index<problem.coset_index,events)
        @test events==expected.events[1:length(events)]
        @test occursin("incomplete",sprint(showerror,problem))
    end
    @test observed(G,V,need,Q.V5Work(0,4);beta,plan,max_kernel=8,max_output_spaces=outputs)==expected
    @test_throws ArgumentError Q.v5_extensions(G,V,need,Q.V5Work(0,4);beta,plan,max_output_spaces=-1)
    empty_plan=Q.prepare_v5_plan(G,V,99;beta)
    @test isempty(Q.v5_extensions(G,V,99,Q.V5Work(0,4);beta,plan=empty_plan,max_output_spaces=0).Ss)
end

@testset "Shared real n8 plan preserves all original coset proofs" begin
    G=Q.geometry(8);V=UInt32[142878652,72146349,47389132,22095572,3691981]
    beta=copy(Q.BETA8);need=22
    builder=Q.V5Work(23)
    plan=Q.prepare_v5_plan(G,V,need;beta,work=builder)
    @test length(plan.eligible_cosets)==14716
    @test 16*1024^2<Q.v5_plan_bytes(plan)<18*1024^2
    snapshot=plan_hash(plan)
    full=observed(G,V,need,builder;beta,max_kernel=23,du7_filter=:bitsets)
    prepared=observed(G,V,need,Q.V5Work(0);beta,max_kernel=23,du7_filter=:bitsets,plan)
    @test full==prepared
    midpoint=length(plan.eligible_cosets)÷2
    pieces=Vector{Any}(undef,2)
    @sync for index in 1:2
        Threads.@spawn begin
            first=index==1 ? 1 : midpoint+1
            count=index==1 ? midpoint : length(plan.eligible_cosets)-midpoint
            pieces[index]=observed(G,V,need,Q.V5Work(0);beta,max_kernel=23,du7_filter=:bitsets,plan,
                start_x=first,max_x=count)
        end
    end
    @test vcat(pieces[1].events,pieces[2].events)==full.events
    @test union(pieces[1].result.Ss,pieces[2].result.Ss)==full.result.Ss
    @test pieces[1].result.ncand+pieces[2].result.ncand==full.result.ncand
    @test pieces[1].result.nT+pieces[2].result.nT==full.result.nT
    @test plan_hash(plan)==snapshot
    fill!(builder.cnt,0);fill!(builder.g5,0);fill!(builder.flat_histogram,0)
    @test plan_hash(plan)==snapshot
end

@testset "Production packets retain byte-identical planned coverage and candidates" begin
    using VBFSearch
    FP=VBFSearch
    lut=hex2bytes("00000079003b96d40083a55feb53d819009efe19a005c814cfd294f084a2491600094b3be0d23d7679f3976472c30ac220b7957b60cc4396968286eb3d12bbed002d13470c1a89e6802e36e167f247ab10a3fd37bc34c7365f6f175e1813c6b404205c01e8f72640fd5a00defa669174348e925178f948b0023b0141a5a7304b00598aaa04661803409a6fccaf4e168e08cf7cc2ac504ecb87c3566bc8b78f890252c3eae68db1a33be85ff534dcc6572ae415a26e9bc74bdc91467273057f700175989509460630c136fd7322ee883d19f37eedb16040e8167fd4c45507012a077ad5d1efa9ab94be40c94ebd785ce03fdc138977afcd6c4929c0d9eab1f5d7")
    properties=FP.properties(lut);G=Q.geometry(8);V=UInt32[142878652,72146349,47389132,22095572,3691981]
    plan=Q.prepare_v5_plan(G,V,22;beta=Q.BETA8)
    packet=Dict{String,Any}("schema"=>FP.CLOSURE_WORK_SCHEMA,"job_id"=>1,"parent_id"=>1,
        "job_key"=>"plan-fixture:v5","kind"=>"v5","direction"=>308,"combination"=>"1",
        "payload"=>Dict("forms"=>Int.(V),"need"=>22,"b5"=>30),"target_b6"=>52,
        "max_kernel"=>23,"extension_cosets"=>1,"switching_directions"=>1,
        "parent"=>Dict("lut_sha256"=>properties["lut_sha256"],"lut_hex"=>properties["lut_hex"],"sigma"=>properties["sigma_hash"]))
    packet["packet_sha256"]=FP._closure_packet_digest(packet)
    ordinary=FP.ClosureWorkContext();ordinary.geometry=G
    prepared=FP.ClosureWorkContext(;v5_plan=plan);prepared.geometry=G
    expected=FP._closure_compute(packet;context=ordinary,seconds=Inf,evaluations=256)
    actual=FP._closure_compute(packet;context=prepared,seconds=Inf,evaluations=256)
    @test actual["work"]==expected["work"]
    @test actual["packet_sha256"]==expected["packet_sha256"]
    @test !isempty(actual["work"]["records"])
    @test actual["work"]["ledger"]==expected["work"]["ledger"]
    @test length(prepared.work.cnt)==length(prepared.work.g5)==1
    prepared.v5_plan=nothing
    reused=FP._closure_compute(packet;context=prepared,seconds=Inf,evaluations=256)
    @test reused["work"]==expected["work"]
    @test length(prepared.work.cnt)==1<<23
    legacy=FP.ClosureWorkContext(G,Q.V5Work(0),ReentrantLock(),nothing,FP.DiscoveryEvidence.PropertyCache())
    @test legacy.v5_plan===nothing && legacy.geometry===G
    @test legacy.record_limit==ordinary.record_limit==prepared.record_limit==typemax(Int)
    six_arguments=FP.ClosureWorkContext(G,Q.V5Work(0),ReentrantLock(),nothing,
        FP.DiscoveryEvidence.PropertyCache(),plan)
    @test six_arguments.v5_plan===plan && six_arguments.record_limit==typemax(Int)
    @test haskey(FP.implementation_fingerprint(),"packages/VBF/src/constructions/quadratic_v5_plan.jl")

    limited=FP.ClosureWorkContext(;v5_plan=plan,record_limit=0);limited.geometry=G
    for (first,count) in ((308,1),(1,308))
        request=deepcopy(packet);request["direction"]=first;request["extension_cosets"]=count
        request["packet_sha256"]=FP._closure_packet_digest(request)
        problem=try
            FP._closure_compute(request;context=limited,seconds=Inf,evaluations=256)
            nothing
        catch error
            error
        end
        @test problem isa FP._ClosureWorkCapacity
        @test problem.kind==:output_spaces && problem.limit==0
        @test problem.retained.packet["packet_sha256"]==request["packet_sha256"]==FP._closure_packet_digest(problem.retained.packet)
        @test problem.retained.coset==308 && problem.retained.output_spaces==0
        @test isempty(problem.retained.records)
        @test length(problem.retained.chunks)==308-first
        @test all(c->c["proof"]["first_x"]<308 && c["proof"]["next_x"]<=308 &&
            c["proof"]["candidate_spaces"]==0 && !c["proof"]["capped"],problem.retained.chunks)
        @test !islocked(limited.guard)
        if first==1
            prefix=deepcopy(request);prefix["extension_cosets"]=307
            prefix["packet_sha256"]=FP._closure_packet_digest(prefix)
            complete=FP._closure_compute(prefix;context=limited,seconds=Inf,evaluations=256)
            @test complete["work"]["chunks"]==problem.retained.chunks
            @test complete["work"]["proof"]["next_x"]==308
            @test complete["work"]["processed_cosets"]==307
            @test !complete["work"]["done"] && !islocked(limited.guard)
        end
    end
end
end
