module ClosureBatchTests
using Test,SQLite,DBInterface
include(joinpath(@__DIR__,"..","tools","closure_batches.jl"))
include(joinpath(@__DIR__,"..","tools","closure_refill.jl"))
rows(db)=Int[r.id for r in DBInterface.execute(db,"SELECT id FROM results ORDER BY id")]

@testset "Coordinator batching commits a verified prefix and isolates failed packets" begin
    mktempdir() do directory
        path=joinpath(directory,"store.sqlite");db=SQLite.DB(path)
        _closure_batch_execute!(db,"PRAGMA journal_mode=WAL")
        _closure_batch_execute!(db,"PRAGMA synchronous=FULL")
        _closure_batch_execute!(db,"CREATE TABLE results(id INTEGER PRIMARY KEY)")
        reader=SQLite.DB(path)
        closure_coordinator_step!(db) do
            for id in 1:3
                closure_apply_savepoint!(db) do
                    _closure_batch_execute!(db,"INSERT INTO results VALUES(?)",(id,))
                end
            end
            @test isempty(rows(reader))
        end
        @test rows(reader)==[1,2,3]
        @test !SQLite.intransaction(db)
        @test_throws ErrorException closure_coordinator_step!(db) do
            closure_apply_savepoint!(db) do
                _closure_batch_execute!(db,"INSERT INTO results VALUES(4)")
            end
            closure_apply_savepoint!(db) do
                _closure_batch_execute!(db,"INSERT INTO results VALUES(5)")
                error("synthetic packet failure after a partial write")
            end
        end
        @test rows(reader)==[1,2,3,4]
        @test !SQLite.intransaction(db)
        @test only(Int(r[1]) for r in DBInterface.execute(db,"PRAGMA synchronous"))==2
        close(reader);close(db)
    end
end

@testset "A failed durable commit rolls back the entire uncommitted batch" begin
    db=SQLite.DB()
    _closure_batch_execute!(db,"PRAGMA foreign_keys=ON")
    _closure_batch_execute!(db,"CREATE TABLE results(id INTEGER PRIMARY KEY)")
    _closure_batch_execute!(db,"CREATE TABLE children(parent INTEGER REFERENCES results(id) DEFERRABLE INITIALLY DEFERRED)")
    @test_throws SQLite.SQLiteException closure_coordinator_step!(db) do
        closure_apply_savepoint!(db) do
            _closure_batch_execute!(db,"INSERT INTO results VALUES(1)")
            _closure_batch_execute!(db,"INSERT INTO children VALUES(2)")
        end
    end
    @test isempty(rows(db)) && !SQLite.intransaction(db)
    close(db)
end

@testset "The batched refill pool retains FIFO order and commits before reporting" begin
    db=SQLite.DB();_closure_batch_execute!(db,"CREATE TABLE results(id INTEGER PRIMARY KEY)")
    queue=collect(1:48);ticks=Ref(0);steps=Ref(0)
    reserve=(limit,excluded)->begin
        n=min(limit,length(queue));selected=queue[1:n];deleteat!(queue,1:n);selected
    end
    prepare=(item,ticket,slot)->item
    compute=(item,slot,stop)->begin
        item%3==0 && sleep(.002)
        item
    end
    apply=(item,value,seconds,meta)->closure_apply_savepoint!(db) do
        @test item==value==meta.ticket
        _closure_batch_execute!(db,"INSERT INTO results VALUES(?)",(value,))
    end
    step=f->begin
        steps[]+=1
        closure_coordinator_step!(f,db)
    end
    report=()->begin
        @test !SQLite.intransaction(db)
        ticks[]+=1
    end
    result=run_refill_pool!(reserve,prepare,compute,apply;concurrency=4,max_pending=16,
        coordinator_step=step,on_tick=report)
    @test result.dispatched==result.applied==48
    @test rows(db)==collect(1:48)
    @test ticks[]>0 && steps[]==ticks[]+2
    close(db)
end
end
