"""Read one consistent SQLite snapshot, without acquiring the experiment's writer lease."""
function report_snapshot(directory)
    db=SQLite.DB("file:"*abspath(joinpath(directory,"run.sqlite"))*"?mode=ro")
    rows(sql)=DiscoveryStore.query(db,sql)
    try
        DiscoveryStore.execute!(db,"BEGIN")
        candidates=[TOML.parse(r["evidence"]) for r in rows("SELECT evidence FROM candidates ORDER BY lut_id")]
        summary=DiscoveryStore.snapshot(db)
        merge(summary,Dict("created_utc"=>string(now(UTC)),
            "manifest"=>TOML.parse(only(rows("SELECT value FROM metadata WHERE key='run'"))["value"]),
            "candidates"=>candidates,
            "construction_units"=>rows("SELECT id,kind,status,direction,result FROM units ORDER BY id"),
            "sessions"=>rows("SELECT * FROM sessions ORDER BY id"),
            "comparisons"=>[TOML.parse(r["evidence"]) for r in rows("SELECT evidence FROM comparisons ORDER BY id")],
            "counts"=>Dict("exact_luts"=>length(candidates),
                "evaluated_switching_combinations"=>only(rows("SELECT COUNT(*) c FROM evaluations"))["c"],
                "apn_luts"=>count(p->p["apn"],candidates),
                "quadratic_apn_luts"=>count(p->p["apn"] && p["quadratic"],candidates),
                "quadratic_signature_buckets"=>length(Set(p["sigma_hash"] for p in candidates if p["apn"] && p["quadratic"])),
                "corpus_absent_signature_buckets"=>summary["corpus_absent_signature_buckets"]),
            "novelty_scope"=>"documented quadratic corpus only"))
    finally
        SQLite.intransaction(db) && DiscoveryStore.execute!(db,"ROLLBACK")
        SQLite.close(db)
    end
end

function write_evidence_table(path,rows,fields;delim=',')
    names=Tuple(Symbol.(fields))
    records=[NamedTuple{names}(Tuple(get(row,key,missing) for key in fields)) for row in rows]
    # A typed empty vector preserves CSV headers for a run with no discoveries.
    isempty(records) && (records=NamedTuple{names,NTuple{length(fields),String}}[])
    CSV.write(path,records;delim)
end

"""Export a consistent experiment snapshot, candidate tables and reusable seeds in Julia.
Publication plots consume this output from VBFWorkingPaper.
"""
function report(directory;output=joinpath(directory,"publication"))
    evidence=report_snapshot(directory);mkpath(output)
    open(io->JSON3.write(io,evidence),joinpath(output,"snapshot.json"),"w")
    candidates=evidence["candidates"]
    write_evidence_table(joinpath(output,"candidates.csv"),candidates,
        ["lut_sha256","sigma_hash","apn","algebraic_degree","differential_uniformity","evidence_level","literature_novelty","lut_hex"])
    write_evidence_table(joinpath(output,"seeds.tsv"),filter(p->p["apn"] && p["quadratic"],candidates),
        ["sigma_hash","lut_hex","lut_sha256"];delim='\t')
    write_evidence_table(joinpath(output,"relationships.csv"),evidence["comparisons"],
        ["candidate_sha256","target_sha256","relation","status","equivalent"])
    open(joinpath(output,"counts.tex"),"w") do io
        println(io,raw"\begin{tabular}{lr}")
        println(io,raw"Measure & Count \\")
        println(io,raw"\hline")
        for (key,value) in sort!(collect(evidence["counts"]))
            println(io,replace(key,'_'=>' ')," & ",value,raw" \\")
        end
        println(io,raw"\end{tabular}")
        println(io,"% Signature buckets are lower bounds on quadratic CCZ classes; literature novelty is unresolved.")
    end
    abspath(output)
end
