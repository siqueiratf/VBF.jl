module ClosureParentScopeTests
using Test,SQLite,VBFSearch
include(joinpath(@__DIR__,"..","tools","closure_continuous.jl"))
const FP=VBFSearch

@testset "Recursive-only selection excludes even unfinished published roots" begin
    db=SQLite.DB()
    try
        FP._closure_create_schema(db)
        for (id,origin,status) in ((1,"root","pending"),(2,"discovered","paused"),(3,"root","done"),(4,"discovered","pending"))
            FP._closure_exec(db,"INSERT INTO parents(id,candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,?,?,'fixture')",(id,string(id),"sigma",origin,"fixture"))
            FP._closure_exec(db,"INSERT INTO jobs(parent_id,kind,job_key,payload,status) VALUES(?,'prepare_v5',?,'',?)",(id,string(id),status))
        end
        selected(scope,limit=100)=ContinuousSeedSearch.select_parents(db,limit;parent_scope=scope)
        ids(scope,limit=100)=[r["id"] for r in selected(scope,limit)]
        @test ids("all")==[1]
        @test ids("discovered")==[2,4]
        @test ids("discovered",1)==[2]
        @test all(r->r["origin"]=="discovered",selected("discovered"))
        FP._closure_exec(db,"UPDATE jobs SET status='done' WHERE parent_id=2")
        @test ids("discovered")==[4]
        FP._closure_exec(db,"UPDATE jobs SET status='done' WHERE parent_id=4")
        @test isempty(selected("discovered"))
        @test ids("all")==[1]
        idle=ContinuousSeedSearch.select_parents(db,100;parent_scope="discovered",fallback=true)
        @test only(idle)["id"]==1 && only(idle)["selection_kind"]=="idle"
        FP._closure_exec(db,"INSERT INTO jobs(parent_id,kind,job_key,payload,status) VALUES(3,'deduplicate','ea-fixture','','paused')")
        ea=ContinuousSeedSearch.select_parents(db,100;parent_scope="discovered",fallback=true)
        @test only(ea)["id"]==3 && only(ea)["origin"]=="root"
        @test only(ea)["selection_kind"]=="equivalence"
        @test isempty(selected("discovered"))
        @test ids("all")==[1]
        @test_throws ArgumentError selected("invalid")
        @test_throws ArgumentError selected("discovered",0)
    finally
        close(db)
    end
end
end
