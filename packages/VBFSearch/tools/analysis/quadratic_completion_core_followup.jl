using VBF,JSON3,Random,Dates,SHA
include("quadratic_completion_core_pilot.jl")
const CF=QuadraticCompletionCorePilot
const K=CF.K
const Q=VBF.QuadraticExtensions

"Bounded additional support minimization and lower-rank obstruction sampling."
function main(directory)
    pilot=JSON3.read(read(joinpath(directory,"pilot.json"),String));G=Q.geometry(8)
    inputs=sort([r for r in pilot.records if r.domain!==nothing&&r.domain.status=="unsat"];by=r->r.domain.nodes)[1:4]
    cores=Any[]
    for record in inputs
        p=K.S.problem(G,record.U)
        result=K.minimize(p;max_seconds=8,max_nodes=100000,query_seconds=0.05)
        indices=K.C.O.flat_indices(G,p.R)[result.indices]
        graph=K.C.intersection_graph(G,indices)
        coloring=K.C.coloring_obstruction(graph;max_nodes=10000,max_seconds=0.02)
        entry=(;parent_id=record.parent_id,coset_index=record.coset_index,U=p.R,
            source_flat_count=length(p.flats),core=result,original_flats=G.flats[indices],
            graph_status=coloring.status,core_features=CF.triangle_invariants(result.flats))
        push!(cores,entry)
        println(JSON3.write((;parent_id=record.parent_id,coset_index=record.coset_index,
            flats=length(result.flats),rank=result.rank,irreducible=result.irreducible,
            graph_status=coloring.status,seconds=result.seconds)))
        flush(stdout)
    end
    original=JSON3.read(read(joinpath(directory,"core.json"),String))
    p=K.S.problem(G,original.U);rng=Xoshiro(225422);cuts=Any[];lower_rank_cores=Any[]
    for i in 1:64
        t=rand(rng,UInt32(1):UInt32((1<<p.D)-1))
        flats=[c for c in p.flats if !Q.par(c&t)]
        restricted=(;r=p.r,D=p.D,flats)
        result=K.D.solve(restricted;max_nodes=10000,timeout_seconds=0.02,capture_proof=true)
        push!(cuts,(;functional=t,flat_count=length(flats),rank=VBF.rank_f2(flats;nbits=p.D),
            status=result.status,nodes=result.nodes,seconds=result.seconds))
        if result.status=="unsat"
            K.D.replay_unsat(restricted,result.proof) || error("lower-rank proof failed")
            push!(lower_rank_cores,(;functional=t,flats,proof=result.proof))
        end
    end
    result=(;created_utc=string(now(UTC)),source_sha256=bytes2hex(open(sha256,@__FILE__)),
        cores,cuts,lower_rank_cores,
        caveat="64 uniform hyperplane cuts only; SAT/unknown cuts give no global absence theorem")
    write(joinpath(directory,"followup.json"),JSON3.write(result))
    println(JSON3.write((;cuts=length(cuts),statuses=Dict(s=>count(t->t.status==s,cuts) for s in ("sat","unsat","unknown")),
        lower_rank_certificates=length(lower_rank_cores))))
end
abspath(PROGRAM_FILE)==(@__FILE__) && main(ARGS[1])
