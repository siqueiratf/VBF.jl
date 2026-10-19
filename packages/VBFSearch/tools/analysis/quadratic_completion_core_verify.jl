using VBF,JSON3,SHA,Dates
include("quadratic_completion_core_pilot.jl")
const CA=QuadraticCompletionCorePilot
const K=CA.K
const Q=VBF.QuadraticExtensions

"Audit frozen parents, actual target profiles and every retained algebraic proof."
function verify(directory,samplepath)
    source=read(samplepath);parentsdoc=JSON3.read(String(copy(source)))
    receipt=JSON3.read(read(joinpath(dirname(samplepath),"provenance-validation.json"),String))
    receipt.complete && receipt.bindings["parents.json"]==bytes2hex(sha256(source)) || error("provenance receipt")
    parents=Dict(Int(p.parent_id)=>p for p in parentsdoc.parents)
    pilot=JSON3.read(read(joinpath(directory,"pilot.json"),String))
    pilot.sample_sha256==bytes2hex(sha256(source)) || error("pilot source binding")
    G=Q.geometry(8);parentchecked=Set{Int}();proofs=0;lifts=0;graphstatuses=Dict{String,Int}()
    for rec in pilot.records
        parent=parents[Int(rec.parent_id)];V=UInt32.(parent.maximizing_v5_forms[Int(rec.v5_index)])
        if !(Int(rec.parent_id) in parentchecked)
            components=K.C.O.V5ParentProvenance.parent_component_space(hex2bytes(String(parent.lut_hex)))
            K.C.O.V5ParentProvenance.contained_five_space(components,V) || error("V5 outside parent")
            push!(parentchecked,Int(rec.parent_id))
        end
        U=UInt32.(rec.U);basis=VBF.linear_basis(U;nbits=28)
        length(basis)==6 && all(q->VBF.is_in_span(q,basis;nbits=28),V) || error("U6 containment")
        count(q->Q.form_rank(G,q)==8,Q.comp_forms(U))==52 || error("U6 target profile")
        p=K.S.problem(G,U)
        if rec.quadratic_lift.status=="unsat"
            A=CA.lifted_rows(p.flats,p.D);w=Int.(rec.quadratic_lift.witness)
            isodd(length(w)) && all(j->iseven(count(identity,A[w,j])),axes(A,2)) || error("lift witness")
            rec.prior_status in ("existing_du_obstruction","singular_three_space") || error("new lift rejection unexpectedly present")
            lifts+=1
        end
        if rec.domain!==nothing && rec.domain.status=="unsat"
            proof=JSON3.read(read(`gzip -dc $(rec.domain.proofpath)`,String))
            UInt32.(proof.U)==U && UInt32.(proof.flats)==p.flats || error("proof input mismatch")
            K.D.replay_unsat(p,proof.proof) || error("serialized domain proof")
            indices=K.C.O.flat_indices(G,U)
            graph=K.C.intersection_graph(G,indices)
            coloring=K.C.coloring_obstruction(graph;max_nodes=10000,max_seconds=1)
            graphstatuses[coloring.status]=get(graphstatuses,coloring.status,0)+1
            proofs+=1
        end
    end
    original=JSON3.read(read(joinpath(directory,"core.json"),String))
    corep=(;r=2,D=22,flats=UInt32.(original.core.flats))
    K.D.replay_unsat(corep,original.core.proof) || error("original minimal core proof")
    deletion_models=Any[]
    for i in eachindex(corep.flats)
        rows=corep.flats[setdiff(eachindex(corep.flats),[i])]
        answer=K.D.solve((;r=2,D=22,flats=rows);max_nodes=100000,timeout_seconds=0.1)
        answer.status=="sat" && all(c->any(v->Q.par(c&v),answer.vectors),rows) || error("core deletion witness")
        push!(deletion_models,(;deleted_index=i,vectors=answer.vectors))
    end
    write(joinpath(directory,"original-core-deletion-models.json"),JSON3.write(deletion_models))
    result=(;created_utc=string(now(UTC)),frozen_parent_count=length(parentchecked),
        verified_u6_profiles=length(pilot.records),serialized_domain_proofs=proofs,
        replayed_lift_witnesses=lifts,domain_proof_graph_statuses=graphstatuses,
        original_core_independently_verified_deletions=length(deletion_models),
        source_sha256=bytes2hex(open(sha256,@__FILE__)))
    write(joinpath(directory,"verification.json"),JSON3.write(result));println(JSON3.write(result))
end
abspath(PROGRAM_FILE)==(@__FILE__) && verify(ARGS[1],ARGS[2])
