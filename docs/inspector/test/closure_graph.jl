using Test, SQLite, JSON3, SHA, TOML, HTTP
include(joinpath(@__DIR__,"..","closure_graph.jl"))
isdefined(Main,:APNClosureMonitor) || include(joinpath(@__DIR__,"..","closure_monitor.jl"))

@testset "Cached graph preserves class edges and never mutates the search ledger" begin
    mktempdir() do directory
        run=joinpath(directory,"run");mkpath(run)
        file=joinpath(run,"closure.sqlite");db=SQLite.DB(file);sql=SQLite.DBInterface
        sql.execute(db,"CREATE TABLE parents(id INTEGER PRIMARY KEY,candidate_id TEXT,origin TEXT,source TEXT,sigma TEXT)")
        sql.execute(db,"CREATE TABLE candidates(id TEXT PRIMARY KEY,class_id INTEGER)")
        sql.execute(db,"CREATE TABLE paths(id INTEGER PRIMARY KEY,parent_id INTEGER,child_id TEXT,method TEXT)")
        for i in 1:6
            sql.execute(db,"INSERT INTO parents VALUES(?,?,?,?,?)",(i,"lut$i",i in (1,5,6) ? "root" : "discovered",i==1 ? "published:1" : "","sigma$i"))
            sql.execute(db,"INSERT INTO candidates VALUES(?,?)",("lut$i",i))
        end
        sql.execute(db,"INSERT INTO candidates VALUES('unresolved',NULL)")
        for (id,u,v,method) in [(1,1,"lut2","v5"),(2,1,"lut2","v5"),(3,1,"lut2","switching"),
                (4,2,"lut3","v5"),(5,3,"lut4","switching"),(6,4,"lut2","v5"),
                (7,1,"lut1","v5"),(8,1,"unresolved","switching")]
            sql.execute(db,"INSERT INTO paths VALUES(?,?,?,?)",(id,u,v,method))
        end
        close(db)
        write(joinpath(run,"progress.toml"),"completed_parents = 12\n")
        before=bytes2hex(open(SHA.sha256,file));output=joinpath(run,"graph")
        result=APNClosureGraph.build(run,output)
        @test result["nodes"]==6 && result["seeds"]==3
        @test result["v5_edges"]==3 && result["switching_edges"]==2
        @test result["directed_pairs"]==4 && result["pending_observations"]==1
        @test result["components"]==3 && result["largest_component"]==4
        @test result["largest_strong_component"]==3
        @test bytes2hex(open(SHA.sha256,file))==before
        current=JSON3.read(read(joinpath(output,"current.json"),String))
        built_at=stat(joinpath(output,"current.json")).mtime
        @test !APNClosureGraph.refresh_due(output,511;now_seconds=built_at+601)
        @test APNClosureGraph.refresh_due(output,512;now_seconds=built_at+600)
        @test !APNClosureGraph.refresh_due(output,512;now_seconds=built_at+599)
        @test APNClosureGraph.refresh_due(joinpath(directory,"absent"),12)
        snapshot=joinpath(output,current.version)
        xy=collect(reinterpret(Float32,read(joinpath(snapshot,"positions.bin"))))
        @test length(xy)==12 && all(isfinite,xy)
        edges=collect(reinterpret(UInt32,read(joinpath(snapshot,"edges.bin"))))
        @test length(edges)==10
        @test count(x->x&0x80000000!=0,edges[2:2:end])==2
        @test count(x->x&0x40000000!=0,edges[2:2:end])==2
        metadata=JSON3.read(read(joinpath(snapshot,"nodes-0.json"),String))
        @test metadata[1].v5_returns==1
        @test metadata[2].incoming==2 && metadata[2].outgoing==1
        mkpath(joinpath(directory,"seed_count"))
        write(joinpath(directory,"campaign.toml"),"[roots]\n")
        monitor=APNClosureMonitor.Monitor(directory;run)
        call(path)=APNClosureMonitor.handle(monitor,HTTP.Request("GET",path))
        @test call("/graph").status==200
        @test call("/graph.js").status==200
        @test call("/api/graph").status==200
        @test call("/graph-data/$(current.version)/positions.bin").body==read(joinpath(snapshot,"positions.bin"))
        @test call("/graph-data/$(current.version)/nodes-0.json").status==200
        @test call("/graph-data/$(current.version)/%2e%2e/closure.sqlite").status==400
        @test call("/graph-data/$(current.version)/current.json").status==400
        @test call("/graph-data/20260101T000000-0-0/positions.bin").status==404
        @test occursin("Explore graph",String(call("/").body))
        outside=joinpath(directory,"private.bin");write(outside,"private")
        rm(joinpath(snapshot,"flags.bin"));symlink(outside,joinpath(snapshot,"flags.bin"))
        @test call("/graph-data/$(current.version)/flags.bin").status==400
        @test bytes2hex(open(SHA.sha256,file))==before
        previous=read(joinpath(output,"current.json"),String)
        db=SQLite.DB(file);sql.execute(db,"UPDATE parents SET id=7 WHERE id=6");close(db)
        @test_throws ErrorException APNClosureGraph.build(run,output)
        @test read(joinpath(output,"current.json"),String)==previous
    end
end
