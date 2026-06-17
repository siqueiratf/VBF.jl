using VBF
using VBFCatalog

# (corpus name, bib_key, raw member count)
const FAMILIES = [
    ("edelpott2009_n8", "Edel_200900", 22),
    ("wengtangong2013_n8", "WengTanGong_201300", 10),
    ("yuwangli2014_qam_n8", "Yu_201411", 8179),
    ("taniguchi2019_n8", "Taniguchi_201909", 2),
    ("beierleleander2022_n8", "Beierle_202201", 12923),
    ("yuperrin2022_qam_n8", "Yu_202211", 5412),
    ("beierleleanderperrin2022_n8", "Beierle_202200", 6368),
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
