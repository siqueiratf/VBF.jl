module HistoricalReconciliationTests
using Test,VBF,SQLite,JSON3,SHA
include(joinpath(@__DIR__,"..","tools","datasets","reconcile_historical.jl"))
const H=HistoricalReconciliation
const SQL=SQLite.DBInterface
sha(lut)=bytes2hex(SHA.sha256(lut))
count(db,table)=only(H.rows(db,"SELECT COUNT(*) n FROM $table"))["n"]

@testset "Historical retirement requires positive graph evidence and preserves namespaces" begin
    mktempdir() do dir
        f=UInt8.(gold_apn(8).lut);g=f.⊻0x05;h=UInt8.(gold_apn(8,3).lut)
        history=joinpath(dir,"historical.sqlite");source=SQLite.DB(history)
        SQL.execute(source,"CREATE TABLE classes(class_id INTEGER PRIMARY KEY,sigma_hash TEXT,lut_sha256 TEXT,lut BLOB,source TEXT,source_member_idx INTEGER,source_run TEXT)")
        for (id,lut,sigma) in ((1,f,"s1"),(190455,h,"s2"))
            SQL.execute(source,"INSERT INTO classes VALUES(?,?,?,?,?,?,?)",(id,sigma,sha(lut),lut,"fixture",id,"original"))
        end
        close(source);original=read(history)
        active=joinpath(dir,"active.sqlite");db=H.initialize(history,active)
        try
            @test count(db,"classes")==count(db,"source_classes")==2
            @test_throws ErrorException H.initialize(history,history)
            @test_throws ErrorException H.initialize(history,active;expected_sha256="0"^64)
            proof=H.witness(UInt16[1<<i for i in 0:15],5)
            @test H.prove(f,g;cached=proof).status=="equivalent"
            old=only(H.rows(db,"SELECT * FROM source_classes WHERE class_id=1"))
            target=Dict("id"=>999,"sha"=>sha(g),"lut"=>g)
            bad=H.witness(UInt16[1<<i for i in 0:15],0)
            @test_throws ErrorException H.record!(db,old,target,bad,"recursive","fake",history,"cached",Dict())
            @test count(db,"classes")==2
            @test_throws ErrorException H.record!(db,old,merge(target,Dict("sha"=>"0"^64)),proof,"recursive","fake",history,"cached",Dict())

            freeze=joinpath(dir,"freeze");mkpath(freeze)
            roots=SQLite.DB(joinpath(freeze,"classes.sqlite"))
            SQL.execute(roots,"CREATE TABLE classes(class_id INTEGER PRIMARY KEY,lut_sha256 TEXT,lut BLOB,sigma_hash TEXT,observed_output INTEGER)")
            frozen_lut=f.⊻0x07
            SQL.execute(roots,"INSERT INTO classes VALUES(203,?,?,'s1',1)",(sha(frozen_lut),frozen_lut));close(roots)
            certs=SQLite.DB(joinpath(freeze,"comparisons.sqlite"))
            SQL.execute(certs,"CREATE TABLE historical(class_id INTEGER PRIMARY KEY,historical_class_id INTEGER,status TEXT,sigma_hash TEXT,witness_columns BLOB,witness_constant INTEGER)")
            SQL.execute(certs,"INSERT INTO historical VALUES(203,1,'equivalent_witness_replayed','s1',?,7)",(proof[2:33],));close(certs)
            write(joinpath(freeze,"comparison.json"),JSON3.write(Dict("complete"=>true,"all_positive_witnesses_replayed"=>true,"roots_sha256"=>"roots")))
            H.frozen!(db,freeze,"roots")
            @test count(db,"classes")==1 && count(db,"matches")==1
            @test only(H.rows(db,"SELECT target_class_id FROM matches"))["target_class_id"]==203
            H.frozen!(db,freeze,"roots")
            @test count(db,"matches")==1
            @test_throws ErrorException H.frozen!(db,freeze,"wrong roots")

            run=joinpath(dir,"run");mkpath(joinpath(run,"reports"));write(joinpath(run,"identity.toml"),"fixture = true\n")
            campaign=SQLite.DB(joinpath(run,"closure.sqlite"))
            SQL.execute(campaign,"CREATE TABLE parents(id INTEGER PRIMARY KEY,candidate_id TEXT UNIQUE,sigma TEXT,origin TEXT)")
            SQL.execute(campaign,"CREATE INDEX parents_sigma ON parents(sigma)")
            SQL.execute(campaign,"CREATE TABLE candidates(id TEXT PRIMARY KEY,lut_hex TEXT,sigma TEXT,apn INTEGER,degree INTEGER)")
            cache=SQLite.DB(joinpath(run,"reports","classes.sqlite"))
            SQL.execute(cache,"CREATE TABLE classes(id INTEGER PRIMARY KEY,sha TEXT,sigma TEXT,absent INTEGER)")
            for (id,lut,sigma) in ((101,g,"s1"),(102,h,"s2"))
                SQL.execute(campaign,"INSERT INTO parents VALUES(?,?,?,'discovered')",(id,sha(lut),sigma))
                SQL.execute(campaign,"INSERT INTO candidates VALUES(?,?,?,1,2)",(sha(lut),bytes2hex(lut),sigma))
                SQL.execute(cache,"INSERT INTO classes VALUES(?,?,?,1)",(id,sha(lut),sigma))
            end
            close(campaign);close(cache)
            campaign_bytes=read(joinpath(run,"closure.sqlite"))
            snapshot=Dict("parent_cutoff"=>102,"confirmed_absent_classes"=>2,"generated_utc"=>"fixture","reference"=>"fixture")
            identity=H.current!(db,run;snapshot,deadline=0)
            report=H.summary(db,snapshot,identity)
            @test report["recursive_verified_overlap"]==1
            @test report["recursive_unresolved_classes"]==1 && !report["recursive_comparison_complete"]
            @test report["active_remaining_classes"]==0 && report["recovered_classes"]==2
            @test report["recursive_maximum_possible_overlap"]==2
            H.current!(db,run;snapshot,pair_seconds=0.0)
            @test only(H.rows(db,"SELECT status FROM attempts"))["status"]=="budget"
            @test H.summary(db,snapshot,identity)["recursive_verified_overlap"]==1
            H.current!(db,run;snapshot,pair_seconds=5.0)
            @test H.summary(db,snapshot,identity)["recursive_unresolved_classes"]==1
            SQL.execute(db,"UPDATE attempts SET next_retry=0")
            identity=H.current!(db,run;snapshot,pair_seconds=5.0)
            report=H.summary(db,snapshot,identity)
            @test report["recursive_verified_overlap"]==2 && report["recursive_comparison_complete"]
            @test report["recursive_190454_prefix_overlap"]==1
            @test report["conditional_outside_catalog_estimate"]==2
            H.current!(db,run;snapshot,pair_seconds=5.0)
            @test count(db,"matches")==3
            @test Set(r["target_class_id"] for r in H.rows(db,"SELECT target_class_id FROM matches WHERE collection='recursive'"))==Set([101,102])
            freeze2=joinpath(dir,"second-freeze");cp(freeze,freeze2)
            roots=SQLite.DB(joinpath(freeze2,"classes.sqlite"))
            SQL.execute(roots,"UPDATE classes SET lut_sha256=?,lut=? WHERE class_id=203",(sha(g),g));close(roots)
            certs=SQLite.DB(joinpath(freeze2,"comparisons.sqlite"))
            SQL.execute(certs,"UPDATE historical SET witness_constant=5");close(certs)
            H.frozen!(db,freeze2,"roots")
            write(joinpath(run,"identity.toml"),"fixture = true\nnew_namespace = true\n")
            identity2=H.current!(db,run;snapshot,deadline=0)
            @test identity2!=identity
            @test H.summary(db,snapshot,identity2)["recursive_verified_overlap"]==2
            @test H.summary(db,snapshot,identity2)["recursive_comparison_complete"]
            @test count(db,"matches")==6
            @test read(history)==original
            @test read(joinpath(run,"closure.sqlite"))==campaign_bytes
        finally
            close(db)
        end
    end
end
end
