using VBF,JSON3,SHA
include(joinpath(@__DIR__,"quadratic_completion_smt.jl"))
include(joinpath(@__DIR__,"quadratic_completion_domains.jl"))
const CVSMT=QuadraticCompletionSMT
const CVDomain=QuadraticCompletionDomains
const CVQ=VBF.QuadraticExtensions

"Replay retained positive models and serialized algebraic UNSAT trees only."
function verify(directory)
    geometry=Dict(4=>CVQ.geometry(4),8=>CVQ.geometry(8))
    external=JSON3.read(read(joinpath(directory,"pilot.json"),String))
    external_sat=0;external_unknown=0;external_unsat=0
    for rec in external.records
        p=CVSMT.problem(geometry[rec.n],rec.U_forms)
        input=joinpath(directory,rec.name,rec.solver,"query.smt2")
        bytes2hex(open(sha256,input))==rec.query_sha256 || error("query binding mismatch")
        if rec.status=="sat"
            rows=CVSMT.parse_model(read(joinpath(dirname(input),"stdout.txt"),String),p.r)
            replay=CVSMT.replay_model(p,rows;need=rec.native_target_need)
            replay.S==rec.positive_replay.S || error("external SAT replay mismatch")
            external_sat+=1
        elseif rec.status=="unsat"
            external_unsat+=1
        else
            external_unknown+=1
        end
    end
    domain=JSON3.read(read(joinpath(directory,"domains-pilot.json"),String))
    domain_sat=0;domain_unknown=0;domain_unsat=0
    for rec in domain.records
        p=CVSMT.problem(geometry[8],rec.U)
        if rec.result.status=="unsat"
            CVDomain.replay_unsat(p,rec.result.proof) || error("serialized UNSAT proof failed")
            domain_unsat+=1
        elseif rec.result.status=="sat"
            replay=CVSMT.replay_model(p,rec.result.vectors;need=rec.native_target_need)
            replay.S==rec.replay.S || error("domain SAT replay mismatch")
            any(m->m.S==replay.S,domain.native_models) || error("SAT absent from native target set")
            domain_sat+=1
        else
            rec.result.proof===nothing || error("unknown must not carry an UNSAT proof")
            domain_unknown+=1
        end
    end
    length(domain.native_models)==11 || error("native reference count changed")
    p=CVSMT.problem(geometry[8],first(domain.records).U)
    for model in domain.native_models
        CVSMT.replay_model(p,model.vectors;need=22).target_match || error("native target mismatch")
    end
    result=(;external_sat,external_unknown,external_unsat,
        external_unsat_note="solver responses; not independently proof-checked",
        domain_sat,domain_unknown,domain_unsat,domain_unsat_independently_replayed=true,
        native_models_replayed=length(domain.native_models))
    write(joinpath(directory,"replay.json"),JSON3.write(result))
    println(JSON3.write(result))
end
abspath(PROGRAM_FILE)==(@__FILE__) && verify(ARGS[1])
