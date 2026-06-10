# Implements optional VBFCatalog diagnostics for pre-2025 corpora
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 3 and 5
#
# Pseudocode:
#   1. Load the local catalog and list the registered n=8 quadratic APN corpora.
#   2. Compare local corpus member counts to the paper's previously known count total.
#   3. Label the result as diagnostic because corpus/import reconciliation can differ from paper classes.
# VBF API used: none; VBFCatalog is intentionally isolated to this file

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

const PRIOR_CORPUS_NAMES = [
    "beierleleander2022_n8",
    "beierleleanderperrin2022_n8",
    "edelpott2009_n8",
    "taniguchi2019_n8",
    "wengtangong2013_n8",
    "yuperrin2022_qam_n8",
    "yuwangli2014_qam_n8",
]

"Read local pre-2025 bulk-corpus counts from VBFCatalog."
function local_prior_corpus_counts()
    db = load_catalog()
    counts = Dict{String,Int}()
    for name in PRIOR_CORPUS_NAMES
        counts[name] = corpus_length(db, name)
    end
    counts
end

"Diagnostic comparison between local corpus members and paper prior classes."
function catalog_count_comparison()
    counts = local_prior_corpus_counts()
    local_total = sum(values(counts))
    (;
        counts,
        local_total,
        paper_prior_classes = PRIOR_KNOWN_CLASSES,
        delta = local_total - PRIOR_KNOWN_CLASSES,
        matches_paper_total = local_total == PRIOR_KNOWN_CLASSES,
    )
end

"Report local catalog counts without using them as proof of Theorem 5.1."
function catalog_validation_report(io::IO = stdout)
    print_section("Local Catalog Diagnostics", io)
    r = catalog_count_comparison()
    print_kv("local corpus total equals paper prior total", r.matches_paper_total, io)
    print_kv("paper prior classes", r.paper_prior_classes, io)
    print_kv("local corpus members", r.local_total, io)
    print_kv("delta", r.delta, io)
    for name in sort(collect(keys(r.counts)))
        print_kv(name, r.counts[name], io)
    end
    print_kv("completeness", "diagnostic only; theorem arithmetic uses paper constants", io)
    r
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    catalog_validation_report()
end
