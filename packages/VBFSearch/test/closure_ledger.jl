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

@testset "Streaming worker ledger is byte-identical to generic row packing" begin
    function proof_chunks(n)
        [Dict("proof"=>Dict{String,Any}("V5_forms"=>[134658561,34016355,17372590,10987437,4393092],
            "candidate_spaces"=>i%3,"capped"=>i==n,"completion_spaces"=>i%7,
            "coset_order"=>"increasing nonzero quotient integer with exact bent count",
            "coset_representative"=>27i,"du_reject"=>Int(i%5==0),"first_x"=>i,
            "heuristic_pruning"=>false,"linear_system_candidates"=>101i,
            "next_x"=>i+1,"total_x"=>n)) for i in 1:n]
    end
    for n in (1,2,64,4096),future in (false,true)
        chunks=proof_chunks(n)
        if future
            chunks[end]["proof"]["future_field"]="αβ\nexact \"quoted\" evidence"
        end
        expected=[Dict{String,Any}("job_id"=>17,"first_x"=>c["proof"]["first_x"],
            "next_x"=>c["proof"]["next_x"],"total_x"=>c["proof"]["total_x"],
            "capped"=>Int(c["proof"]["capped"]),"evidence"=>VS._closure_coset_evidence_text(c["proof"])) for c in chunks]
        packed=VS._closure_ledger_row(17,chunks)
        @test packed.evidence==(n==1 ? first(expected)["evidence"] : VS._closure_pack_chunks(expected))
        @test packed.job_id==17 && packed.first_x==1 && packed.next_x==n+1 && packed.total_x==n && packed.capped==1
        envelope=Dict{String,Any}(String(k)=>v for (k,v) in pairs(packed))
        @test VS._closure_unpack_chunks(envelope)==expected
        if !future
            native=map(chunks) do chunk
                p=chunk["proof"]
                proof=VS._ClosureCosetProof(Tuple(p["V5_forms"]),p["first_x"],p["next_x"],p["total_x"],
                    p["candidate_spaces"],p["linear_system_candidates"],p["du_reject"],p["completion_spaces"],
                    p["coset_representative"],p["capped"])
                VS._ClosureCosetChunk(proof,nothing)
            end
            @test VS._closure_ledger_row(17,native)==packed
        end
    end
    empty=Dict("proof"=>Dict{String,Any}("first_x"=>1,"next_x"=>1,"total_x"=>0,"capped"=>false))
    @test VS._closure_ledger_row(17,[empty]).evidence==VS._closure_text(empty["proof"])
    @test_throws Exception VS._closure_ledger_row(17,[])
    @test_throws Exception VS._closure_ledger_row(17,fill(empty,65537))
    bad=proof_chunks(2);bad[end]["proof"]["first_x"]=-1
    @test_throws Exception VS._closure_ledger_row(17,bad)
    @test_throws Exception VS._closure_ledger_row(-1,proof_chunks(2))
end

@testset "Normalized native and mixed proofs preserve template bytes and validation" begin
    native=[VS._ClosureCosetProof((1,2,3,4,5),i,i+1,12,i%3,17(i%3),i%2,i%3,23i,i%3==0) for i in 1:12]
    generic=copy.(native)
    expected=VS._closure_v2_payload(17,generic)
    @test expected!==nothing
    for proofs in (native,Any[native...],Tuple(native),Any[isodd(i) ? p : copy(p) for (i,p) in enumerate(native)])
        @test VS._closure_v2_payload(17,proofs)==expected
    end
    mixed=Any[native...];mixed[2]=copy(native[2]);mixed[2]["V5_forms"]=Float64.(mixed[2]["V5_forms"])
    @test VS._closure_v2_payload(17,mixed)==expected
    badforms=[(-1,2,3,4,5)]
    Sys.WORD_SIZE==64 && push!(badforms,(Int(typemax(UInt32))+1,2,3,4,5))
    for forms in badforms
        proof=VS._ClosureCosetProof(forms,1,2,6,0,0,0,0,1,false)
        @test VS._closure_v2_payload(17,[proof])===nothing
        @test VS._closure_v2_payload(17,[copy(proof)])===nothing
    end
    for (field,value) in (("first_x",99),("next_x",99),("total_x",99),("completion_spaces",-1))
        broken=deepcopy(generic);broken[2][field]=value
        @test VS._closure_v2_payload(17,broken)===nothing
    end
end

@testset "Direct proof encoding preserves canonical text and bounded fallback writes" begin
    native=VS._ClosureCosetProof((1,2,3,4,5),7,8,16,1,9,0,3,23,false)
    ordinary=copy(native);future=copy(native);future["future_field"]="αβ\nquoted \"proof\""
    empty=Dict{String,Any}("first_x"=>1,"next_x"=>1,"total_x"=>0,"capped"=>false)
    for proof in (native,ordinary,future,empty)
        expected=VS._closure_text(proof)
        @test VS._closure_coset_evidence_text(proof)==expected
        io=IOBuffer();write(io,"α")
        VS._closure_write_coset_evidence(io,proof,sizeof("α")+sizeof(expected))
        @test String(take!(io))=="α"*expected
        @test_throws ErrorException VS._closure_write_coset_evidence(IOBuffer(),proof,0)
    end
    io=IOBuffer()
    @test_throws ErrorException VS._closure_write_coset_evidence(io,future,0)
    @test position(io)==0
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
