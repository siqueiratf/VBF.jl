using VBFCatalog,TOML
"""Read current committed search progress in one SQLite transaction, including live runs."""
function status(dir)
    path=joinpath(dir,"run.sqlite");isfile(path) || error("not a search run")
    db=VBFCatalog.SQLite.DB("file:"*abspath(path)*"?mode=ro")
    DBI=VBFCatalog.DBInterface
    rows(sql)=[NamedTuple(r) for r in DBI.execute(db,sql)]
    scalar(sql)=only(rows(sql))[1]
    try
        foreach(_->nothing,DBI.execute(db,"BEGIN"))
        config=TOML.parse(scalar("SELECT value FROM metadata WHERE key='run'"))["identity"]["configuration"]
        units=Dict(String(r.status)=>Int(r.c) for r in rows("SELECT status,COUNT(*) c FROM units GROUP BY status"))
        candidates=scalar("SELECT COUNT(*) FROM candidates")
        additional=scalar("SELECT COUNT(DISTINCT sigma) FROM candidates WHERE additional=1")
        exhausted=scalar("SELECT COUNT(*) FROM metadata WHERE key='plan_complete'")>0 &&
            sum(values(units))>0 && get(units,"done",0)==sum(values(units))
        println("Run: ",abspath(dir));println("Method: ",config["method"])
        println("Exact candidate LUTs: $candidates; additional signatures: $additional")
        println("Work units: ",join(["$k=$(get(units,k,0))" for k in ("done","pending","paused","running")],", "))
        println("Frozen plan exhausted: $exhausted; literature novelty: unresolved")
        result=Dict("exact_luts"=>candidates,"additional_signatures"=>additional,"units"=>units,"finite_plan_exhausted"=>exhausted)
        foreach(_->nothing,DBI.execute(db,"ROLLBACK"));result
    finally
        VBFCatalog.SQLite.close(db)
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && (length(ARGS)==1 ? status(only(ARGS)) : error("expected RUN_DIRECTORY"))
