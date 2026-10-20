module ClosureEAResumeTests
using Test,VBF,VBFSearch,TOML
include(joinpath(@__DIR__,"..","tools","closure_continuous.jl"))
const FP=VBFSearch

"""Synthetic completed coverage tests scheduling; the EA witness is real.

The zero-dimensional kernels model committed coverage, rather than claiming a
construction result about the Gold function. No synthetic proof is admitted as
an equivalence certificate: VBF must find and replay the positive EA witness.
"""
function ea_only_fixture(directory;complete_constructions=true)
    mkpath(directory)
    lut=gold_apn(8).lut;p=FP.properties(lut)
    input=joinpath(directory,"input.tsv");write(input,p["lut_hex"]*"\n")
    digest=FP.DiscoveryEvidence.filehash(input)
    identity=Dict{String,Any}("schema"=>FP.CLOSURE_SCHEMA,"campaign"=>input,
        "campaign_sha256"=>digest,"roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,
        "inputs"=>Dict(input=>digest),"implementation"=>FP.implementation_fingerprint(),"julia"=>string(VERSION),
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23))
    roots=[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="ea-resume-fixture:1")]
    run=joinpath(directory,"run");FP._closure_initialize(run,identity,roots)
    store=FP._closure_open(run)
    candidate=FP.properties(lut .⊻ UInt8(1))
    try
        FP._closure_transaction(store) do
            job=only(FP._closure_rows(store.db,"SELECT * FROM jobs WHERE kind='switching'"))
            if complete_constructions
                FP._closure_exec(store.db,"UPDATE jobs SET status='done' WHERE kind='prepare_v5'")
                for direction in 1:255
                    FP._closure_exec(store.db,"INSERT INTO kernels VALUES(?,?,0,?)",(job["id"],direction,"fixture_only = true\n"))
                end
                FP._closure_exec(store.db,"UPDATE jobs SET status='done',direction=256 WHERE id=?",(job["id"],))
            end
            FP._closure_record_candidate!(store,job,candidate,"fixture-only",Dict("fixture_only"=>true))
        end
        FP._closure_validate_cursors(store)
        ContinuousSeedSearch.ClosureOperations.bind_active_environment!(store)
    finally
        FP._closure_close(store)
    end
    FP.DiscoveryStore.atomic_toml(joinpath(run,"progress.toml"),FP.closure_snapshot(run))
    (;run,candidate=candidate["lut_sha256"])
end

function resume_until_classified(run,candidate,evidence,stop)
    cancelled=Threads.Atomic{Bool}(false)
    watcher=@async begin
        while !cancelled[]
            db=FP.SQLite.DB("file:"*joinpath(run,"closure.sqlite")*"?mode=ro")
            try
                row=only(FP._closure_rows(db,"SELECT class_id FROM candidates WHERE id=?",(candidate,)))
                if !ismissing(row["class_id"])
                    write(stop,"EA recovery completed\n");break
                end
            finally
                close(db)
            end
            sleep(.01)
        end
    end
    try
        ContinuousSeedSearch.run(Dict{String,Any}("run"=>run,"evidence"=>evidence,
            "parent_scope"=>"discovered","concurrency"=>1,"window_size"=>1,
            "duration_seconds"=>30.0,"equivalence_seconds"=>5.0,"equivalence_nodes"=>100000,
            "stop_files"=>[stop],"precompute_rank_table"=>false,"checkpoint_on_stop"=>false))
    finally
        cancelled[]=true;wait(watcher)
    end
end

@testset "A staged EA-only frontier resumes without dispatching excluded root constructions" begin
    mktempdir() do directory
        fixture=ea_only_fixture(joinpath(directory,"source"))
        bundle=joinpath(directory,"staged")
        @test FP.closure_export_checkpoint(fixture.run;output=bundle,reserve_bytes=0)["verified"]
        result=resume_until_classified(bundle,fixture.candidate,joinpath(directory,"session"),joinpath(directory,"operator-stop"))
        @test result["state"]=="paused_external"
        @test result["processed_packets"]==1 && result["evaluations"]==0
        @test result["seed_statistics"]["completed_this_session"]==0
        @test result["runtime_metrics"]["packet_totals"]["deduplicate"]["packets"]==1
        store=FP._closure_open(bundle)
        try
            row=only(FP._closure_rows(store.db,"SELECT class_id,state FROM candidates WHERE id=?",(fixture.candidate,)))
            @test row["class_id"]==1 && row["state"]=="equivalent"
            proofs=FP._closure_rows(store.db,"SELECT evidence FROM comparisons")
            @test length(proofs)==1 && FP.verify_comparison(TOML.parse(only(proofs)["evidence"]))
            @test FP._closure_count(store.db,"SELECT COUNT(*) n FROM parents")==1
            @test FP._closure_count(store.db,"SELECT COUNT(*) n FROM jobs WHERE status='running'")==0
        finally
            FP._closure_close(store)
        end
        idle=ContinuousSeedSearch.run(Dict{String,Any}("run"=>bundle,"evidence"=>joinpath(directory,"idle"),
            "parent_scope"=>"discovered","concurrency"=>1,"duration_seconds"=>.3,
            "precompute_rank_table"=>false,"checkpoint_on_stop"=>false))
        @test idle["state"]=="paused_budget" && idle["processed_packets"]==0
        @test idle["seed_statistics"]["completed_this_session"]==0
    end
end

@testset "Global EA fallback never dispatches an excluded root's unfinished constructions" begin
    mktempdir() do directory
        fixture=ea_only_fixture(joinpath(directory,"source");complete_constructions=false)
        result=resume_until_classified(fixture.run,fixture.candidate,joinpath(directory,"session"),joinpath(directory,"STOP"))
        @test result["state"]=="paused_external" && result["processed_packets"]==1
        @test result["seed_statistics"]["completed_this_session"]==0
        store=FP._closure_open(fixture.run)
        try
            jobs=FP._closure_rows(store.db,"SELECT status,last_session FROM jobs WHERE kind IN ('prepare_v5','v5','switching')")
            @test length(jobs)==2 && all(j->j["status"]=="pending" && j["last_session"]==0,jobs)
            @test FP._closure_count(store.db,"SELECT COUNT(*) n FROM candidates WHERE class_id=1")==2
        finally
            FP._closure_close(store)
        end
    end
end
end
