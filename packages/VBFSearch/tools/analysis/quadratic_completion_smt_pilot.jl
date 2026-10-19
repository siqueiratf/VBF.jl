using VBF,JSON3,SHA,Dates
include(joinpath(@__DIR__,"quadratic_completion_smt.jl"))
const C=QuadraticCompletionSMT
const Q=VBF.QuadraticExtensions

"""Bounded installed-solver feasibility controls; never changes campaign state.

Usage: julia --project=docs/inspector quadratic_completion_smt_pilot.jl OUTPUT
Each query is retained with its exact solver input/output and positive VBF replay.
The initial pilot asks only for first models and small n=4 exhaustion, and makes
no population or full n=8 completion coverage claim.
"""
function main(directory)
    mkpath(directory);records=Any[]
    native_source=joinpath(dirname(pathof(VBF)),"constructions","quadratic_extensions.jl")
    native_source_sha256=bytes2hex(open(sha256,native_source))
    function record_query(p,name,solver;need=nothing,blocked=Vector{Vector{UInt32}}(),timeout_ms=250)
        rec=C.query(p,joinpath(directory,name,solver);solver,timeout_ms,blocked)
        rec["name"]=name;rec["n"]=p.G.n;rec["r"]=p.r;rec["D"]=p.D
        rec["U_forms"]=p.R;rec["residual_flat_count"]=length(p.flats)
        rec["native_target_need"]=need
        if rec["vectors"]!==nothing
            replay=C.replay_model(p,rec["vectors"];need)
            rec["positive_replay"]=replay
        elseif rec["status"]=="sat"
            rec["model_parse_failed"]=true
        end
        push!(records,rec)
        write(joinpath(directory,"pilot.json"),JSON3.write((;
            created_utc=string(now(UTC)),scope="bounded first-model feasibility; not complete n8 enumeration",
            native_source_sha256,
            prototype_sha256=bytes2hex(open(sha256,joinpath(@__DIR__,"quadratic_completion_smt.jl"))),records)))
        println(JSON3.write(rec));flush(stdout)
        rec
    end
    G4=Q.geometry(4);U4=UInt32[0x21];p4=C.problem(G4,U4)
    spaces=Set{Vector{UInt32}}();beta4=Q.bent_fourier(G4)
    for need in 0:2
        native=Q.v5_extensions(G4,U4,need,Q.V5Work(5,4);beta=beta4,max_kernel=5,du7_filter=:bitsets)
        native.capped && error("unexpected n4 cap");union!(spaces,native.Ss)
    end
    blocks=[C.model_of_space(p4,S) for S in spaces]
    length(blocks)==20 || error("n4 native control count")
    for solver in ("cvc4","yices-smt2")
        record_query(p4,"n4-first",solver;timeout_ms=500)
        rec=record_query(p4,"n4-block-all20",solver;blocked=blocks,timeout_ms=500)
        rec["status"]=="unsat" || error("n4 exact native exhaustion disagrees with solver")
    end
    G8=Q.geometry(8)
    U5=UInt32[136265460,67900911,43432498,26361691,3242677]
    for solver in ("cvc4","yices-smt2")
        record_query(C.problem(G8,U5),"parent170-whole-v5",solver;need=22,timeout_ms=1000)
    end
    U6_empty=UInt32[136265402,67900833,43432498,26361621,3242677,78]
    U6_positive=UInt32[134441522,67900911,42659572,26110877,2961011,1856710]
    for (name,U) in (("parent170-u6-native-empty",U6_empty),("parent170-u6-native-positive",U6_positive))
        for solver in ("cvc4","yices-smt2")
            record_query(C.problem(G8,U),name,solver;timeout_ms=1000)
        end
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && main(ARGS[1])
