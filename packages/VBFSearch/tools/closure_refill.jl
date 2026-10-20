"""Run a bounded FIFO of reserved jobs, refilling each free compute slot.

`reserve(limit, excluded_keys)` runs only initially and after an ordered apply.
It must return deterministic descriptors not already reserved. `coordinator_step`
may group writes; worker waits and reporting stay outside it. `prepare` and
`apply` run on the coordinator; `compute` alone runs on worker tasks. A slot is
an exclusive scratch owner, independent of the Julia thread executing its task.

At most `max_pending` tickets exist, including queued, computing and completed
results. Completed results apply in reservation order. A fast slot immediately
takes the next reserved ticket while an earlier slow ticket is still running.
An extreme head straggler eventually causes bounded backpressure. Reservation
depends on the committed prefix, not the order in which workers complete.

STOP stops reservation/dispatch and cooperatively interrupts workers. Every
already dispatched successful result still applies in order. On failure, the
successful prefix is applied, all workers are joined, and the original error
is rethrown; the caller owns durable recovery of unapplied jobs.
"""
function run_refill_pool!(reserve,prepare,compute,apply;
    concurrency::Int,max_pending::Int=2concurrency,key=identity,
    stop_requested=()->false,on_tick=()->nothing,on_wait=()->nothing,
    on_state=_->nothing,measure_result_bytes=false,poll_seconds=0.1,coordinator_step=f->f())
    concurrency>0 || throw(ArgumentError("invalid concurrency"))
    max_pending>=concurrency || throw(ArgumentError("reservation horizon must cover every slot"))
    isfinite(poll_seconds) && poll_seconds>0 || throw(ArgumentError("invalid worker poll interval"))
    events=Channel{Any}(max_pending)
    cancelled=Threads.Atomic{Bool}(false)
    worker_stop()=cancelled[] || stop_requested()
    reserved=Dict{Int,Any}();reserved_keys=Set{Any}()
    ready=Int[];ready_head=1;free_slots=collect(1:concurrency)
    active=Dict{Int,Task}();completed=Dict{Int,Any}()
    next_ticket=1;next_apply=1;dispatched=0;applied=0
    peak_active=0;peak_pending=0;peak_completed=0;failure=nothing
    reserve_seconds=0.0;prepare_seconds=0.0;apply_seconds=0.0;event_wait_seconds=0.0
    completed_bytes=0;peak_completed_bytes=0
    function publish_state!()
        on_state((;active=length(active),reserved=length(reserved),completed=length(completed),
            peak_active,peak_pending,peak_completed,completed_bytes,peak_completed_bytes,
            result_bytes_measured=measure_result_bytes,reserve_seconds,prepare_seconds,apply_seconds,event_wait_seconds))
    end
    function reserve_more!()
        worker_stop() && return
        room=max_pending-length(reserved)
        room==0 && return
        t=time_ns();descriptors=reserve(room,copy(reserved_keys));reserve_seconds+=(time_ns()-t)*1e-9
        length(descriptors)<=room || error("reservation exceeds bounded horizon")
        for item in descriptors
            id=key(item)
            id in reserved_keys && error("job reserved twice")
            reserved[next_ticket]=item;push!(reserved_keys,id);push!(ready,next_ticket)
            next_ticket+=1
        end
        peak_pending=max(peak_pending,length(reserved))
    end
    function dispatch!()
        while !worker_stop() && !isempty(free_slots) && ready_head<=length(ready)
            ticket=ready[ready_head];ready_head+=1
            slot=popfirst!(free_slots)
            t=time_ns();prepared=prepare(reserved[ticket],ticket,slot);prepare_seconds+=(time_ns()-t)*1e-9
            active[ticket]=Threads.@spawn begin
                started=time_ns();value=nothing;problem=nothing
                try
                    value=compute(prepared,slot,worker_stop)
                catch error
                    problem=(exception=error,backtrace=catch_backtrace())
                end
                finished=time_ns()
                put!(events,(;ticket,slot,prepared,value,problem,
                    compute_seconds=(finished-started)*1e-9,finished_ns=finished))
            end
            dispatched+=1;peak_active=max(peak_active,length(active))
        end
        # Keep the reservation queue bounded in memory during an indefinite run.
        if ready_head>max_pending
            deleteat!(ready,1:ready_head-1);ready_head=1
        end
    end
    function apply_prefix!()
        while haskey(completed,next_apply)
            event=completed[next_apply]
            event.problem===nothing || return
            t=time_ns();apply(event.prepared,event.value,event.compute_seconds,
                (;ticket=event.ticket,slot=event.slot,
                    ready_wait_seconds=(time_ns()-event.finished_ns)*1e-9))
            apply_seconds+=(time_ns()-t)*1e-9
            completed_bytes-=event.result_bytes
            delete!(completed,next_apply)
            item=pop!(reserved,next_apply);delete!(reserved_keys,key(item))
            next_apply+=1;applied+=1
            reserve_more!();dispatch!()
        end
    end
    function receive!(event)
        wait(pop!(active,event.ticket))
        push!(free_slots,event.slot);sort!(free_slots)
        bytes=measure_result_bytes ? Base.summarysize((event.prepared,event.value)) : 0
        completed[event.ticket]=merge(event,(result_bytes=bytes,))
        completed_bytes+=bytes;peak_completed_bytes=max(peak_completed_bytes,completed_bytes)
        peak_completed=max(peak_completed,length(completed))
        if event.problem!==nothing
            failure===nothing && (failure=event.problem)
            cancelled[]=true
        end
    end
    try
        coordinator_step() do
            reserve_more!();dispatch!()
        end
        publish_state!()
        while !isempty(active)
            t=time_ns()
            while !isready(events)
                maintenance_started=time_ns();on_wait();t+=time_ns()-maintenance_started
                timedwait(()->isready(events),poll_seconds;pollint=min(0.001,poll_seconds))
            end
            event_wait_seconds+=(time_ns()-t)*1e-9
            event=take!(events)
            coordinator_step() do
                receive!(event)
                # Drain already completed work without waiting inside a transaction.
                while isready(events)
                    receive!(take!(events))
                end
                dispatch!();apply_prefix!()
            end
            publish_state!()
            failure===nothing && on_tick()
        end
        coordinator_step(apply_prefix!)
        failure===nothing || throw(failure.exception)
        (;state=worker_stop() ? :stopped : :drained,dispatched,applied,
            peak_active,peak_pending,peak_completed,
            peak_completed_bytes,result_bytes_measured=measure_result_bytes,
            reserve_seconds,prepare_seconds,apply_seconds,event_wait_seconds,
            reserved_unstarted=length(reserved),reservation_horizon=max_pending)
    catch error
        # Preserve the original worker failure if cleanup of its successful
        # prefix or a progress callback also encounters an error.
        failure===nothing ? rethrow() : throw(failure.exception)
    finally
        cancelled[]=true
        # Event capacity covers all outstanding tickets, so a terminating worker
        # cannot block forever in put! while the coordinator handles an error.
        for task in values(active)
            try
                wait(task)
            catch
                # Preserve the primary compute/apply/report error.
            end
        end
    end
end
