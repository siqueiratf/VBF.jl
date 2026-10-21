module StatementExecutionTests
using Test,VBFSearch,SQLite,DBInterface
const S=VBFSearch.DiscoveryStore

@testset "Write execution drains returning rows and preserves statement recovery" begin
    db=SQLite.DB();cache=S.StatementCache(db)
    try
        S.execute!(cache,"CREATE TABLE items(id INTEGER PRIMARY KEY,value TEXT NOT NULL UNIQUE)")
        S.execute!(cache,"INSERT INTO items(value) VALUES(?),(?),(?) RETURNING id",("first","second","third"))
        @test [r["value"] for r in S.query(cache,"SELECT value FROM items ORDER BY id")]==["first","second","third"]
        visited=Int[]
        SQLite.register(db,x->(push!(visited,Int(x));x);name="visit",nargs=1,isdeterm=false)
        S.execute!(cache,"SELECT visit(id) FROM items ORDER BY id")
        @test visited==[1,2,3]
        S.execute!(cache,"BEGIN IMMEDIATE")
        S.execute!(cache,"UPDATE items SET value=value||'!' RETURNING id")
        S.execute!(cache,"COMMIT")
        @test !SQLite.intransaction(db)
        @test length(S.query(cache,"SELECT * FROM items"))==3
        S.execute!(cache,"CREATE TRIGGER reject_insert BEFORE INSERT ON items WHEN NEW.value='reject' BEGIN SELECT RAISE(ABORT,'late insert failure'); END")
        sql="INSERT INTO items(value) VALUES(?),(?) RETURNING id"
        @test_throws SQLite.SQLiteException S.execute!(cache,sql,("prefix","reject"))
        @test isempty(S.query(cache,"SELECT * FROM items WHERE value='prefix'"))
        S.execute!(cache,sql,("fourth","fifth"))
        @test length(S.query(cache,"SELECT * FROM items"))==5
        fail=Ref(true)
        SQLite.register(db,x->(fail[] && x==3 && error("late row failure");push!(visited,Int(x));x);
            name="visit_or_fail",nargs=1,isdeterm=false)
        empty!(visited)
        @test_throws SQLite.SQLiteException S.execute!(cache,"SELECT visit_or_fail(id) FROM items ORDER BY id")
        @test visited==[1,2]
        fail[]=false;empty!(visited)
        S.execute!(cache,"SELECT visit_or_fail(id) FROM items ORDER BY id")
        @test visited==[1,2,3,4,5]
        @test_throws SQLite.SQLiteException S.execute!(cache,"INSERT INTO items(value) VALUES(?)",("fourth",))
        S.execute!(cache,"INSERT INTO items(value) VALUES(?)",("sixth",))
        @test length(S.query(cache,"SELECT * FROM items"))==6
        S.execute!(db,"PRAGMA journal_mode=MEMORY")
        @test only(S.query(cache,"PRAGMA journal_mode"))["journal_mode"]=="memory"
        @test_throws SQLite.SQLiteException S.execute!(db,"INSERT INTO missing_table VALUES(1)")
        S.execute!(db,"INSERT INTO items(value) VALUES(?) RETURNING id",("standalone",))
        @test only(S.query(cache,"SELECT COUNT(*) AS n FROM items"))["n"]==7
    finally
        S.close_statements!(cache);close(db)
    end
end

@testset "FIFO cache admits late hot queries after setup pollution" begin
    db=SQLite.DB();cache=S.StatementCache(db;limit=2)
    try
        first_sql="SELECT 1 AS first_value";second_sql="SELECT 2 AS second_value"
        S.query(cache,first_sql);first_statement=cache.statements[first_sql]
        S.query(cache,second_sql);second_statement=cache.statements[second_sql]
        # FIFO hits preserve insertion order; fresh hot work can displace setup.
        S.query(cache,first_sql)
        hot_sql="SELECT ? AS hot_value"
        @test only(S.query(cache,hot_sql,(3,)))["hot_value"]==3
        hot_statement=cache.statements[hot_sql]
        @test !haskey(cache.statements,first_sql)
        @test !SQLite.isready(first_statement)
        @test SQLite.isready(second_statement)
        for value in 4:12
            @test only(S.query(cache,hot_sql,(value,)))["hot_value"]==value
            @test cache.statements[hot_sql]===hot_statement
        end
        @test isempty(hot_statement.params)
        before=S.statement_cache_stats(cache)
        order=copy(cache.order)
        @test_throws SQLite.SQLiteException S.query(cache,"SELECT value FROM absent_table")
        @test cache.order==order
        @test cache.statements[hot_sql]===hot_statement
        @test SQLite.isready(hot_statement) && SQLite.isready(second_statement)
        after=S.statement_cache_stats(cache)
        @test after["misses"]==before["misses"]+1
        @test after["prepares"]==before["prepares"]
        @test after["evictions"]==1
        @test after["entries"]==after["peak_entries"]==after["limit"]==2
        @test after["hits"]==10
        @test after["temporary_statements"]==after["active"]==0
        S.close_statements!(cache)
        @test !SQLite.isready(hot_statement) && !SQLite.isready(second_statement)
        closed=S.statement_cache_stats(cache)
        @test closed["entries"]==closed["active"]==0
        @test closed["prepares"]==after["prepares"] && closed["peak_entries"]==2
        @test isempty(cache.order)
    finally
        S.close_statements!(cache);close(db)
    end
end

@testset "Active statements stay pinned during recursive execution" begin
    db=SQLite.DB();cache=S.StatementCache(db;limit=2)
    try
        outer_sql="SELECT ? AS outer_value";inactive_sql="SELECT 2 AS inactive_value"
        S.query(cache,outer_sql,("initial",));S.query(cache,inactive_sql)
        inactive=cache.statements[inactive_sql]
        S._statement(cache,outer_sql) do outer
            SQLite.bind!(outer,("outer binding",))
            @test length(cache.active)==1
            @test_throws ErrorException S.close_statements!(cache)
            @test only(S.query(cache,"SELECT 3 AS new_value"))["new_value"]==3
            @test !SQLite.isready(inactive)
            @test SQLite.isready(outer) && cache.statements[outer_sql]===outer
            @test outer.params[1]=="outer binding"
            # The same SQL cannot reset or clear the active statement's bindings.
            @test only(S.query(cache,outer_sql,("nested binding",)))["outer_value"]=="nested binding"
            @test outer.params[1]=="outer binding"
            S._statement(cache,"SELECT 3 AS new_value") do inner
                @test length(cache.active)==2
                @test only(S.query(cache,"SELECT 4 AS overflow_value"))["overflow_value"]==4
                @test !haskey(cache.statements,"SELECT 4 AS overflow_value")
                @test SQLite.isready(inner) && SQLite.isready(outer)
                @test length(cache.statements)==2
            end
            @test length(cache.active)==1
        end
        @test isempty(cache.active)
        @test all(isempty(stmt.params) for stmt in values(cache.statements))
        @test S.statement_cache_stats(cache)["temporary_statements"]==2
        @test S.statement_cache_stats(cache)["evictions"]==1
        @test_throws ErrorException S._statement(cache,outer_sql) do statement
            SQLite.bind!(statement,("failed callback",));error("callback failure")
        end
        @test isempty(cache.active)
        @test isempty(cache.statements[outer_sql].params)
        @test only(S.query(cache,outer_sql,("recovered",)))["outer_value"]=="recovered"
    finally
        S.close_statements!(cache);close(db)
    end
end

@testset "Zero cache capacity and execution errors retain connection recovery" begin
    db=SQLite.DB();cache=S.StatementCache(db;limit=0)
    try
        @test_throws ArgumentError S.StatementCache(db;limit=-1)
        S.execute!(cache,"CREATE TABLE bounded_items(value TEXT UNIQUE NOT NULL)")
        insert="INSERT INTO bounded_items VALUES(?)"
        S.execute!(cache,insert,("first",))
        @test_throws SQLite.SQLiteException S.execute!(cache,insert,("first",))
        S.execute!(cache,insert,("second",))
        @test only(S.query(cache,"SELECT COUNT(*) AS n FROM bounded_items"))["n"]==2
        temporary=Ref{SQLite.Stmt}()
        S._statement(cache,"SELECT ? AS value") do outer
            temporary[]=outer
            SQLite.bind!(outer,("outer",))
            @test only(S.query(cache,"SELECT ? AS value",("inner",)))["value"]=="inner"
            @test outer.params[1]=="outer"
        end
        @test !SQLite.isready(temporary[])
        @test_throws ErrorException S._statement(cache,"SELECT ? AS value") do statement
            temporary[]=statement
            SQLite.bind!(statement,("failed",));error("temporary callback failure")
        end
        @test !SQLite.isready(temporary[])
        @test isempty(cache.statements) && isempty(cache.active) && isempty(cache.order)
        stats=S.statement_cache_stats(cache)
        @test stats["entries"]==stats["peak_entries"]==stats["limit"]==stats["hits"]==stats["evictions"]==0
        @test stats["prepares"]==stats["misses"]==stats["temporary_statements"]==8
    finally
        S.close_statements!(cache);close(db)
    end
end

@testset "A stepping SQL callback can query the same SQL recursively" begin
    db=SQLite.DB();cache=S.StatementCache(db;limit=1)
    sql="SELECT recursive_value(?) AS value"
    visited=Int[]
    try
        SQLite.register(db,x->begin
            value=Int(x);push!(visited,value)
            value==0 ? 0 : only(S.query(cache,sql,(value-1,)))["value"]+1
        end;name="recursive_value",nargs=1,isdeterm=false)
        @test only(S.query(cache,sql,(4,)))["value"]==4
        @test visited==[4,3,2,1,0]
        @test length(cache.statements)==1 && isempty(cache.active)
        prepared=cache.statements[sql]
        @test SQLite.isready(prepared) && isempty(prepared.params)
        empty!(visited)
        @test only(S.query(cache,sql,(2,)))["value"]==2
        @test visited==[2,1,0]
        @test cache.statements[sql]===prepared
        stats=S.statement_cache_stats(cache)
        @test stats["hits"]==1 && stats["evictions"]==0
        @test stats["prepares"]==7 && stats["temporary_statements"]==6
    finally
        S.close_statements!(cache);close(db)
    end
end
end
