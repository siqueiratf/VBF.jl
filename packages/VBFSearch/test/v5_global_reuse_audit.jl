using Test,SQLite,DBInterface,JSON3,VBF,SHA
include(joinpath(@__DIR__,"../tools/analysis/v5_global_reuse_audit.jl"))
using .V5GlobalReuseAudit
@testset "Global prepared V5 extraction and invariant bounds" begin
    mktempdir() do d
        source=joinpath(d,"source.sqlite");out=joinpath(d,"audit")
        db=SQLite.DB(source)
        DBInterface.execute(db,"CREATE TABLE metadata(key TEXT,value TEXT)")
        DBInterface.execute(db,"INSERT INTO metadata VALUES('identity','test=true')")
        DBInterface.execute(db,"CREATE TABLE parents(id INTEGER PRIMARY KEY,origin TEXT)")
        DBInterface.execute(db,"CREATE TABLE jobs(id INTEGER PRIMARY KEY,parent_id INTEGER,kind TEXT,payload TEXT,status TEXT,result TEXT)")
        R=UInt32[134658561,34016355,17372590,10987437,4393092]
        G=VBF.QuadraticExtensions.geometry(8)
        S=VBF.transform_quadratic_space(G,R,UInt16[2,1,4,8,16,32,64,128])
        for i in 1:3
            DBInterface.execute(db,"INSERT INTO parents VALUES(?,?)",(i,i==3 ? "discovered" : "root"))
            forms=i==3 ? S : R
            payload="b5=30\nneed=22\nforms=[$(join(Int.(forms),','))]\n"
            DBInterface.execute(db,"INSERT INTO jobs VALUES(?,?,'v5',?,'done','total_x=10\nnext_x=11\ncapped=false\nlinear_system_candidates=100')",(i,i,payload))
        end
        DBInterface.execute(db,"INSERT INTO jobs VALUES(4,1,'prepare_v5','','pending','')")
        close(db);before=read(source)
        r=redirect_stdout(devnull) do;V5GlobalReuseAudit.extract(source,out);end
        @test before==read(source)
        @test r["prepared_jobs"]==3
        @test r["exact_spaces"]==2
        @test r["exact_repeated_jobs"]==1
        @test r["spaces_with_verified_completion_cursor"]==2
        @test r["reusable_jobs_lower_bound"]==1
        @test !r["fingerprint_complete"]
        plan_db=V5GlobalReuseAudit.openindex(out;readonly=true)
        plan=[String(x.detail) for x in DBInterface.execute(plan_db,
            "EXPLAIN QUERY PLAN SELECT space_id,forms FROM spaces WHERE fingerprint IS NULL ORDER BY space_id LIMIT 256")]
        close(plan_db)
        @test !any(x->occursin("TEMP B-TREE",x),plan)
        @test any(x->occursin("COVERING INDEX",x),plan)
        @test_throws ErrorException V5GlobalReuseAudit.extract(source,out)
        indexed=redirect_stdout(devnull) do;V5GlobalReuseAudit.fingerprint_index(out;max_spaces=1,batch_size=1);end
        @test indexed["fingerprinted_spaces"]==1
        @test !indexed["fingerprint_complete"]
        complete=redirect_stdout(devnull) do;V5GlobalReuseAudit.fingerprint_index(out);end
        @test complete["fingerprint_complete"]
        @test complete["necessary_invariant_buckets"]==1
        @test complete["distinct_orbits_lower_bound"]==1
        @test complete["distinct_orbits_upper_bound"]==2
        @test complete["reusable_jobs_lower_bound"]==1
        @test complete["reusable_jobs_upper_bound"]==2
        @test complete["last_index_pass"]["implementation"]["sources_unchanged_during_index"]
        @test complete["last_index_pass"]["max_spaces"]=="unbounded"
        @test_throws ErrorException V5GlobalReuseAudit.fingerprint_index(out;max_rounds=1)
        @test before==read(source)
        @test V5GlobalReuseAudit.decodeforms(V5GlobalReuseAudit.formsblob(R))==R
    end
end
