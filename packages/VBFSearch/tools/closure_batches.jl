"""Finish each SQLite statement before issuing savepoints or transaction control."""
_closure_batch_execute!(db,args...)=(foreach(_->nothing,DBInterface.execute(db,args...));nothing)

"""Group coordinator writes while preserving an atomic successful packet prefix.

Each application uses a savepoint because the frozen store joins an existing
transaction. A callback failure rolls back its own application; the enclosing
step commits earlier successful packets before propagating that failure.
No transaction is held while waiting for workers.
"""
function closure_apply_savepoint!(f, db)
    SQLite.intransaction(db) || return f()
    _closure_batch_execute!(db,"SAVEPOINT closure_controller_apply")
    try
        result=f()
        _closure_batch_execute!(db,"RELEASE closure_controller_apply")
        result
    catch
        _closure_batch_execute!(db,"ROLLBACK TO closure_controller_apply")
        _closure_batch_execute!(db,"RELEASE closure_controller_apply")
        rethrow()
    end
end

"""Commit one bounded coordinator step, including its successful failure prefix."""
function closure_coordinator_step!(f, db)
    SQLite.intransaction(db) && error("coordinator step requires its own transaction")
    _closure_batch_execute!(db,"BEGIN IMMEDIATE")
    local result
    try
        result=f()
    catch
        try
            _closure_batch_execute!(db,"COMMIT")
        catch
            SQLite.intransaction(db) && _closure_batch_execute!(db,"ROLLBACK")
        end
        rethrow()
    end
    try
        _closure_batch_execute!(db,"COMMIT")
    catch
        SQLite.intransaction(db) && _closure_batch_execute!(db,"ROLLBACK")
        rethrow()
    end
    result
end
