using VBF,JSON3,SHA,Dates
include(joinpath(@__DIR__,"quadratic_completion_smt.jl"))
include(joinpath(@__DIR__,"quadratic_completion_domains.jl"))
const D=QuadraticCompletionDomains
const S=QuadraticCompletionSMT
const Q=VBF.QuadraticExtensions

"Bounded domain-propagation realdata controls, with positive VBF model replay."
function main(directory)
    mkpath(directory);G=Q.geometry(8);records=Any[]
    native_source=joinpath(dirname(pathof(VBF)),"constructions","quadratic_extensions.jl")
    native_source_sha256=bytes2hex(open(sha256,native_source))
    inputs=[("parent170-whole-v5",UInt32[136265460,67900911,43432498,26361691,3242677],22),
        ("parent170-u6-native-empty",UInt32[136265402,67900833,43432498,26361621,3242677,78],nothing),
        ("parent170-u6-native-positive",UInt32[134441522,67900911,42659572,26110877,2961011,1856710],nothing)]
    warm=S.problem(Q.geometry(4),UInt32[0x21]);D.solve(warm;timeout_seconds=Inf)
    for (name,U,need) in inputs
        p=S.problem(G,U);result=D.solve(p;max_nodes=1000000,timeout_seconds=1,capture_proof=p.r==2)
        replay=result.status=="sat" ? S.replay_model(p,result.vectors;need) : nothing
        unsat_replayed=result.status=="unsat" && D.replay_unsat(p,result.proof)
        result.status=="unsat" && !unsat_replayed && error("UNSAT tree replay failed")
        rec=(;name,U,r=p.r,D=p.D,residual_flats=length(p.flats),native_target_need=need,result,replay,unsat_replayed)
        push!(records,rec)
        println(JSON3.write((;name,status=result.status,nodes=result.nodes,seconds=result.seconds,unsat_replayed,replay)))
        flush(stdout)
    end
    U=inputs[1][2];native_start=time_ns()
    native=Q.v5_extensions(G,U,22,Q.V5Work(23);beta=Q.BETA8,max_kernel=23,du7_filter=:bitsets)
    native_seconds=(time_ns()-native_start)*1e-9
    !native.capped && native.nX_used==native.nX || error("native comparison incomplete")
    native_models=[S.replay_model(S.problem(G,U),S.model_of_space(S.problem(G,U),space);need=22) for space in native.Ss]
    all(m->m.target_match,native_models) || error("native target mismatch")
    positive_in_native=all(rec.replay===nothing || rec.r!=2 || any(m->m.S==rec.replay.S,native_models) for rec in records)
    positive_in_native || error("domain completion missing from complete native comparison")
    output=(;created_utc=string(now(UTC)),scope="bounded first-model feasibility; all retained UNSAT trees independently replayed",
        native_source_sha256,native_positive_subset_verified=positive_in_native,
        native_timing_note="one full invocation, no shared polar rank table; not a standalone timing benchmark",
        prototype_sha256=bytes2hex(open(sha256,joinpath(@__DIR__,"quadratic_completion_domains.jl"))),records)
    write(joinpath(directory,"domains-pilot.json"),JSON3.write(merge(output,(;native_seconds,native_complete=true,native_models))))
end
abspath(PROGRAM_FILE)==(@__FILE__) && main(ARGS[1])
