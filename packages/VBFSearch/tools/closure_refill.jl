"""Run a bounded FIFO of reserved jobs, refilling each free compute slot.

`reserve(limit, excluded_keys)` runs only initially and after an ordered apply.
It must return deterministic descriptors not already reserved. `prepare` and
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
    stop_requested=()->false,on_tick=()->nothing)
    concurrency>0 || throw(ArgumentError("invalid concurrency"))
    max_pending>=concurrency || throw(ArgumentError("reservation horizon must cover every slot"))
    events=Channel{Any}(max_pending)
    cancelled=Threads.Atomic{Bool}(false)
    worker_stop()=cancelled[] || stop_requested()
    reserved=Dict{Int,Any}();reserved_keys=Set{Any}()
    ready=Int[];ready_head=1;free_slots=collect(1:concurrency)
    active=Dict{Int,Task}();completed=Dict{Int,Any}()
    next_ticket=1;next_apply=1;dispatched=0;applied=0
    peak_active=0;peak_pending=0;peak_completed=0;failure=nothing
    function reserve_more!()
        worker_stop() && return
        room=max_pending-length(reserved)
        room==0 && return
        descriptors=reserve(room,copy(reserved_keys))
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
            prepared=prepare(reserved[ticket],ticket,slot)
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
            apply(event.prepared,event.value,event.compute_seconds,
                (;ticket=event.ticket,slot=event.slot,
                    ready_wait_seconds=(time_ns()-event.finished_ns)*1e-9))
            delete!(completed,next_apply)
            item=pop!(reserved,next_apply);delete!(reserved_keys,key(item))
            next_apply+=1;applied+=1
            reserve_more!();dispatch!()
        end
    end
    try
        reserve_more!();dispatch!()
        while !isempty(active)
            event=take!(events)
            wait(pop!(active,event.ticket))
            push!(free_slots,event.slot);sort!(free_slots)
            completed[event.ticket]=event
            peak_completed=max(peak_completed,length(completed))
            if event.problem!==nothing
                failure===nothing && (failure=event.problem)
                cancelled[]=true
            end
            # Refill before serial application, using the already reserved FIFO.
            dispatch!();apply_prefix!()
            failure===nothing && on_tick()
        end
        apply_prefix!()
        failure===nothing || throw(failure.exception)
        (;state=worker_stop() ? :stopped : :drained,dispatched,applied,
            peak_active,peak_pending,peak_completed,
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
