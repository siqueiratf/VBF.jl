module CompactClosureLedgerTests
using Test,SQLite,VBFSearch
const VS=VBFSearch
function records(n;first_x=1,total_x=20000)
    [Dict{String,Any}("job_id"=>17,"first_x"=>i,"next_x"=>i+1,"total_x"=>total_x,"capped"=>0,
        "evidence"=>"arbitrary = \"αβ $(i)\"\nunknown_field = [1, 5, 19]\n"*repeat("unchanged proof text\n",12)) for i in first_x:first_x+n-1]
end
function envelope(rows)
    Dict{String,Any}("job_id"=>first(rows)["job_id"],"first_x"=>first(rows)["first_x"],
        "next_x"=>last(rows)["next_x"],"total_x"=>first(rows)["total_x"],
        "capped"=>maximum(r["capped"] for r in rows),"evidence"=>VS._closure_pack_chunks(rows))
end
@testset "Compact ledger retains all original evidence and detects corruption" begin
    for n in (1,64,4096)
        rows=records(n);block=envelope(rows)
        @test VS._closure_unpack_chunks(block)==rows
        n>1 && @test length(block["evidence"])<sum(sizeof(r["evidence"]) for r in rows)÷5
    end
    rows=records(64);block=envelope(rows)
    for field in ("job_id","first_x","next_x","total_x","capped")
        bad=deepcopy(block);bad[field]+=1
        @test_throws Exception VS._closure_unpack_chunks(bad)
    end
    for index in (1,17,length(block["evidence"]))
        bad=deepcopy(block);bad["evidence"][index]⊻=0x80
        @test_throws Exception VS._closure_unpack_chunks(bad)
    end
    empty=only(records(1;total_x=0));empty["next_x"]=1
    @test VS._closure_unpack_chunks(envelope([empty]))==[empty]
    capped=records(64);last(capped)["capped"]=1
    @test VS._closure_unpack_chunks(envelope(capped))==capped
    rows=records(4);rows[3]["first_x"]+=1
    @test_throws Exception VS._closure_unpack_chunks(envelope(rows))
    @test_throws Exception VS._closure_pack_chunks([])
end
@testset "SQLite preserves compact BLOBs, mixed legacy rows, and rollback" begin
    db=SQLite.DB()
    try
        VS._closure_create_schema(db)
        rows=records(64);block=envelope(rows)
        VS._closure_exec(db,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",Tuple(block[k] for k in (VS._CLOSURE_LEDGER_FIELDS...,"evidence")))
        legacy=only(records(1;first_x=65))
        VS._closure_exec(db,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",Tuple(legacy[k] for k in (VS._CLOSURE_LEDGER_FIELDS...,"evidence")))
        decoded=Any[];VS._closure_foreach_chunk(r->push!(decoded,r),db)
        @test decoded==vcat(rows,[legacy])
        @test VS._closure_count(db,"SELECT SUM(next_x-first_x) n FROM chunks")==65
        @test VS._closure_count(db,"SELECT COUNT(*) n FROM chunks")==2
        VS._closure_exec(db,"BEGIN IMMEDIATE")
        VS._closure_exec(db,"DELETE FROM chunks")
        VS._closure_exec(db,"ROLLBACK")
        @test VS._closure_count(db,"SELECT COUNT(*) n FROM chunks")==2
    finally
        close(db)
    end
end

if haskey(ENV,"VBF_CLOSURE_COMPACT_HELPER")
    @testset "Native migration and Julia decoder preserve the same logical stream" begin
        mktempdir() do directory
            source=joinpath(directory,"old.sqlite");target=joinpath(directory,"new.sqlite")
            db=SQLite.DB(source);rows=records(8200)
            empty=only(records(1;total_x=0));empty["job_id"]=18;empty["next_x"]=1;push!(rows,empty)
            try
                VS._closure_create_schema(db)
                VS._closure_exec(db,"CREATE TABLE storage_fixture(id INTEGER PRIMARY KEY, txt TEXT, bytes BLOB, real_value REAL, absent)")
                VS._closure_exec(db,"INSERT INTO storage_fixture VALUES(?,?,?,?,NULL)",(1,"αβ",UInt8[0,255],-1.25))
                VS._closure_exec(db,"BEGIN")
                for row in rows
                    VS._closure_exec(db,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",Tuple(row[k] for k in (VS._CLOSURE_LEDGER_FIELDS...,"evidence")))
                end
                VS._closure_exec(db,"COMMIT")
            finally
                close(db)
            end
            log=read(Cmd([ENV["VBF_CLOSURE_COMPACT_HELPER"],source,target]),String)
            @test occursin("\"event\":\"complete\"",log)
            db=SQLite.DB(target);before=SQLite.DB(source)
            try
                decoded=Any[];VS._closure_foreach_chunk(r->push!(decoded,r),db)
                @test decoded==rows
                @test VS._closure_count(db,"SELECT COUNT(*) n FROM chunks")==4
                @test isequal(VS._closure_rows(db,"SELECT * FROM storage_fixture"),VS._closure_rows(before,"SELECT * FROM storage_fixture"))
            finally
                close(db);close(before)
            end
            @test_throws ProcessFailedException run(pipeline(Cmd([ENV["VBF_CLOSURE_COMPACT_HELPER"],source,target]);stdout=devnull,stderr=devnull))
            verified=read(Cmd([ENV["VBF_CLOSURE_COMPACT_HELPER"],"--verify",source,target]),String)
            @test occursin("\"event\":\"complete\"",verified)
            db=SQLite.DB(target)
            try
                VS._closure_exec(db,"DELETE FROM chunks WHERE job_id=17 AND first_x=1")
            finally
                close(db)
            end
            @test_throws ProcessFailedException run(pipeline(Cmd([ENV["VBF_CLOSURE_COMPACT_HELPER"],"--verify",source,target]);stdout=devnull,stderr=devnull))
        end
    end
end
end
