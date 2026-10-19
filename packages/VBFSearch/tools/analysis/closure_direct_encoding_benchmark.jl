"""Byte-parity and allocation controls for direct canonical coset-proof encoding."""
module ClosureDirectEncodingBenchmark
using VBF,VBFSearch,JSON3,SHA,Statistics,Dates,Test
include("closure_direct_encoding.jl")
include("closure_worker_integration_audit.jl")
const D=ClosureDirectEncoding
const FP=VBFSearch
const Q=VBF.QuadraticExtensions

function synthetic_chunks(n)
    [Dict("proof"=>Dict{String,Any}("V5_forms"=>[134658561,34016355,17372590,10987437,4393092],
        "candidate_spaces"=>i%3,"capped"=>i==n,"completion_spaces"=>i%7,
        "coset_order"=>"increasing nonzero quotient integer with exact bent count",
        "coset_representative"=>27i,"du_reject"=>Int(i%5==0),"first_x"=>i,
        "heuristic_pruning"=>false,"linear_system_candidates"=>101i,
        "next_x"=>i+1,"total_x"=>n)) for i in 1:n]
end

function controls()
    checks=0
    for n in (1,2,64,256),future in (false,true)
        chunks=synthetic_chunks(n)
        future && (chunks[end]["proof"]["future_field"]="αβ\nexact \"quoted\" evidence")
        a=D.baseline_row(17,chunks);b=D.direct_row(17,chunks)
        @test a==b;checks+=1
        for c in chunks
            io=IOBuffer();D.write_proof(io,c["proof"])
            @test String(take!(io))==D.text_proof(c["proof"]);checks+=1
        end
    end
    empty=Dict("proof"=>Dict{String,Any}("first_x"=>1,"next_x"=>1,"total_x"=>0,"capped"=>false))
    @test D.direct_row(17,[empty])==D.baseline_row(17,[empty]);checks+=1
    checks
end

function run(holdout,parents_input,out;repeats=7)
    mkpath(out);started=time();checks=controls()
    r=first(JSON3.read(read(holdout,String))["records"])
    parents=Dict(Int(p["parent_id"])=>p for p in JSON3.read(read(parents_input,String))["parents"])
    s,jobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"isolated-fixture"),[r],parents)
    packet=try FP._closure_work_packet(s,only(jobs)) finally FP._closure_close(s) end
    table=Q.PolarRankTable(Q.geometry(8));context=FP.ClosureWorkContext(;rank_table=table)
    work=FP._closure_compute(packet;context,seconds=60,evaluations=256)["work"]
    work["done"] || error("incomplete fixture packet")
    chunks=work["chunks"];job=Int(packet["job_id"])
    expected=D.baseline_row(job,chunks);actual=D.direct_row(job,chunks)
    @test expected==actual;checks+=1
    timings=Dict("baseline"=>Any[],"direct"=>Any[],"production"=>Any[])
    for i in 1:repeats,which in (isodd(i) ? (:baseline,:production,:direct) : (:direct,:production,:baseline))
        t=which===:baseline ? (@timed D.baseline_row(job,chunks)) : which===:direct ?
            (@timed D.direct_row(job,chunks)) : (@timed FP._closure_ledger_row(job,chunks))
        @test t.value==expected;checks+=1
        push!(timings[String(which)],Dict("seconds"=>t.time,"bytes"=>t.bytes,"gc_seconds"=>t.gctime))
    end
    summary=Dict(k=>Dict("median_seconds"=>median(x["seconds"] for x in values),
        "median_bytes"=>median(x["bytes"] for x in values)) for (k,values) in timings)
    report=Dict("schema"=>"vbfsearch-direct-coset-encoding-v1","created_utc"=>string(now(UTC))*"Z",
        "source_bindings"=>D.source_bindings,"tool_sha256"=>bytes2hex(open(sha256,@__FILE__)),
        "prototype_sha256"=>bytes2hex(open(sha256,joinpath(@__DIR__,"closure_direct_encoding.jl"))),
        "parent_id"=>Int(r["parent_id"]),"cosets"=>length(chunks),"checks"=>checks,
        "compressed_bytes"=>length(actual.evidence),"compressed_sha256"=>bytes2hex(sha256(actual.evidence)),
        "byte_for_byte_equal"=>true,"summary"=>summary,"timings"=>timings,
        "allocation_reduction"=>1-summary["direct"]["median_bytes"]/summary["baseline"]["median_bytes"],
        "median_speedup"=>summary["baseline"]["median_seconds"]/summary["direct"]["median_seconds"],
        "elapsed_seconds"=>time()-started)
    open(io->JSON3.pretty(io,report),joinpath(out,"report.json"),"w")
    println(JSON3.write(report));report
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && ClosureDirectEncodingBenchmark.run(ARGS[1],ARGS[2],ARGS[3])
