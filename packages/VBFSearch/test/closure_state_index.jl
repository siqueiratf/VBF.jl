module ClosureStateIndexTests
using Test,VBF,VBFSearch,SQLite,TOML,SHA
const FP=VBFSearch

"""Fresh, independent checkpoint using the normal identity/archive builder."""
function fixture(directory)
    p=FP.properties(gold_apn(8).lut)
    input=joinpath(directory,"state-index-root.tsv");write(input,p["lut_hex"]*"\n")
    digest=bytes2hex(open(SHA.sha256,input))
    identity=Dict{String,Any}("schema"=>FP.CLOSURE_SCHEMA,"campaign"=>input,
        "campaign_sha256"=>digest,"roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,
        "inputs"=>Dict(input=>digest),"implementation"=>FP.implementation_fingerprint(),"julia"=>string(VERSION),
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23))
    roots=[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="state-index-fixture:1")]
    run=joinpath(directory,"state-index-run");FP._closure_initialize(run,identity,roots)
    run
end

hasindex(db)=FP._closure_count(db,"SELECT COUNT(*) n FROM sqlite_master WHERE type='index' AND name='candidates_state'")==1

"""Snapshot logical rows, excluding physical SQLite catalog/index metadata."""
function snapshot(db)
    tables=FP._closure_rows(db,"SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
    Dict(t["name"]=>FP._closure_rows(db,"SELECT * FROM \"$(t["name"])\" ORDER BY rowid") for t in tables)
end

function legacy!(run)
    db=SQLite.DB(joinpath(run,"closure.sqlite"))
    try
        FP._closure_exec(db,"DROP INDEX candidates_state")
        @test !hasindex(db)
    finally
        close(db)
    end
end

@testset "Candidate-state index covers counts and preserves legacy checkpoint rows" begin
    mktempdir() do directory
        run=fixture(directory);db=SQLite.DB(joinpath(run,"closure.sqlite"))
        before=nothing;count=0
        try
            @test hasindex(db)
            f=gold_apn(8).lut
            for i in 1:12
                p=FP.properties(f .⊻ UInt8(i))
                FP._closure_insert_candidate!((db=db,),p;state=isodd(i) ? "unresolved_equivalence" : "awaiting_equivalence")
            end
            before=snapshot(db)
            count=FP._closure_count(db,"SELECT COUNT(*) n FROM candidates WHERE state='unresolved_equivalence'")
            @test count==6
            FP._closure_exec(db,"DROP INDEX candidates_state")
            @test !hasindex(db)
        finally
            close(db)
        end
        s=FP._closure_open(run)
        schema_version=0
        try
            @test hasindex(s.db)
            @test isequal(snapshot(s.db),before)
            @test FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates WHERE state='unresolved_equivalence'")==count
            plan=FP._closure_rows(s.db,"EXPLAIN QUERY PLAN SELECT COUNT(*) FROM candidates WHERE state='unresolved_equivalence'")
            @test any(row->occursin("COVERING INDEX candidates_state",row["detail"]),plan)
            schema_version=only(FP._closure_rows(s.db,"PRAGMA schema_version"))["schema_version"]
        finally
            FP._closure_close(s)
        end
        s=FP._closure_open(run)
        try
            @test hasindex(s.db)
            @test only(FP._closure_rows(s.db,"PRAGMA schema_version"))["schema_version"]==schema_version
            @test isequal(snapshot(s.db),before)
        finally
            FP._closure_close(s)
        end
    end
end

@testset "Checkpoint guards reject before adding an optional physical index" begin
    for corruption in (:implementation,:input,:archive)
        mktempdir() do directory
            run=fixture(directory);legacy!(run)
            identity=TOML.parsefile(joinpath(run,"identity.toml"))
            if corruption===:implementation
                identity["implementation"]["packages/VBFSearch/src/closure_store.jl"]=repeat("0",64)
                open(io->TOML.print(io,identity;sorted=true),joinpath(run,"identity.toml"),"w")
                db=SQLite.DB(joinpath(run,"closure.sqlite"))
                try
                    FP._closure_exec(db,"UPDATE metadata SET value=? WHERE key='identity'",(FP._closure_text(identity),))
                finally
                    close(db)
                end
            elseif corruption===:input
                write(identity["campaign"],"changed fixture input\n")
            else
                archived=joinpath(run,"replay","workspace","packages/VBFSearch/src/closure_store.jl")
                open(io->write(io,"\n# changed fixture archive\n"),archived,"a")
            end
            db=SQLite.DB(joinpath(run,"closure.sqlite"))
            before=try snapshot(db) finally close(db) end
            @test_throws ErrorException FP._closure_open(run)
            db=SQLite.DB(joinpath(run,"closure.sqlite"))
            try
                @test !hasindex(db)
                @test isequal(snapshot(db),before)
            finally
                close(db)
            end
        end
    end
end

@testset "Optional-index installation requires the exclusive checkpoint lease" begin
    mktempdir() do directory
        run=fixture(directory);legacy!(run)
        lease=FP._closure_lease(run)
        try
            @test_throws ErrorException FP._closure_open(run)
            db=SQLite.DB(joinpath(run,"closure.sqlite"))
            try
                @test !hasindex(db)
            finally
                close(db)
            end
        finally
            close(lease)
        end
        s=FP._closure_open(run)
        try
            @test hasindex(s.db)
        finally
            FP._closure_close(s)
        end
    end
end
end
