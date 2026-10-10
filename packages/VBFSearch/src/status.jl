"""Read current committed search progress in one SQLite transaction, including live runs."""
function status(dir)
    path=joinpath(dir,"run.sqlite");isfile(path) || error("not a search run")
    db=SQLite.DB("file:"*abspath(path)*"?mode=ro")
    DBI=DBInterface
    rows(sql)=[NamedTuple(r) for r in DBI.execute(db,sql)]
    scalar(sql)=only(rows(sql))[1]
    try
        foreach(_->nothing,DBI.execute(db,"BEGIN"))
        config=TOML.parse(scalar("SELECT value FROM metadata WHERE key='run'"))["identity"]["configuration"]
        progress=DiscoveryStore.snapshot(db)
        units=progress["units"];candidates=progress["exact_luts"]
        additional=progress["additional_signature_buckets"];exhausted=progress["finite_plan_exhausted"]
        println("Run: ",abspath(dir));println("Method: ",config["method"])
        println("Exact candidate LUTs: $candidates; additional signatures: $additional")
        println("Work units: ",join(["$k=$(get(units,k,0))" for k in ("done","pending","paused","running")],", "))
        println("Frozen plan exhausted: $exhausted; literature novelty: unresolved")
        result=Dict("exact_luts"=>candidates,"additional_signatures"=>additional,"units"=>units,"finite_plan_exhausted"=>exhausted)
        foreach(_->nothing,DBI.execute(db,"ROLLBACK"));result
    finally
        SQLite.close(db)
    end
end
