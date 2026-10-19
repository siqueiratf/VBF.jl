module LiveStructureTests
using Test,VBF,SQLite,JSON3,SHA
include(joinpath(@__DIR__,"..","..","..","packages","VBFSearch","tools","analysis","live_structure_report.jl"))
const SQL=SQLite.DBInterface

@testset "Live structure measures Gold and reports exact LUT coverage" begin
    F=gold_apn(8);sha=bytes2hex(SHA.sha256(UInt8.(F.lut)))
    measured=LiveClosureStructure.measurements(UInt8.(F.lut),sha)
    @test measured[2:5]==(170,85,0,0)
    @test measured[6]==6
    @test measured[8:10]==(340,0,0)
    @test_throws ErrorException LiveClosureStructure.measurements(UInt8.(F.lut),repeat("0",64))
    mktempdir() do dir
        path=joinpath(dir,"classes.sqlite");source=SQLite.DB(path)
        SQL.execute(source,"CREATE TABLE classes(id INTEGER PRIMARY KEY,sha TEXT,origin TEXT,absent INTEGER)")
        SQL.execute(source,"INSERT INTO classes VALUES(1,?,'root',0)",(sha,))
        lut2=UInt8.(F.lut).⊻0x01;sha2=bytes2hex(SHA.sha256(lut2))
        SQL.execute(source,"INSERT INTO classes VALUES(2,?,'discovered',1)",(sha2,))
        SQL.execute(source,"INSERT INTO classes VALUES(3,'not-measured','discovered',1)")
        close(source)
        db=SQLite.DB()
        try
            SQL.execute(db,"CREATE TABLE features(sha TEXT PRIMARY KEY,bent INTEGER,c6 INTEGER,c4 INTEGER,c2 INTEGER,degree INTEGER,du INTEGER,two INTEGER,three INTEGER,four INTEGER,identity_ok INTEGER)")
            SQL.execute(db,"INSERT INTO features VALUES(?,?,?,?,?,?,?,?,?,?,?)",measured)
            SQL.execute(db,"ATTACH DATABASE ? AS current",("file:"*path*"?mode=ro",))
            template=Dict("reference"=>"fixture","references"=>Any[])
            LiveClosureStructure.publish(db,dir,dir,template)
            readreport()=JSON3.read(read(joinpath(dir,"structure.json"),String))
            first=readreport()
            @test first.coverage.classes_analyzed==1 && first.coverage.total_classes==3
            @test first.coverage.remaining==2 && !first.coverage.complete
            SQL.execute(db,"INSERT INTO features VALUES(?,?,?,?,?,?,?,?,?,?,?)",LiveClosureStructure.measurements(lut2,sha2))
            LiveClosureStructure.publish(db,dir,dir,template)
            second=readreport()
            @test second.coverage.classes_analyzed==2 && second.coverage.remaining==1
            @test sum(g.classes for g in second.groups)==2
            @test sum(r.classes for r in second.bent)==2
            @test second.identity_holds && second.live
        finally
            close(db)
        end
    end
end
end
