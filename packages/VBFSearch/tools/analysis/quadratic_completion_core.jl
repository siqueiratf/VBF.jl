"""Extract small original-flat supports from exact algebraic APN obstructions.

Only a newly certified UNSAT subset is accepted. SAT and budget-unknown trials
both retain the removed flats. The final subset has its own exact tree checked
directly against original flat coordinates. Greedy irreducibility is claimed
only when every single deletion is positively solved SAT; unknown is explicit.
"""
module QuadraticCompletionCore
using VBF,JSON3,SHA,Dates
include("quadratic_completion_smt.jl")
include("quadratic_completion_domains.jl")
include("flat_intersection_coloring.jl")
const S=QuadraticCompletionSMT
const D=QuadraticCompletionDomains
const C=FlatIntersectionColoring
const Q=VBF.QuadraticExtensions

"Bounded deterministic deletion minimization in the original residual-flat set."
function minimize(p;max_seconds=20.0,max_nodes=100000,query_seconds=0.05)
    start=time_ns();indices=collect(eachindex(p.flats));trials=Any[]
    function trial(chosen,label)
        elapsed=(time_ns()-start)*1e-9
        elapsed>=max_seconds && return nothing
        sub=(;r=p.r,D=p.D,flats=p.flats[chosen])
        result=D.solve(sub;max_nodes,timeout_seconds=min(query_seconds,max_seconds-elapsed))
        push!(trials,(;label,flat_count=length(chosen),status=result.status,nodes=result.nodes,seconds=result.seconds))
        result.status=="unsat"
    end
    initial=trial(indices,"initial")
    initial===true || error("initial problem not certified UNSAT within bound")
    chunks=2
    while length(indices)>1 && (time_ns()-start)*1e-9<max_seconds
        changed=false
        for block in 1:chunks
            first=fld((block-1)*length(indices),chunks)+1
            last=fld(block*length(indices),chunks)
            chosen=vcat(indices[1:first-1],indices[last+1:end])
            accepted=trial(chosen,"chunk-$chunks-$block")
            accepted===nothing && break
            if accepted
                indices=chosen;chunks=max(2,chunks-1);changed=true;break
            end
        end
        changed && continue
        chunks>=length(indices) && break
        chunks=min(length(indices),2chunks)
    end
    proof_result=D.solve((;r=p.r,D=p.D,flats=p.flats[indices]);
        max_nodes,timeout_seconds=max(1.0,query_seconds),capture_proof=true)
    proof_result.status=="unsat" || error("final proof reconstruction did not finish")
    D.replay_unsat((;r=p.r,D=p.D,flats=p.flats[indices]),proof_result.proof) || error("core proof failed")
    deletions=Any[]
    for i in eachindex(indices)
        (time_ns()-start)*1e-9>=max_seconds && break
        chosen=indices[setdiff(eachindex(indices),[i])]
        answer=D.solve((;r=p.r,D=p.D,flats=p.flats[chosen]);max_nodes,timeout_seconds=query_seconds)
        if answer.status=="sat"
            all(c->any(v->Q.par(c&v),answer.vectors),p.flats[chosen]) || error("deletion SAT witness failed")
        end
        push!(deletions,(;deleted_index=indices[i],status=answer.status,nodes=answer.nodes,
            vectors=answer.vectors))
    end
    (;indices,flats=p.flats[indices],rank=VBF.rank_f2(p.flats[indices];nbits=p.D),
        proof=proof_result.proof,proof_nodes=proof_result.nodes,trials,deletions,
        irreducible=length(deletions)==length(indices)&&all(d->d.status=="sat",deletions),
        seconds=(time_ns()-start)*1e-9)
end

"Minimize the retained non-Fano, graph-three-colorable real U6 obstruction."
function main(directory)
    mkpath(directory);G=Q.geometry(8)
    U=UInt32[136265402,67900833,43432498,26361621,3242677,78]
    p=S.problem(G,U);result=minimize(p)
    flatindices=C.O.flat_indices(G,U)
    actual_indices=flatindices[result.indices]
    graph=C.intersection_graph(G,actual_indices)
    coloring=C.coloring_obstruction(graph;max_nodes=100000,max_seconds=1)
    output=(;created_utc=string(now(UTC)),U,r=p.r,D=p.D,
        source_flat_count=length(p.flats),core=result,geometry_indices=actual_indices,
        original_flats=G.flats[actual_indices],graph,graph_status=coloring.status,
        existing_obstruction=C.O.inspect(G,U,flatindices),
        source_sha256=bytes2hex(open(sha256,@__FILE__)),
        solver_sha256=bytes2hex(open(sha256,joinpath(@__DIR__,"quadratic_completion_domains.jl"))))
    write(joinpath(directory,"core.json"),JSON3.write(output))
    println(JSON3.write((;source_flat_count=length(p.flats),flat_count=length(result.flats),
        rank=result.rank,proof_nodes=result.proof_nodes,irreducible=result.irreducible,
        graph_status=coloring.status,seconds=result.seconds,
        trial_statuses=Dict(s=>count(t->t.status==s,result.trials) for s in ("sat","unsat","unknown")))))
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && QuadraticCompletionCore.main(ARGS[1])
