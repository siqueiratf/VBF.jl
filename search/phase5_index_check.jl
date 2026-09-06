# search/phase5_index_check.jl — PHASE 5 precondition.
#
# A novelty claim is an ABSENCE claim against the sigma index: "no known
# quadratic APN function at n=8 has this signature". That is only as good as the
# index's coverage. A partially-parsed index silently turns "known" into "new" —
# the exact failure that put four withdrawn functions into this catalog (commit
# 8022d09, per the note in packages/VBFCatalog/src/data/sigma.jl).
#
# So before any novelty claim: state the index's record count and confirm it
# against the source datasets' documented totals. Disagreement => stop.
#
# Writes: search/sigma_index_check.toml

using VBFCatalog
using TOML
# SQLite/DBInterface are VBFCatalog dependencies, not root-project ones.
const SQLite = VBFCatalog.SQLite
const DBInterface = VBFCatalog.DBInterface

const ROOT = normpath(joinpath(@__DIR__, ".."))

q1(db, sql) = first(DBInterface.execute(db, sql))

function main()
    p = sigma_index_path()
    isfile(p) || error("phase5: sigma index absent at $p")
    db = SQLite.DB(p)

    rows = q1(db, "SELECT COUNT(*) AS c FROM ccz_sigma_index").c
    distinct = q1(db, "SELECT COUNT(DISTINCT sigma_hash) AS c FROM ccz_sigma_index").c
    n8_rows = q1(db, "SELECT COUNT(*) AS c FROM ccz_sigma_index WHERE n = 8").c
    n8_distinct = q1(db, "SELECT COUNT(DISTINCT sigma_hash) AS c FROM ccz_sigma_index WHERE n = 8").c

    println("sigma index: $p")
    println("total rows            : $rows")
    println("distinct sigma        : $distinct")
    println("n=8 rows              : $n8_rows")
    println("n=8 distinct sigma    : $n8_distinct")

    println("\nper-source row counts:")
    per_source = Dict{String,Int}()
    for r in DBInterface.execute(db, "SELECT source, COUNT(*) AS c FROM ccz_sigma_index GROUP BY source ORDER BY c DESC")
        per_source[r.source] = r.c
        println("  ", rpad(r.source, 34), r.c)
    end

    println("\ncoverage table (what the index claims to cover):")
    cov = Tuple{String,Int,Int}[]
    for r in DBInterface.execute(db, "SELECT source, n, indexed FROM sigma_coverage ORDER BY source")
        push!(cov, (r.source, r.n, r.indexed))
        println("  ", rpad(r.source, 34), " n=", lpad(r.n, 3), "  indexed=", r.indexed)
    end
    skipped = [c for c in cov if c[3] == 0]

    # ── cross-check against the corpora themselves ──────────────────────────
    println("\ncross-check: corpus member counts from the corpus stores")
    cat = VBFCatalog.load_catalog()
    corpora = VBFCatalog.list_corpora(cat)
    println("  corpora present: ", length(corpora))
    mismatches = String[]
    total_members = 0
    for c in corpora
        nm = VBFCatalog.corpus_length(cat, c)
        total_members += nm
        indexed = get(per_source, c, 0)
        ok = indexed == nm
        ok || push!(mismatches, "$c: corpus has $nm members, index has $indexed rows")
        println("  ", rpad(c, 34), "members=", lpad(nm, 7), "  indexed=", lpad(indexed, 7),
                ok ? "  OK" : "  MISMATCH")
    end

    # ── compare against the figures recorded in bench/calibration.toml ──────
    calib = TOML.parsefile(joinpath(ROOT, "bench", "calibration.toml"))
    cb = get(calib, "sigma_index_build_all_corpora", Dict())
    doc_rows = get(cb, "total_rows", nothing)
    doc_distinct = get(cb, "distinct_sigma", nothing)
    doc_members = get(cb, "corpus_members", nothing)
    doc_funcs = get(cb, "functions_indexed", nothing)
    println("\ndocumented in bench/calibration.toml:")
    println("  total_rows        = ", doc_rows, "   observed ", rows,
            rows == doc_rows ? "   MATCH" : "   MISMATCH")
    println("  distinct_sigma    = ", doc_distinct, "   observed ", distinct,
            distinct == doc_distinct ? "   MATCH" : "   MISMATCH")
    println("  corpus_members    = ", doc_members, "   observed ", total_members,
            total_members == doc_members ? "   MATCH" : "   MISMATCH")
    println("  functions_indexed = ", doc_funcs)

    consistent = isempty(mismatches) && isempty(skipped) &&
                 (doc_rows === nothing || rows == doc_rows) &&
                 (doc_distinct === nothing || distinct == doc_distinct)

    open(joinpath(ROOT, "search", "sigma_index_check.toml"), "w") do io
        println(io, "# PHASE 5 precondition — sigma index parse verification")
        println(io, "path = ", repr(p))
        println(io, "total_rows = ", rows)
        println(io, "distinct_sigma = ", distinct)
        println(io, "n8_rows = ", n8_rows)
        println(io, "n8_distinct_sigma = ", n8_distinct)
        println(io, "corpora_present = ", length(corpora))
        println(io, "corpus_members_total = ", total_members)
        println(io, "documented_total_rows = ", repr(doc_rows))
        println(io, "documented_distinct_sigma = ", repr(doc_distinct))
        println(io, "documented_corpus_members = ", repr(doc_members))
        println(io, "rows_match_documented = ", doc_rows !== nothing && rows == doc_rows)
        println(io, "distinct_match_documented = ", doc_distinct !== nothing && distinct == doc_distinct)
        # `println(io, String[])` emits `String[]`, which is not valid TOML.
        toml_arr(v) = "[" * join(map(repr, v), ", ") * "]"
        println(io, "per_source_mismatches = ", toml_arr(mismatches))
        println(io, "sources_skipped = ", toml_arr([c[1] for c in skipped]))
        println(io, "consistent = ", consistent)
    end

    println("\nVERDICT: ", consistent ? "index parse CONSISTENT — novelty claims may be made against it" :
                                        "index parse INCONSISTENT — novelty claims are NOT valid")
    if !isempty(mismatches)
        println("mismatches:")
        foreach(m -> println("  ", m), mismatches)
    end
    consistent
end

main()
