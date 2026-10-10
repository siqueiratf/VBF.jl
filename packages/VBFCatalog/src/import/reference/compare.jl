"""Require successful, exhaustive coverage before making baseline comparisons."""
function require_complete(db, path)
    rows = [String(r.value) for r in DBI.execute(db, "SELECT value FROM metadata WHERE key='complete'")]
    rows == ["true"] || error("incomplete source: $path")
    nothing
end

"""Count a SQL query returning one scalar named c."""
scalar(db, query, params=()) = Int(first(DBI.execute(db, query, params)).c)

"""
Compare exact (source, member, signature) rows against the old index, then
compare per-source LUT/signature sets rebuilt from originals. A global union
is rebuilt from fresh signatures only. Missing originals or partial runs
prevent a provenance-complete report. Signature matches do not prove CCZ
equivalence; distinct signatures separate quadratic APN classes.
"""
function compare(outdir; stored=inputs("stored", outdir), raw=inputs("raw", outdir),
                 old_index_path=VBFCatalog.sigma_index_path())
    report = Dict{String,Any}("scope"=>"quadratic (8,8)-APN", "started_utc"=>string(now(UTC)),
        "sources"=>Dict{String,Any}(), "provenance_complete"=>false)
    unionpath = joinpath(outdir, "fresh_union.sqlite.building")
    isfile(unionpath) && rm(unionpath)
    uniondb = SQL.DB(unionpath)
    try
        SQL.execute(uniondb, "PRAGMA cache_size=-262144")
        SQL.execute(uniondb, "CREATE TABLE signatures(sigma_hash TEXT PRIMARY KEY) WITHOUT ROWID")
        old = readonly(old_index_path)
        try
            names = Set(d.corpus for d in stored)
            report["old_index_unknown_sources"] = [String(r.source) for r in DBI.execute(old,
                "SELECT DISTINCT source FROM ccz_sigma_index WHERE n=8") if !(String(r.source) in names)]
            report["old_index_n8_rows"] = scalar(old, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE n=8")
        finally
            close(old)
        end
        for desc in vcat(stored, raw)
            path = joinpath(outdir, desc.name * ".sqlite")
            db = readonly(path)
            try
                require_complete(db, path)
                saved_identity = only([String(r.value) for r in DBI.execute(db, "SELECT value FROM metadata WHERE key='identity'")])
                saved_identity == sprint(io -> TOML.print(io, input_identity(desc, 0); sorted=true)) ||
                    error("changed input/code since rebuild: $(desc.name)")
                info = TOML.parsefile(joinpath(outdir, desc.name * ".toml"))
                entry = Dict{String,Any}("records"=>scalar(db, "SELECT COUNT(*) c FROM records"),
                    "input_records_scanned"=>info["records"], "excluded_records"=>info["excluded_records"],
                    "distinct_signatures"=>scalar(db, "SELECT COUNT(DISTINCT sigma_hash) c FROM records"),
                    "descriptor_sha256_matches"=>info["descriptor_sha256_matches"])
                if startswith(desc.name, "stored_")
                    DBI.execute(db, "ATTACH DATABASE ? AS old", (old_index_path,))
                    SQL.execute(db, "PRAGMA temp_store=MEMORY")
                    DBI.execute(db, "CREATE TEMP TABLE old_rows AS SELECT member_idx,sigma_hash FROM old.ccz_sigma_index WHERE n=8 AND source=?", (desc.corpus,))
                    SQL.execute(db, "CREATE INDEX temp.ix_old_member ON old_rows(member_idx,sigma_hash)")
                    entry["old_index_rows"] = scalar(db, "SELECT COUNT(*) c FROM old_rows")
                    entry["missing_or_changed_index_rows"] = scalar(db,
                        "SELECT COUNT(*) c FROM records r WHERE NOT EXISTS (SELECT 1 FROM old_rows i WHERE i.member_idx=r.member_idx AND i.sigma_hash=r.sigma_hash)")
                    entry["orphan_or_changed_index_rows"] = scalar(db,
                        "SELECT COUNT(*) c FROM old_rows i WHERE NOT EXISTS (SELECT 1 FROM records r WHERE r.member_idx=i.member_idx AND r.sigma_hash=i.sigma_hash)")
                elseif desc.corpus != "langevin_may2025"
                    storepath = joinpath(outdir, "stored_" * desc.corpus * ".sqlite")
                    DBI.execute(db, "ATTACH DATABASE ? AS stored", (storepath,))
                    entry["raw_records_absent_from_store_luts"] = scalar(db,
                        "SELECT COUNT(*) c FROM records r WHERE NOT EXISTS(SELECT 1 FROM stored.records s WHERE s.lut_sha256=r.lut_sha256)")
                    entry["stored_records_absent_from_raw_luts"] = scalar(db,
                        "SELECT COUNT(*) c FROM stored.records s WHERE NOT EXISTS(SELECT 1 FROM records r WHERE r.lut_sha256=s.lut_sha256)")
                    entry["raw_signatures_absent_from_store"] = scalar(db,
                        "SELECT COUNT(DISTINCT sigma_hash) c FROM records r WHERE NOT EXISTS(SELECT 1 FROM stored.records s WHERE s.sigma_hash=r.sigma_hash)")
                    entry["stored_signatures_absent_from_raw"] = scalar(db,
                        "SELECT COUNT(DISTINCT sigma_hash) c FROM stored.records s WHERE NOT EXISTS(SELECT 1 FROM records r WHERE r.sigma_hash=s.sigma_hash)")
                end
                report["sources"][desc.name] = entry
                # Use one input at a time: SQLite's ATTACH limit is ten databases.
                DBI.execute(uniondb, "ATTACH DATABASE ? AS source", (path,))
                SQL.execute(uniondb, "INSERT OR IGNORE INTO signatures SELECT sigma_hash FROM source.records")
                SQL.execute(uniondb, "DETACH DATABASE source")
                println(desc.name, ": ", entry); flush(stdout)
            finally
                close(db)
            end
        end
        report["fresh_union_distinct_signatures"] = scalar(uniondb, "SELECT COUNT(*) c FROM signatures")
        stored_entries = [report["sources"][d.name] for d in stored]
        report["old_index_exact_rows_match"] = isempty(report["old_index_unknown_sources"]) &&
            all(e -> e["records"] == e["old_index_rows"] && e["missing_or_changed_index_rows"] ==
                e["orphan_or_changed_index_rows"] == 0, stored_entries)
        raw_entries = [report["sources"][d.name] for d in raw if d.corpus != "langevin_may2025"]
        report["stored_original_lut_sets_match"] = all(e -> e["raw_records_absent_from_store_luts"] ==
            e["stored_records_absent_from_raw_luts"] == 0, raw_entries)
        report["stored_original_signature_sets_match"] = all(e -> e["raw_signatures_absent_from_store"] ==
            e["stored_signatures_absent_from_raw"] == 0, raw_entries)
        report["provenance_complete"] = true
        report["limitations"] = [
            "Scope is the local quadratic (8,8)-APN corpus and named public source files, not all literature.",
            "Catalog functions are read from LUT rows; Taniguchi members use the library constructor.",
            "Matching signatures do not prove CCZ equivalence."]
        println("fresh comparison baseline: ", report["fresh_union_distinct_signatures"], " distinct signatures")
    finally
        close(uniondb)
    end
    final_union = joinpath(outdir, "fresh_union.sqlite")
    mv(unionpath, final_union; force=true)
    report["fresh_union_sha256"] = filehash(final_union)
    report["finished_utc"] = string(now(UTC))
    report_path = joinpath(outdir, "comparison.toml")
    open(io -> TOML.print(io, report; sorted=true), report_path * ".partial", "w")
    mv(report_path * ".partial", report_path; force=true)
    report
end
