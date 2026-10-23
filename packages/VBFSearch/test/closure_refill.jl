module ClosureRefillTests
using Test
include(joinpath(@__DIR__,"..","tools","closure_refill.jl"))

function fifo_reserver(items)
    queue=collect(items)
    (limit,excluded)->begin
        @assert all(!(x in excluded) for x in queue)
        n=min(limit,length(queue));selected=queue[1:n];deleteat!(queue,1:n);selected
    end
end

@testset "Grouped reservations retain every job key within the horizon" begin
    remaining=collect(1:40);applied=Int[]
    reserve=(limit,excluded)->begin
        @test all(id->!(id in excluded),remaining)
        n=min(limit,length(remaining));selected=remaining[1:n];deleteat!(remaining,1:n)
        [selected[i:min(i+3,n)] for i in 1:4:n]
    end
    result=run_refill_pool!(reserve,(ids,ticket,slot)->ids,(ids,slot,stop)->ids,
        (ids,value,seconds,meta)->append!(applied,value);
        concurrency=2,max_pending=8,item_keys=identity)
    @test applied==collect(1:40)
    @test result.dispatched_jobs==result.applied_jobs==40
    @test result.dispatched==result.applied==10
    @test result.peak_pending==8 && result.peak_completed_jobs<=8
    @test result.reserved_jobs_unstarted==0
    @test_throws ErrorException run_refill_pool!((n,excluded)->[[1,1]],identity,identity,identity;
        concurrency=1,max_pending=2,item_keys=identity)
    @test_throws ErrorException run_refill_pool!((n,excluded)->[[1,2,3]],identity,identity,identity;
        concurrency=1,max_pending=2,item_keys=identity)
end

@testset "Grouped reservation membership survives descriptor mutation" begin
    groups=[[1,2],[3,4]];applied=Int[]
    reserve=(limit,excluded)->isempty(groups) ? Vector{Int}[] : [popfirst!(groups)]
    prepare=(ids,ticket,slot)->begin
        original=copy(ids);empty!(ids);original
    end
    result=run_refill_pool!(reserve,prepare,(ids,slot,stop)->ids,
        (ids,value,seconds,meta)->append!(applied,value);
        concurrency=1,max_pending=2,item_keys=identity)
    @test applied==collect(1:4)
    @test result.applied_jobs==4 && result.peak_pending==2
    @test result.reserved_jobs_unstarted==0
end

@testset "A reserved classification lane drains STOP across undispatched gaps" begin
    stop=Threads.Atomic{Bool}(false);started=Channel{Int}(2);release=Channel{Nothing}(2)
    dispatched=Int[];applied=Int[]
    prepare=(item,ticket,slot)->begin push!(dispatched,item);item end
    compute=(item,slot,cancel)->begin put!(started,item);take!(release);item end
    coordinator=@async run_refill_pool!(fifo_reserver(1:4),prepare,compute,
        (item,value,seconds,meta)->push!(applied,value);
        concurrency=2,max_pending=4,lane=item->item<=2 ? :classification : :default,
        lane_limits=Dict(:classification=>1,:default=>1),stop_requested=()->stop[])
    @test sort!([take!(started),take!(started)])==[1,3]
    stop[]=true;put!(release,nothing);put!(release,nothing)
    result=fetch(coordinator)
    @test dispatched==applied==[1,3]
    @test result.state==:stopped && result.applied_jobs==2
    @test result.reserved_jobs_unstarted==2
    @test_throws ArgumentError run_refill_pool!(nothing,nothing,nothing,nothing;
        concurrency=1,lane_limits=Dict(:classification=>0))
end

@testset "A fast slot refills before the first slow ticket completes" begin
    slow_gate=Channel{Nothing}(1);third_started=Channel{Nothing}(1)
    dispatched=Int[];applied=Int[];first_finished=Threads.Atomic{Bool}(false)
    guards=[ReentrantLock() for _ in 1:2]
    prepare=(item,ticket,slot)->begin push!(dispatched,item);(;item,ticket,slot) end
    compute=(work,slot,stop)->begin
        trylock(guards[slot]) || error("scratch slot shared concurrently")
        try
            if work.item==1
                take!(slow_gate);first_finished[]=true
            elseif work.item==3
                put!(third_started,nothing)
            end
            work.item
        finally
            unlock(guards[slot])
        end
    end
    apply=(work,value,seconds,meta)->begin
        @test work.ticket==meta.ticket && work.slot==meta.slot && value==work.item
        push!(applied,value)
    end
    coordinator=@async run_refill_pool!(fifo_reserver(1:8),prepare,compute,apply;
        concurrency=2,max_pending=4)
    @test timedwait(()->isready(third_started),10.0)==:ok
    take!(third_started)
    @test !first_finished[]
    @test isempty(applied)
    @test dispatched[1:3]==[1,2,3]
    put!(slow_gate,nothing)
    result=fetch(coordinator)
    @test dispatched==applied==collect(1:8)
    @test result.state==:drained && result.dispatched==result.applied==8
    @test result.peak_active==2 && result.peak_pending==4 && result.peak_completed<=4
    @test all(!islocked(g) for g in guards)
end

@testset "STOP drains dispatched results without starting reserved jobs" begin
    stop=Threads.Atomic{Bool}(false);started=Channel{Int}(2);release=Channel{Nothing}(2)
    dispatched=Int[];applied=Int[]
    prepare=(item,ticket,slot)->begin push!(dispatched,item);item end
    compute=(item,slot,cancel)->begin put!(started,item);take!(release);item end
    apply=(item,value,seconds,meta)->push!(applied,value)
    coordinator=@async run_refill_pool!(fifo_reserver(1:8),prepare,compute,apply;
        concurrency=2,max_pending=4,stop_requested=()->stop[])
    @test sort!([take!(started),take!(started)])==[1,2]
    stop[]=true;put!(release,nothing);put!(release,nothing)
    result=fetch(coordinator)
    @test result.state==:stopped
    @test dispatched==applied==[1,2]
    @test result.dispatched==result.applied==2 && result.reserved_unstarted==2
end

@testset "Compute and apply failures join every worker and preserve the prefix" begin
    started=Channel{Nothing}(1);applied=Int[];finished=Threads.Atomic{Bool}(false)
    prepare=(item,ticket,slot)->item
    compute=(item,slot,stop)->begin
        if item==1
            put!(started,nothing)
            while !stop();yield();end
            finished[]=true
            return item
        end
        take!(started);error("synthetic compute failure")
    end
    apply=(item,value,seconds,meta)->push!(applied,value)
    failure=try
        run_refill_pool!(fifo_reserver(1:4),prepare,compute,apply;concurrency=2,
            on_tick=()->error("cosmetic progress failure must not mask compute failure"))
        nothing
    catch error
        error
    end
    @test failure isa ErrorException
    @test occursin("synthetic compute failure",sprint(showerror,failure))
    @test applied==[1] && finished[]

    second_started=Channel{Nothing}(1);second_finished=Threads.Atomic{Bool}(false)
    compute2=(item,slot,stop)->begin
        if item==1
            take!(second_started);return item
        end
        put!(second_started,nothing)
        while !stop();yield();end
        second_finished[]=true;item
    end
    fail_apply=(item,value,seconds,meta)->error("synthetic apply failure")
    failure2=try
        run_refill_pool!(fifo_reserver(1:4),prepare,compute2,fail_apply;concurrency=2)
        nothing
    catch error
        error
    end
    @test failure2 isa ErrorException
    @test occursin("synthetic apply failure",sprint(showerror,failure2))
    @test second_finished[]

    prepare_worker_finished=Threads.Atomic{Bool}(false)
    prepare3=(item,ticket,slot)->begin
        item==2 && error("synthetic prepare failure")
        item
    end
    compute3=(item,slot,stop)->begin
        while !stop();yield();end
        prepare_worker_finished[]=true;item
    end
    failure3=try
        run_refill_pool!(fifo_reserver(1:4),prepare3,compute3,apply;concurrency=2)
        nothing
    catch error
        error
    end
    @test failure3 isa ErrorException
    @test occursin("synthetic prepare failure",sprint(showerror,failure3))
    @test prepare_worker_finished[]
end

@testset "Reservation bounds and duplicate protection" begin
    @test_throws ArgumentError run_refill_pool!(nothing,nothing,nothing,nothing;concurrency=0)
    @test_throws ArgumentError run_refill_pool!(nothing,nothing,nothing,nothing;concurrency=2,max_pending=1)
    reserve=(limit,excluded)->[1,1]
    @test_throws ErrorException run_refill_pool!(reserve,identity,identity,identity;concurrency=2)
end

@testset "Waiting observes stop requests, drains and measures buffered results" begin
    stopped=Threads.Atomic{Bool}(false);ticks=Ref(0);applied=Int[]
    compute=(item,slot,stop)->begin while !stop();yield();end;item end
    poll=()->begin ticks[]+=1;stopped[]=true end
    result=run_refill_pool!(fifo_reserver(1:5),(item,ticket,slot)->item,compute,
        (item,value,seconds,meta)->push!(applied,value);concurrency=1,
        stop_requested=()->stopped[],on_wait=poll,measure_result_bytes=true)
    @test ticks[]>0 && result.state==:stopped && applied==[1]
    @test result.peak_completed_bytes>0 && result.result_bytes_measured
    @test result.reserved_unstarted==1 && result.applied==1
    @test result.event_wait_seconds>=0 && result.prepare_seconds>=0
end
@testset "Bounded application steps expose real occupancy and horizon stalls" begin
    slow=Channel{Nothing}(1);saturated=Channel{Nothing}(1)
    applied=Int[];tick_prefixes=Int[];notified=Ref(false)
    compute=(item,slot,stop)->begin item==1 && take!(slow);item end
    observe=state->begin
        if state.active==1 && state.completed==3 && !notified[]
            notified[]=true;put!(saturated,nothing)
        end
    end
    coordinator=@async run_refill_pool!(fifo_reserver(1:12),(item,ticket,slot)->item,compute,
        (item,value,seconds,meta)->push!(applied,value);concurrency=2,max_pending=4,
        max_apply_per_step=1,on_state=observe,on_tick=()->push!(tick_prefixes,length(applied)))
    @test timedwait(()->isready(saturated),10.0)==:ok
    put!(slow,nothing)
    result=fetch(coordinator)
    @test applied==collect(1:12)
    @test maximum(diff(vcat(0,tick_prefixes)))<=1
    @test result.horizon_backpressure_seconds>0
    @test result.underfilled_seconds>=result.horizon_backpressure_seconds
    @test 0<result.active_slot_seconds<=2result.pool_wall_seconds
    @test 0<result.slot_occupancy<=1
    @test result.compute_slot_seconds>0 && result.completed_ticket_seconds>0
    @test_throws ArgumentError run_refill_pool!(nothing,nothing,nothing,nothing;concurrency=1,max_apply_per_step=0)
end

@testset "Head waiting excludes coordinator maintenance and application work" begin
    gate=Channel{Nothing}(1);head_blocked=Ref(false);wait_ticks=Ref(0)
    observe=state->(head_blocked[]=state.active==1 && state.completed==3)
    maintain=()->begin
        if head_blocked[]
            wait_ticks[]+=1
            wait_ticks[]==2 && put!(gate,nothing)
        end
    end
    result=run_refill_pool!(fifo_reserver(1:4),(item,ticket,slot)->item,
        (item,slot,stop)->begin item==1 && take!(gate);item end,
        (item,value,seconds,meta)->nothing;concurrency=2,max_pending=4,
        on_state=observe,on_wait=maintain,poll_seconds=.005)
    @test wait_ticks[]>=2
    @test 0<result.horizon_wait_seconds<=result.ordered_head_wait_seconds<=result.event_wait_seconds
    @test result.horizon_wait_seconds<=result.horizon_backpressure_seconds
    @test result.idle_slot_wait_seconds>=result.horizon_wait_seconds
    @test result.applied==4
end

@testset "Reservation batching keeps short and generated frontiers live" begin
    prepare=(item,ticket,slot)->item
    compute=(item,slot,stop)->item
    applied=Int[]
    result=run_refill_pool!(fifo_reserver(1:2),prepare,compute,
        (item,value,seconds,meta)->push!(applied,value);concurrency=2,max_pending=8,reservation_refill_batch=8)
    @test applied==[1,2] && result.dispatched==result.applied==2
    @test result.reservation_calls==2 && result.reservation_refill_batch==8
    @test result.peak_pending==2 && result.reserved_unstarted==0
    queue=[1];empty!(applied)
    reserve=(limit,excluded)->begin
        n=min(limit,length(queue));items=queue[1:n];deleteat!(queue,1:n);items
    end
    apply=(item,value,seconds,meta)->begin
        push!(applied,value)
        item<7 && push!(queue,item+1)
    end
    generated=run_refill_pool!(reserve,prepare,compute,apply;concurrency=2,max_pending=8,reservation_refill_batch=8)
    @test applied==collect(1:7) && isempty(queue)
    @test generated.reservation_calls==8 && generated.peak_pending==1
    empty=run_refill_pool!((limit,excluded)->Int[],prepare,compute,apply;concurrency=2,max_pending=8,reservation_refill_batch=8)
    @test empty.applied==empty.dispatched==0 && empty.reservation_calls==1
    @test_throws ArgumentError run_refill_pool!(nothing,nothing,nothing,nothing;concurrency=1,max_pending=8,reservation_refill_batch=0)
    @test_throws ArgumentError run_refill_pool!(nothing,nothing,nothing,nothing;concurrency=1,max_pending=8,reservation_refill_batch=9)
end

@testset "Coordinator timing separates callbacks, transactions and finished workers" begin
    snapshots=Any[];applied=Int[]
    step=work->begin
        yield()
        work()
        sleep(.001)
    end
    result=run_refill_pool!(fifo_reserver(1:8),(item,ticket,slot)->item,
        (item,slot,stop)->begin yield();item end,
        (item,value,seconds,meta)->push!(applied,value);
        concurrency=2,max_pending=4,max_apply_per_step=1,coordinator_step=step,
        on_tick=()->yield(),on_state=x->push!(snapshots,x))
    @test applied==collect(1:8)
    @test result.coordinator_step_seconds>=result.transaction_control_seconds>0
    @test result.tick_seconds>0 && result.wait_maintenance_seconds>=0
    @test result.event_collection_seconds>0 && result.peak_uncollected>=1
    @test result.finished_compute_seconds≈result.compute_slot_seconds
    @test all(s->0<=s.workers_computing<=2 && 0<=s.completed_uncollected<=2,snapshots)
    @test last(snapshots).workers_computing==last(snapshots).workers_scheduled==last(snapshots).completed_uncollected==0
end

function generated_reservation_trace(batch;slow_head=false,explicit=true)
    frontier=Set(1:12);applied=Int[];trace=Any[]
    gate=Channel{Nothing}(1);finished=Channel{Int}(24)
    reserve=(limit,excluded)->begin
        selected=sort!(Int[x for x in frontier if !(x in excluded) && !(x in applied)])
        resize!(selected,min(limit,length(selected)))
        push!(trace,(prefix=copy(applied),room=limit,excluded=sort!(Int[x for x in excluded]),items=copy(selected)))
        selected
    end
    compute=(item,slot,stop)->begin
        if item==(slow_head ? 1 : 3)
            take!(gate)
        elseif item==(slow_head ? 3 : 1)
            put!(finished,item);put!(gate,nothing);return item
        end
        put!(finished,item);item
    end
    apply=(item,value,seconds,meta)->begin
        @test value==item && meta.ticket==length(applied)+1
        push!(applied,item)
        item>0 && push!(frontier,-item)
    end
    kwargs=explicit ? (;reservation_refill_batch=batch) : NamedTuple()
    result=run_refill_pool!(reserve,(item,ticket,slot)->item,compute,apply;
        concurrency=4,max_pending=8,kwargs...)
    completion=[take!(finished) for _ in 1:24]
    (;result,trace,applied,completion)
end

@testset "Reservation batches follow the applied prefix independently of worker completion" begin
    ordinary=generated_reservation_trace(1;explicit=false)
    explicit=generated_reservation_trace(1)
    @test ordinary.applied==explicit.applied && ordinary.trace==explicit.trace
    @test ordinary.result.reservation_calls==explicit.result.reservation_calls==25
    fast_head=generated_reservation_trace(4)
    slow_head=generated_reservation_trace(4;slow_head=true)
    @test findfirst(==(1),fast_head.completion)<findfirst(==(3),fast_head.completion)
    @test findfirst(==(3),slow_head.completion)<findfirst(==(1),slow_head.completion)
    @test fast_head.trace==slow_head.trace && fast_head.applied==slow_head.applied
    @test sort(fast_head.applied)==sort(ordinary.applied)==vcat(collect(-12:-1),collect(1:12))
    @test fast_head.applied!=ordinary.applied # Newly generated priority changes can affect admission order.
    @test fast_head.result.reservation_calls==length(fast_head.trace)<ordinary.result.reservation_calls
    @test all(event->event.room>=4,fast_head.trace)
    @test all(event->event.room+length(event.excluded)==8,fast_head.trace)
    @test fast_head.result.peak_pending<=8 && slow_head.result.peak_pending<=8
end

@testset "Batched reservations preserve STOP draining and the successful failure prefix" begin
    for batch in (1,4,8)
        stop=Threads.Atomic{Bool}(false);started=Channel{Int}(2);release=Channel{Nothing}(2)
        applied=Int[]
        compute=(item,slot,cancel)->begin put!(started,item);take!(release);item end
        coordinator=@async run_refill_pool!(fifo_reserver(1:12),(item,ticket,slot)->item,compute,
            (item,value,seconds,meta)->push!(applied,value);concurrency=2,max_pending=8,
            reservation_refill_batch=batch,stop_requested=()->stop[])
        @test sort!([take!(started),take!(started)])==[1,2]
        stop[]=true;put!(release,nothing);put!(release,nothing)
        result=fetch(coordinator)
        @test applied==[1,2] && result.state==:stopped
        @test result.reservation_calls==1 && result.reserved_unstarted==6 && result.peak_pending<=8

        head_started=Channel{Nothing}(1);head_finished=Threads.Atomic{Bool}(false);empty!(applied)
        fail_compute=(item,slot,cancel)->begin
            if item==1
                put!(head_started,nothing)
                while !cancel();yield();end
                head_finished[]=true;return item
            end
            take!(head_started);error("batched worker failure")
        end
        failure=try
            run_refill_pool!(fifo_reserver(1:12),(item,ticket,slot)->item,fail_compute,
                (item,value,seconds,meta)->push!(applied,value);concurrency=2,max_pending=8,reservation_refill_batch=batch)
            nothing
        catch error
            error
        end
        @test failure isa ErrorException && occursin("batched worker failure",sprint(showerror,failure))
        @test applied==[1] && head_finished[]
    end
end

end
