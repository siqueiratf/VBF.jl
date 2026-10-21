"""Finish each SQLite statement before issuing savepoints or transaction control."""
function _closure_batch_execute!(db,sql,args=())
    statement=SQLite.Stmt(db,sql;register=false)
    try
        DBInterface.execute(rows->foreach(_->nothing,rows),statement,args)
        nothing
    finally
        DBInterface.close!(statement)
    end
end

"""Group coordinator writes while preserving an atomic successful packet prefix.

Each application uses a savepoint because the frozen store joins an existing
transaction. A callback failure rolls back its own application; the enclosing
step commits earlier successful packets before propagating that failure.
No transaction is held while waiting for workers. `execute_control` may reuse
connection-owned prepared statements; the standalone default closes each one.
"""
function closure_apply_savepoint!(f, db;execute_control=sql->_closure_batch_execute!(db,sql))
    SQLite.intransaction(db) || return f()
    execute_control("SAVEPOINT closure_controller_apply")
    try
        result=f()
        execute_control("RELEASE closure_controller_apply")
        result
    catch
        execute_control("ROLLBACK TO closure_controller_apply")
        execute_control("RELEASE closure_controller_apply")
        rethrow()
    end
end

"""Commit one bounded coordinator step, including its successful failure prefix."""
function closure_coordinator_step!(f, db;execute_control=sql->_closure_batch_execute!(db,sql))
    SQLite.intransaction(db) && error("coordinator step requires its own transaction")
    execute_control("BEGIN IMMEDIATE")
    local result
    try
        result=f()
    catch
        try
            execute_control("COMMIT")
        catch
            SQLite.intransaction(db) && execute_control("ROLLBACK")
        end
        rethrow()
    end
    try
        execute_control("COMMIT")
    catch
        SQLite.intransaction(db) && execute_control("ROLLBACK")
        rethrow()
    end
    result
end
