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
end
