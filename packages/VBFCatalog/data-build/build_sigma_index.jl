# Build the σ-signature CCZ index over every bulk corpus + functions-table
# quadratic-APN row, populate equivalence_classes for the functions reps, and
# validate. Also registers the Simon-Berg corpus if its side store exists but
# wasn't recorded in bulk_corpora.
#
# --functions-only indexes ONLY the functions table (~600 σ, seconds) and skips
# the corpora (~230k members, hours) and the equivalence_classes population. The
# skipped corpora are recorded in sigma_coverage, so the oracle still refuses to
# answer at n=8 rather than returning an uncertified `:new`. Every corpus is n=8,
# so at every other dimension this index is exactly as complete as the full one —
# which is why it is enough for the n=7 / n=9 paper reproductions in CI, where
# the full build does not fit in the job budget.
using VBF
using VBFCatalog
import SQLite
import DBInterface
import SHA
import Dates

function ensure_simonberg_registered!(db::SQLite.DB)
    name = "simonberg_gf4_n8"
    corpus_info(db, name) === nothing || return false
    path = corpus_store_path(name)
    isfile(path) || return false
    n = 8; modulus = conway_polynomial(n)
    cnt = 0; bpm = 0
    s = SQLite.DB(path)
    try
        for r in DBInterface.execute(s, "SELECT COUNT(*) c, MAX(LENGTH(coeffs)) b FROM members")
            cnt = Int(r.c); bpm = r.b === missing ? 0 : Int(r.b)
        end
    finally; close(s); end
    sha = bytes2hex(SHA.sha256(read(path)))
    register_corpus!(db;
        name = name, n = n, m = n, member_count = cnt, degree = 2, modulus = modulus,
        encoding = "quadratic-coeffs-v1", bytes_per_member = bpm,
        store_file = "corpora/" * name * ".sqlite", store_sha256 = sha,
        family = "CCZ-rep-GF4", bib_key = nothing,
        source_repo = "simonberg-thesis", contributor = "VBFCatalog (re-register existing side store)",
        added_date = string(Dates.now(Dates.UTC)) * "Z",
        notes = "Simon-Berg thesis: GF(2^2)-coefficient quadratic APN over GF(2^8); " *
                "side store present, descriptor re-registered.")
    true
end

function main(; functions_only::Bool = false)
    db = load_catalog()
    try
        if functions_only
            println("functions-only build: corpora SKIPPED (recorded in sigma_coverage; n=8 lookups will refuse)")
            t = @elapsed stats = build_sigma_index!(db; rebuild = true, corpora = String[])
            println("σ-index built in $(round(t;digits=1))s: functions=$(stats.functions) ",
                    "distinct=$(stats.distinct)")
            return
        end
        ensure_simonberg_registered!(db) && println("registered simonberg_gf4_n8")
        println("corpora indexed: ", list_corpora(db))
        t = @elapsed stats = build_sigma_index!(db; rebuild = true)
        println("σ-index built in $(round(t;digits=1))s: functions=$(stats.functions) ",
                "corpus_members=$(stats.corpus_members) total=$(stats.total) distinct=$(stats.distinct)")
        nc = populate_ccz_equivalence_classes!(db)
        println("equivalence_classes (CCZ) populated: $nc")
    finally
        close(db)
    end
end

main(; functions_only = "--functions-only" in ARGS)
