using Test, SQLite, DBInterface, TOML, JSON3, VBF
include(joinpath(@__DIR__,"../tools/analysis/v5_redundancy.jl"))
using .V5RedundancyPilot

@testset "Read-only stratified V5 redundancy pilot" begin
    mktempdir() do directory
        path=joinpath(directory,"closure.sqlite")
        db=SQLite.DB(path)
        DBInterface.execute(db,"CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT)")
        DBInterface.execute(db,"INSERT INTO metadata VALUES('identity','test=true')")
        DBInterface.execute(db,"CREATE TABLE parents(id INTEGER PRIMARY KEY,origin TEXT)")
        DBInterface.execute(db,"CREATE TABLE jobs(id INTEGER PRIMARY KEY,parent_id INTEGER,kind TEXT,payload TEXT,status TEXT,result TEXT)")
        for parent in 1:8
            origin=parent<=4 ? "root" : "discovered"
            b5=isodd(parent) ? 28 : 30
            DBInterface.execute(db,"INSERT INTO parents VALUES(?,?)",(parent,origin))
            for k in 1:3
                id=3(parent-1)+k
                payload="b5 = $b5\nneed = $(52-b5)\nforms = [1,2,4,8,$(16k)]\n"
                DBInterface.execute(db,"INSERT INTO jobs VALUES(?,?,'v5',?,'done','capped=false')",(id,parent,payload))
            end
            DBInterface.execute(db,"INSERT INTO jobs VALUES(?,?,'prepare_v5','','pending','')",(100+parent,parent))
        end
        close(db)
        before=read(path)
        a=V5RedundancyPilot.sample_jobs(path;per_stratum=2)
        b=V5RedundancyPilot.sample_jobs(path;per_stratum=2)
        @test a.total==24
        @test length(a.strata)==4
        @test all(s->s["population"]==6 && s["sampled"]==2,a.strata)
        @test length(a.selected)==8
        @test a.selected==b.selected
        @test a.roster_sha256==b.roster_sha256
        @test length(a.roster_sha256)==64
        @test before==read(path)
        siblings=V5RedundancyPilot.sibling_jobs(path,a;parents_per_stratum=1,max_spaces_per_parent=2)
        @test length(siblings.selected)==8
        @test length(unique(r["parent_id"] for r in siblings.selected))==4
        @test siblings.sibling_population_jobs==12
        @test length(siblings.sibling_roster_sha256)==64
        @test all(s->s["sampled"]==2 && length(s["sampled_parent_ids"])==1,siblings.strata)
        @test before==read(path)
        # Digest binds jobs that were not selected as well as selected jobs.
        selected_ids=Set(r["job_id"] for r in a.selected)
        omitted=first(filter(x->x∉selected_ids,1:24))
        db=SQLite.DB(path)
        DBInterface.execute(db,"UPDATE jobs SET result='capped=true' WHERE id=?",(omitted,))
        close(db)
        c=V5RedundancyPilot.sample_jobs(path;per_stratum=2)
        @test c.selected==a.selected
        @test c.roster_sha256!=a.roster_sha256
        # Exercise the whole bounded report path with an actual b5=30 space,
        # including heterogeneous implementation metadata and exact reuse.
        db=SQLite.DB(path)
        payload="b5 = 30\nneed = 22\nforms = [134658561,34016355,17372590,10987437,4393092]\n"
        DBInterface.execute(db,"UPDATE jobs SET payload=? WHERE kind='v5'",(payload,))
        close(db)
        before_report=read(path)
        report=redirect_stdout(devnull) do
            V5RedundancyPilot.main(["--database",path,"--output",joinpath(directory,"evidence"),
                "--sample-per-stratum","2","--max-pairs","0"])
        end
        @test report["comparison_pairs_attempted"]==0
        @test report["sample_reused_jobs_proved"]==3
        @test report["implementation"]["source_files_unchanged_during_analysis"] isa Bool
        @test length(report["implementation"]["analysis_tool_sha256"])==64
        @test JSON3.read(read(joinpath(directory,"evidence/report.json"),String))["sampled_v5_jobs"]==4
        @test before_report==read(path)
    end
    config=V5RedundancyPilot.configuration(["--database","x","--output","y","--max-pairs","0"])
    @test config.max_pairs==0
    @test_throws ArgumentError V5RedundancyPilot.configuration(["--database","x"])
    @test_throws ArgumentError V5RedundancyPilot.configuration(["--database","x","--output","y","--typo","5"])
    records=[Dict{String,Any}("job_id"=>i,"parent_id"=>i,"origin"=>(i==3 ? "discovered" : "root"),
        "invariant_key"=>"same","exact_key"=>(i<=2 ? "duplicate" : string(i))) for i in 1:4]
    selected=V5RedundancyPilot.candidate_pairs(records,2)
    @test length(selected)==2
    @test all(p->3∈p,selected)
    @test (1,2)∉V5RedundancyPilot.candidate_pairs(records,10)
    summary=V5RedundancyPilot.collision_summary(records,"invariant_key")
    @test summary["maximum_possible_reused_jobs"]==3
    @test occursin("do not prove",summary["meaning"])
end
