# Scope-limited signature checks. Missing/incomplete named sources are unknown;
# a signature match locates an exact-equivalence query, not a positive verdict.
using VBFCatalog, VBF
const DBI = VBFCatalog.DBInterface
include(joinpath(@__DIR__, "helpers.jl"))
const DB_BEIERLE2025 = "beierle2025_n8"
const DB_BBL_FILE = "beierleleander2022_n8"
const DB_EDELPOTT = "edelpott2009_n8"

"""Check registered count and distinct member coverage for one named source."""
function source_coverage(idx, db, source)
    info = VBFCatalog.corpus_info(db, source)
    info === nothing && return (; status = :inconclusive, reason = "source not registered", expected = 0, indexed = 0)
    isfile(VBFCatalog.corpus_store_path(source)) || return (; status = :inconclusive, reason = "corpus store unavailable", expected = Int(info.member_count), indexed = 0)
    tables = Set(String(r.name) for r in DBI.execute(idx,
        "SELECT name FROM sqlite_master WHERE type='table'"))
    "sigma_coverage" in tables || return (; status = :inconclusive, reason = "missing coverage metadata", expected = Int(info.member_count), indexed = 0)
    recorded = any(r.indexed == 1 for r in DBI.execute(idx,
        "SELECT indexed FROM sigma_coverage WHERE source = ? AND n = 8", (source,)))
    row = first(DBI.execute(idx,
        "SELECT COUNT(*) AS count, COUNT(DISTINCT member_idx) AS distinct_count, MIN(member_idx) AS lo, MAX(member_idx) AS hi FROM ccz_sigma_index WHERE source = ? AND n = 8", (source,)))
    expected = Int(info.member_count)
    complete = recorded && expected > 0 && row.count == row.distinct_count == expected && row.lo == 1 && row.hi == expected
    (; status = complete ? :covered : :inconclusive,
       reason = complete ? "all registered member indices indexed" : "missing or incomplete named-source coverage",
       expected, indexed = Int(row.count))
end

function theorem6_run(; index_path = VBFCatalog.sigma_index_path())
    reps = representative_sboxes()
    goldσ = Set(VBFCatalog.sigma_hash.((gold_apn(8, 1), gold_apn(8, 3))))
    db = VBFCatalog.SQLite.DB(VBFCatalog.catalog_path())
    idx = isfile(index_path) ? VBFCatalog.SQLite.DB(index_path) : nothing
    try
        coverage = Dict(source => idx === nothing ?
            (; status = :inconclusive, reason = "signature index unavailable", expected = 0, indexed = 0) :
            source_coverage(idx, db, source)
            for source in (DB_BEIERLE2025, DB_BBL_FILE, DB_EDELPOTT))
        map((:class_a, :class_b, :class_c, :class_d)) do nm
            F = getfield(reps, nm)
            h = VBFCatalog.sigma_hash(F)
            function membership(source)
                coverage[source].status == :covered || return missing
                any(true for _ in DBI.execute(idx,
                    "SELECT 1 FROM ccz_sigma_index WHERE sigma_hash = ? AND source = ? AND n = 8 LIMIT 1", (h, source)))
            end
            (; nm, coverage, in_beierle2025 = membership(DB_BEIERLE2025),
               in_bbl_file = membership(DB_BBL_FILE),
               is_gold = h in goldσ, in_edelpott = membership(DB_EDELPOTT))
        end
    finally
        idx === nothing || VBFCatalog.SQLite.close(idx)
        VBFCatalog.SQLite.close(db)
    end
end

function theorem6_report(io::IO = stdout; kwargs...)
    rows = theorem6_run(; kwargs...)
    print_section("Theorem 6 — named-source signature evidence", io)
    for (source, c) in sort!(collect(first(rows).coverage); by = first)
        print_kv(source, "$(c.status): $(c.reason) ($(c.indexed)/$(c.expected))", io)
    end
    for r in rows
        print_kv(String(r.nm), "Beierle2025=$(r.in_beierle2025), BeierleLeander2022=$(r.in_bbl_file), Gold signature=$(r.is_gold), EdelPott2009=$(r.in_edelpott)", io)
    end
    print_kv("Guarantee", "Signature absence separates only from the covered named sources; missing sources are inconclusive. Matches require exact witnesses (theorem6_exact.jl).", io)
    print_kv("Literature novelty", "not established by this signature report", io)
    rows
end
if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_report()
end
