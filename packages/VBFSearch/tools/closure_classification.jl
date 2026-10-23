"""Batch empty-target classification snapshots without skipping result validation.

Reservation reads a bounded candidate set once. A snapshot with no admitted
signature match still uses the ordinary native worker and application checks.
Admissions earlier in the same batch can invalidate later snapshots; the
existing application path then requeues them for normal EA comparison.
"""

"""Group consecutive cheap jobs, retaining job order and independent EA work."""
function classification_items(s,jobs,batch_size)
    batch_size>1 || return Any[(job=j,equivalence=true) for j in jobs]
    isempty(jobs) && return Any[]
    ids=String[FP._closure_equivalence_candidate_id(j["payload"]) for j in jobs]
    rows=FP._closure_rows(s,"""SELECT c.id,c.lut_hex,c.sigma FROM candidates c
        WHERE c.id IN (SELECT value FROM json_each(?))
        AND NOT EXISTS(SELECT 1 FROM parents p WHERE p.sigma=c.sigma)""",(String(FP.JSON3.write(ids)),))
    cheap=Dict(String(row["id"])=>row for row in rows)
    items=Any[];pending=Any[];candidates=Any[]
    function flush!()
        isempty(pending) && return
        push!(items,(job=first(pending),jobs=copy(pending),candidates=copy(candidates),equivalence=true,cheap=true))
        empty!(pending);empty!(candidates)
    end
    for (job,id) in zip(jobs,ids)
        candidate=get(cheap,id,nothing)
        if candidate===nothing
            flush!();push!(items,(job=job,equivalence=true))
        else
            push!(pending,job);push!(candidates,candidate)
            length(pending)>=batch_size && flush!()
        end
    end
    flush!();items
end

"""Bind a reservation-time empty snapshot to the unchanged worker protocol."""
function classification_packet(job,candidate)
    FP._ClosureEquivalencePacket(Dict{String,Any}(
        "schema"=>FP.CLOSURE_EQUIVALENCE_SCHEMA,"job_id"=>Int(job["id"]),
        "job_key"=>job["job_key"],"candidate_id"=>candidate["id"],
        "lut_hex"=>candidate["lut_hex"],"sigma"=>candidate["sigma"],
        "targets"=>Dict{String,Any}[]))
end

"""Keep every constituent job inside the refill pool's existing memory bound."""
function classification_keys(item)
    if get(item,:cheap,false) && length(item.jobs)>1
        return Int[Int(j["id"]) for j in item.jobs]
    end
    (Int(item.job["id"]),)
end
classification_lane(item)=get(item,:cheap,false) ? :classification : :default

"""Validate a cheap batch on one scratch owner and retain a successful prefix."""
function compute_classification_batch(sources,context,solver_session;make_packet=identity)
    results=Any[];failure=nothing
    for source in sources
        started=time_ns()
        try
            packet=make_packet(source)
            isempty(packet["targets"]) || error("cheap classification requires an empty target snapshot")
            value=FP._closure_equivalence_compute(packet;seconds=0.0,nodes=0,context,solver_session)
            finished_ns=time_ns()
            push!(results,(;packet,value,seconds=(finished_ns-started)*1e-9,finished_ns))
        catch error
            failure=(exception=error,backtrace=catch_backtrace());break
        end
    end
    (;results,failure)
end
