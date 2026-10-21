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
        @test [r["id"] for r in ContinuousSeedSearch.select_parents(db,100;parent_scope="discovered",excluded_parents=[2])]==[4]
        @test isempty(ContinuousSeedSearch.select_parents(db,100;parent_scope="all",excluded_parents=[1],only_origin="root"))
        @test [r["id"] for r in ContinuousSeedSearch.select_parents(db,100;parent_scope="all",only_origin="discovered")]==[2,4]

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
@testset "Invalid controller reporting and rolling policies fail before evidence writes" begin
    mktempdir() do directory
        config=Dict{String,Any}("run"=>joinpath(directory,"run"),"evidence"=>joinpath(directory,"evidence"),"concurrency"=>1)
        for extra in (Dict("report_interval_seconds"=>0.0),Dict("global_count_interval_seconds"=>-1.0),
                Dict("rolling_windows"=>1),Dict("max_windows"=>0),Dict("max_apply_per_step"=>0),
                Dict("reservation_refill_batch"=>0),Dict("reservation_horizon"=>4,"reservation_refill_batch"=>5))
            @test_throws ArgumentError ContinuousSeedSearch.run(merge(config,extra))
            @test !ispath(config["evidence"])
        end
    end
end

@testset "Bound reservation arrays preserve indexed eligibility and query reuse" begin
    db=SQLite.DB();cache=FP.DiscoveryStore.StatementCache(db)
    try
        FP._closure_create_schema(db)
        for parent in 1:2
            FP._closure_exec(db,"INSERT INTO parents(id,candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,'root','fixture','fixture')",(parent,string(parent),"sigma"))
        end
        for (id,parent,kind,status,session) in ((1,1,"prepare_v5","pending",0),(2,1,"switching","paused",0),
                (3,1,"v5","running",8),(4,2,"prepare_v5","pending",0),(5,2,"switching","done",0),
                (10,1,"deduplicate","pending",0),(11,2,"deduplicate","paused",8),(12,1,"deduplicate","paused",7),
                (13,1,"deduplicate","running",0),(14,2,"deduplicate","done",0),(15,2,"deduplicate","paused",8))
            FP._closure_exec(db,"INSERT INTO jobs(id,parent_id,kind,job_key,payload,status,last_session) VALUES(?,?,?,?,?,?,?)",(id,parent,kind,string(id),"",status,session))
        end
        FP._closure_exec(db,"CREATE INDEX jobs_pending_ea ON jobs(id,last_session) WHERE kind='deduplicate' AND status IN ('pending','paused')")
        query(sql,args=())=FP.DiscoveryStore.query(cache,sql,args)
        ids_json=ContinuousSeedSearch._reservation_ids_json
        @test only(query("SELECT json_valid(?) n",(ids_json(Set([10,12])),)))["n"]==1
        for indexed in (false,true),excluded in (Int[],[10],[10,12],[1,2,4],[999]),retries in (Int[],[11],[15],[11,15]),limit in (1,3)
            sql=ContinuousSeedSearch._reservation_ea_sql(indexed)
            actual=query(sql,(8,ids_json(retries),ids_json(excluded),limit))
            excluded_sql=isempty(excluded) ? "0" : join(excluded,",")
            retries_sql=isempty(retries) ? "0" : join(retries,",")
            index=indexed ? " INDEXED BY jobs_pending_ea" : ""
            expected=FP._closure_rows(db,"SELECT * FROM jobs$index WHERE kind='deduplicate' AND status IN ('pending','paused') AND (last_session!=? OR id IN ($retries_sql)) AND id NOT IN ($excluded_sql) ORDER BY id LIMIT ?",(8,limit))
            @test actual==expected
        end
        for excluded in (Int[],[1],[1,2],[2,4],[999]),limit in (1,3)
            actual=query(ContinuousSeedSearch._reservation_construction_sql("1,2"),(ids_json(excluded),limit))
            excluded_sql=isempty(excluded) ? "0" : join(excluded,",")
            expected=FP._closure_rows(db,"SELECT * FROM jobs WHERE parent_id IN (1,2) AND kind IN ('prepare_v5','v5','switching') AND status IN ('pending','paused') AND id NOT IN ($excluded_sql) ORDER BY parent_id,id LIMIT ?",(limit,))
            @test actual==expected
        end
        @test length(cache.statements)==4 # JSON check, two EA plans and one construction plan.
        plan=query("EXPLAIN QUERY PLAN "*ContinuousSeedSearch._reservation_ea_sql(true),(8,"[]","[]",3))
        @test any(occursin("jobs_pending_ea",string(row)) for row in plan)
    finally
        FP.DiscoveryStore.close_statements!(cache);close(db)
    end
end

end
