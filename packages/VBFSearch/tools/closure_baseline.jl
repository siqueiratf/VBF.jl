using VBFSearch, TOML, SHA, SQLite

"""Shared baseline helper for the threaded closure controllers.

The controllers include this file and archive it as `baseline-controller.jl`.
It never claims construction work and never rewrites the frontier identity.
"""
const EA = VBFSearch

"""Save the complete mutable classification projection before any EA attempt."""
function ea_baseline!(s, directory)
    path=joinpath(directory,"classification-before.sqlite")
    ispath(path) && error("baseline already exists")
    EA._closure_exec(s.db,"ATTACH DATABASE ? AS ea_before",(path,))
    try
        for table in ("metadata","candidates","parents","jobs","comparisons","sessions")
            EA._closure_exec(s.db,"CREATE TABLE ea_before.\"$table\" AS SELECT * FROM main.\"$table\"")
        end
        for table in ("candidates","parents","jobs")
            EA._closure_exec(s.db,"CREATE UNIQUE INDEX ea_before.\"$(table)_id\" ON \"$table\"(id)")
        end
    finally
        EA._closure_exec(s.db,"DETACH DATABASE ea_before")
    end
    Dict("path"=>path,"bytes"=>filesize(path),"sha256"=>EA.DiscoveryEvidence.filehash(path),
        "scope"=>"classification, parents and all job cursors; construction path/kernel/chunk evidence remains in the source database")
end
