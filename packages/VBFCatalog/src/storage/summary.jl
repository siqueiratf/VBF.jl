"""Stored signature counts and overlaps; invariant equality is not equivalence."""
function signature_summary(; path::AbstractString=sigma_index_path())
    isfile(path) || throw(ArgumentError("signature index not found: $path"))
    db=SQLite.DB(path)
    rows(sql, params=())=[NamedTuple(r) for r in DBInterface.execute(db,sql,params)]
    try
        # Temporary tables leave the persistent index untouched.
        DBInterface.execute(db,"CREATE TEMP TABLE signatures AS SELECT DISTINCT source,n,sigma_hash FROM ccz_sigma_index")
        DBInterface.execute(db,"CREATE INDEX temp.signature_key ON signatures(n,sigma_hash)")
        DBInterface.execute(db,"CREATE TEMP TABLE multiplicity AS SELECT n,sigma_hash,COUNT(*) sources FROM signatures GROUP BY n,sigma_hash")
        sources=rows("SELECT s.source,s.n,COUNT(*) distinct_signatures,SUM(m.sources>1) shared_signatures FROM signatures s JOIN multiplicity m USING(n,sigma_hash) GROUP BY s.source,s.n ORDER BY s.source,s.n")
        indexed=Dict((String(r.source),Int(r.n))=>Int(r.c) for r in rows("SELECT source,n,COUNT(*) c FROM ccz_sigma_index GROUP BY source,n"))
        sources=[(;r...,indexed_rows=indexed[(String(r.source),Int(r.n))],unique_signatures=r.distinct_signatures-r.shared_signatures) for r in sources]
        overlaps=rows("SELECT a.source source_a,b.source source_b,a.n,COUNT(*) shared_signatures FROM signatures a JOIN signatures b ON a.n=b.n AND a.sigma_hash=b.sigma_hash AND a.source<b.source GROUP BY a.source,b.source,a.n ORDER BY shared_signatures DESC")
        dimensions=rows("SELECT n,COUNT(DISTINCT sigma_hash) distinct_signatures,COUNT(DISTINCT source) indexed_sources FROM signatures GROUP BY n ORDER BY n")
        (;sources,overlaps,dimensions)
    finally
        close(db)
    end
end

"""Count the UNION of stored signatures for selected sources and dimension.

Counts distinct invariant hashes under the index's integrity assumptions, not
confirmed equivalence classes. Overlapping sources contribute each hash once.
"""
function signature_count(;path::AbstractString=sigma_index_path(),n::Integer,sources)
    isempty(sources) && return 0
    isfile(path) || throw(ArgumentError("signature index not found: $path"))
    db=SQLite.DB(path)
    try
        DBInterface.execute(db,"PRAGMA query_only=ON")
        sql="SELECT COUNT(DISTINCT sigma_hash) c FROM ccz_sigma_index WHERE n=? AND source IN ("*join(fill("?",length(sources)),",")*")"
        only([Int(r.c) for r in DBInterface.execute(db,sql,(Int(n),String.(sources)...))])
    finally
        close(db)
    end
end
