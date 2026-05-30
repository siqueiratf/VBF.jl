# Reproduction: the 8-bit quadratic-APN landscape known before the 3.4 GB set
#
# Prior to the large enumeration, 32,892 quadratic APN functions in eight
# variables were known up to EA-equivalence, contributed by seven papers
# (Edel–Pott 22, Yu–Wang–Li 8157, Weng–Tan–Gong 10, Taniguchi 2, Beierle–Leander
# 12921, Yu–Perrin 5412, Beierle–Leander–Perrin 6368). All seven families are
# re-housed as bulk corpora (32,916 members total — the raw counts). This
# capstone recomputes the ortho-derivative EA-fingerprint (`apn_ea_mugshot`) of
# every member and counts the distinct classes, *deriving* the literature's
# 32,892 rather than assuming it: the 24 cross-family collisions are removed by
# the computation, not by hand.
#
# `reproduce()` returns the fast per-family / raw totals (used by the test
# suite). `distinct_up_to_ea()` performs the full ~33k-fingerprint deduplication
# (minutes) and is run by `report()` / standalone.
#
# Reproduction mode: DERIVES the result from the re-housed corpora — the
#   literature's 32,892 distinct-up-to-EA count is computed by ortho-derivative
#   deduplication of all 32,916 members, not assumed.
#
# Run standalone:  julia --project=. papers/quadratic_apn_8bit_landscape.jl

using VBF
using VBFCatalog

# (corpus name, bib_key, raw member count)
const FAMILIES = [
    ("edelpott2009_n8", "EdelPott2009", 22),
    ("wengtangong2013_n8", "WengTanGong2013", 10),
    ("yuwangli2014_qam_n8", "YuWangLi2014QAM", 8179),
    ("taniguchi2019_n8", "Taniguchi2019", 2),
    ("beierleleander2022_n8", "BeierleLeander2022", 12923),
    ("yuperrin2022_qam_n8", "YuPerrin2022QAM", 5412),
    ("beierleleanderperrin2022_n8", "BeierleLeanderPerrin2022Trims", 6368),
]

const EXPECTED = (raw = 32916, distinct_up_to_ea = 32892)

function reproduce()
    db = load_catalog()
    try
        counts = [(name, corpus_length(db, name)) for (name, _, _) in FAMILIES]
        (n_corpora = length(FAMILIES),
         per_family = counts,
         raw = sum(c for (_, c) in counts))
    finally
        close(db)
    end
end

"The number of EA-distinct (ortho-derivative) classes across all seven families."
function distinct_up_to_ea()
    db = load_catalog()
    try
        seen = Set{APNEAMugshot}()
        for (name, _, _) in FAMILIES, i in 1:corpus_length(db, name)
            push!(seen, apn_ea_mugshot(corpus_function(db, name, i)))
        end
        length(seen)
    finally
        close(db)
    end
end

function report(io::IO = stdout; full::Bool = true)
    r = reproduce()
    println(io, "# 8-bit quadratic-APN landscape (pre-3.4 GB)")
    for (name, c) in r.per_family
        println(io, "- ", rpad(name, 30), c)
    end
    println(io, "- ", rpad("RAW total members", 30), r.raw, " (expected ", EXPECTED.raw, ")")
    if full
        d = distinct_up_to_ea()
        println(io, "- ", rpad("DISTINCT up to EA", 30), d, " (literature ", EXPECTED.distinct_up_to_ea, ")")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
