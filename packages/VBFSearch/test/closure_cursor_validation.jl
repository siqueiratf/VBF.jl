module ClosureCursorValidationTests
using Test, Random, SQLite, DBInterface, VBFSearch
const VS=VBFSearch

# Frozen pre-streaming implementation. This independent control flow keeps the
# differential oracle for legacy acceptance, exception types, and error priority.
function legacy_validate_cursors(s)
    for job in VS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind IN ('v5','switching')")
        d=Int(job["direction"]);c=parse(BigInt,job["combination"])
        d>=1 && c>=1 || error("invalid closure cursor")
        if job["kind"]=="switching"
            d<=256 && (d!=256 || c==1) || error("invalid switching exhaustion cursor")
            for row in VS._closure_rows(s.db,"SELECT direction,dimension FROM kernels WHERE job_id=? ORDER BY direction",(job["id"],))
                u=Int(row["direction"]);u>d && error("switching kernel ahead of committed cursor")
                if u<d
                    total=(big(1)<<Int(row["dimension"]))-1
                    VS._closure_count(s.db,"SELECT COUNT(*) n FROM evaluations WHERE job_id=? AND direction=?",(job["id"],u))==total || error("incomplete earlier switching direction")
                end
            end
            VS._closure_count(s.db,"SELECT COUNT(*) n FROM kernels WHERE job_id=? AND direction<?",(job["id"],d))==d-1 || error("missing switching kernel coverage")
            n=VS._closure_count(s.db,"SELECT COUNT(*) n FROM evaluations WHERE job_id=? AND direction=?",(job["id"],d))
            n==c-1 || error("switching cursor disagrees with evaluations")
            job["status"]=="done" && d!=256 && error("switching job marked complete before direction 255")
        else
            next=1
            for row in DBInterface.execute(s.db,"SELECT first_x,next_x,capped FROM chunks WHERE job_id=? ORDER BY first_x",(job["id"],))
                row.first_x==next || error("gap in extension coset coverage")
                row.capped==0 || error("capped extension coverage requires explicit recovery")
                next=Int(row.next_x)
            end
            d==next || error("extension cursor disagrees with chunk ledger")
            if job["status"]=="done"
                chunks=VS._closure_rows(s.db,"SELECT total_x FROM chunks WHERE job_id=? ORDER BY first_x DESC LIMIT 1",(job["id"],))
                !isempty(chunks) && d==only(chunks)["total_x"]+1 || error("extension job marked complete without exhaustive coverage")
            end
        end
    end
end

function fixture(f;kind="v5",direction=1,combination="1",status="pending",id=1)
    db=SQLite.DB()
    try
        VS._closure_create_schema(db)
        job!(db,id,kind,direction,combination,status)
        f(db)
    finally
        close(db)
    end
end
job!(db,id,kind,direction=1,combination="1",status="pending")=
    VS._closure_exec(db,"INSERT INTO jobs(id,kind,job_key,payload,direction,combination,status) VALUES(?,?,?,'unused payload',?,?,?)",(id,kind,string(id),direction,combination,status))
kernel!(db,id,d,dimension)=VS._closure_exec(db,"INSERT INTO kernels VALUES(?,?,?,'unused evidence')",(id,d,dimension))
chunk!(db,id,first,next,total=next-1,capped=0)=VS._closure_exec(db,"INSERT INTO chunks VALUES(?,?,?,?,?,'unused evidence')",(id,first,next,total,capped))
evaluation!(db,id,d,c)=VS._closure_exec(db,"INSERT INTO evaluations VALUES(?,?,?,'unused candidate',1)",(id,d,string(c)))
function prefix!(db,id,d;dimension=0)
    for u in 1:d-1
        kernel!(db,id,u,dimension)
        for c in 1:(1<<dimension)-1
            evaluation!(db,id,u,c)
        end
    end
end
function outcome(f,db)
    try
        f((;db));(:ok,nothing)
    catch e
        (typeof(e),sprint(showerror,e))
    end
end
function parity(db;accepted=nothing,message=nothing)
    before=only(VS._closure_rows(db,"SELECT total_changes() n"))["n"]
    old=outcome(legacy_validate_cursors,db)
    new=outcome(VS._closure_validate_cursors,db)
    @test new==old
    @test only(VS._closure_rows(db,"SELECT total_changes() n"))["n"]==before
    accepted===nothing || @test (new[1]===:ok)==accepted
    message===nothing || @test new[2]==message
    # Both successful and failed validation must leave no active iterator that
    # interferes with a subsequent transaction or a repeated validation.
    VS._closure_exec(db,"BEGIN IMMEDIATE")
    VS._closure_exec(db,"ROLLBACK")
    @test outcome(VS._closure_validate_cursors,db)==new
end

@testset "Streaming closure cursor validation matches frozen checks" begin
    @testset "Empty frontier and extension coverage" begin
        fixture(;kind="deduplicate",direction="ignored",combination="ignored") do db
            kernel!(db,1,0,"ignored");chunk!(db,1,0,0);evaluation!(db,1,0,1)
            parity(db;accepted=true)
        end
        fixture(db->parity(db;accepted=true))
        fixture(db->parity(db;accepted=false,message="extension job marked complete without exhaustive coverage");status="done")
        fixture(;direction=7,status="done") do db
            chunk!(db,1,1,3,99);chunk!(db,1,3,7,6)
            parity(db;accepted=true)
        end
        fixture(;direction=1,status="done") do db
            chunk!(db,1,1,1,0) # Exhaustion marker with no consumed coset.
            parity(db;accepted=true)
        end
        for (first,next,total,capped,status,direction) in (
            (2,3,2,0,"pending",3), (1,2,1,1,"pending",2),
            (1,2,1,"false","pending",2), (1,2,1,0,"pending",3),
            (1,2,5,0,"done",2), (1,0,1,0,"pending",1),
            (1,1,99,0,"pending",1), (1,2,"ignored",0,"pending",2),
            (1,2,"invalid total",0,"done",2), (1,1.5,1,0,"pending",2),
            (1,"invalid next",1,0,"pending",2), (1.5,2,1,0,"pending",2),
            ("invalid first",2,1,0,"pending",2), (2,3,2,1,"pending",3))
            fixture(;direction,status) do db
                chunk!(db,1,first,next,total,capped);parity(db)
            end
        end
        for second in (2,4)
            fixture(;direction=5) do db
                chunk!(db,1,1,3);chunk!(db,1,second,5);parity(db;accepted=false,message="gap in extension coset coverage")
            end
        end
        fixture(;direction=3) do db
            chunk!(db,1,1,3);chunk!(db,1,3,3,2)
            parity(db;accepted=true)
        end
    end
    @testset "Cursor parsing and status boundaries" begin
        for kind in ("v5","switching"), combination in ("0","-1","","garbage","1.0",string(big(1)<<256),UInt8[0x31])
            fixture(db->parity(db);kind,combination)
        end
        for kind in ("v5","switching"), direction in (0,-1,typemin(Int),1.5,"invalid direction")
            fixture(db->parity(db);kind,direction)
        end
        for status in ("pending","paused","running","unknown")
            fixture(db->parity(db;accepted=true);status)
            fixture(db->parity(db;accepted=true);kind="switching",status)
        end
        fixture(;kind="switching",direction=256,status="done") do db
            prefix!(db,1,256);parity(db;accepted=true)
        end
        for direction in (256,257), combination in ("1","2")
            fixture(db->parity(db);kind="switching",direction,combination)
        end
        fixture(;kind="switching",direction=255,status="done") do db
            prefix!(db,1,255);parity(db;accepted=false,message="switching job marked complete before direction 255")
        end
    end
    @testset "Switching kernels, arbitrary-size counts, and ignored evidence" begin
        for dimension in (-4096,-1,0,1,2,65,1.5,"invalid dimension")
            fixture(;kind="switching",direction=2) do db
                kernel!(db,1,1,dimension)
                dimension in (1,2) && foreach(c->evaluation!(db,1,1,c),1:(1<<dimension)-1)
                parity(db)
            end
        end
        fixture(;kind="switching",direction=2,combination="3") do db
            prefix!(db,1,2;dimension=2)
            kernel!(db,1,2,"current dimension is not checked")
            evaluation!(db,1,2,1);evaluation!(db,1,2,2)
            parity(db;accepted=true)
        end
        for u in (-1,0) # Legacy count check permits these replacements for direction 1.
            fixture(;kind="switching",direction=2) do db
                kernel!(db,1,u,0);parity(db;accepted=true)
            end
        end
        for u in (0,2,3,1.5,"invalid direction")
            fixture(;kind="switching") do db
                kernel!(db,1,u,0);parity(db)
            end
        end
        fixture(;kind="switching",direction=3) do db
            kernel!(db,1,1,1);kernel!(db,1,4,0)
            parity(db;accepted=false,message="incomplete earlier switching direction")
        end
        fixture(;kind="switching",direction=3) do db
            kernel!(db,1,1,0);parity(db;accepted=false,message="missing switching kernel coverage")
        end
        fixture(;kind="switching",combination="2") do db
            parity(db;accepted=false,message="switching cursor disagrees with evaluations")
        end
        fixture(;kind="switching") do db
            evaluation!(db,1,-1,1);evaluation!(db,1,1.5,1);evaluation!(db,1,"ignored text",1)
            kernel!(db,1,1,"ignored current dimension")
            parity(db;accepted=true)
        end
    end
    @testset "Merged job streams ignore unrelated and orphan ledgers" begin
        fixture(;id=-3) do db
            job!(db,0,"switching",2);kernel!(db,0,1,0)
            job!(db,2,"v5",3,"1","done");chunk!(db,2,1,3,2)
            job!(db,5,"switching",3);prefix!(db,5,3;dimension=1)
            job!(db,6,"deduplicate","ignored","ignored")
            for orphan in (-10,-2,1,1.5,4,6,10,"orphan text",UInt8[0x31])
                chunk!(db,orphan,-1,0,0,1)
                kernel!(db,orphan,300,"ignored dimension")
                evaluation!(db,orphan,1,1)
            end
            kernel!(db,2,300,"ignored wrong kind");chunk!(db,5,-1,0,0,1)
            parity(db;accepted=true)
        end
    end
    @testset "Prepared extension bindings reset between empty and populated jobs" begin
        for final_status in ("pending","done")
            fixture() do db
                job!(db,2,"v5",4,"1","done");chunk!(db,2,1,4,3)
                job!(db,3,"v5")
                job!(db,4,"v5",2,"1","done");chunk!(db,4,1,2,1)
                job!(db,5,"v5",1,"1",final_status)
                parity(db;accepted=final_status!="done")
            end
        end
        fixture(;direction=2) do db
            chunk!(db,1,1,2,1,1)
            parity(db;accepted=false)
            VS._closure_exec(db,"UPDATE chunks SET capped=0")
            parity(db;accepted=true)
        end
    end
    @testset "SQLite affinity and integer boundary keys" begin
        for id in (typemin(Int),typemax(Int)-1,typemax(Int))
            fixture(;kind="switching",id) do db
                evaluation!(db,id,-Inf,1);evaluation!(db,id,Inf,1)
                evaluation!(db,id,"nonnumeric direction",1)
                evaluation!(db,Float64(typemax(Int)),1,1)
                kernel!(db,Float64(typemax(Int)),300,"ignored orphan")
                parity(db;accepted=true)
            end
        end
        for combination in ("+1","01"," 1","1_0","0x1","1\n")
            fixture(db->parity(db);combination)
        end
        fixture(;kind="switching",direction=2,combination="02",status=UInt8[0x64,0x6f,0x6e,0x65]) do db
            kernel!(db,"01","1e0","0.0")
            evaluation!(db,1,"2.0",1)
            parity(db;accepted=true)
        end
    end
    @testset "Seeded mixed valid frontiers and isolated corruptions" begin
        rng=MersenneTwister(0x51eeda)
        for case in 1:48
            fixture(;kind="deduplicate") do db
                for id in 2:10
                    if rand(rng,Bool)
                        d=rand(rng,1:12);current=rand(rng,1:4)
                        job!(db,id,"switching",d,string(current))
                        prefix!(db,id,d;dimension=rand(rng,0:3))
                        for c in 1:current-1 evaluation!(db,id,d,c) end
                    else
                        lengths=rand(rng,1:8,rand(rng,0:12));d=sum(lengths)+1
                        job!(db,id,"v5",d,"1",isempty(lengths) ? "pending" : "done")
                        x=1
                        for n in lengths chunk!(db,id,x,x+n,d-1);x+=n end
                    end
                end
                if case%3==1
                    VS._closure_exec(db,"UPDATE jobs SET combination='invalid BigInt' WHERE id=6")
                elseif case%3==2
                    VS._closure_exec(db,"UPDATE jobs SET direction=direction+1 WHERE id=6")
                end
                parity(db;accepted=case%3==0)
            end
        end
    end
end
end
