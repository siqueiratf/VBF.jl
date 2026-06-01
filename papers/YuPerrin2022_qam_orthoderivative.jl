using VBF
using VBFCatalog

const EXPECTED = (corpus = 5412,)

function reproduce()
    db = load_catalog()
    try
        n = corpus_length(db, "yuperrin2022_qam_n8")
        sample = [corpus_function(db, "yuperrin2022_qam_n8", i) for i in 1:min(50, n)]
        (corpus = n,
         all_quadratic_apn = all(differential_uniformity(F) == 2 &&
                                 algebraic_degree(F) == 2 for F in sample),
         all_qam = all(is_qam(quadratic_apn_matrix(F)) for F in sample),
         # ortho-derivative fingerprints split the sample into CCZ buckets
         distinct_buckets = length(unique(apn_ea_mugshot(F) for F in sample)))
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# More QAM + ortho-derivative — Yu–Perrin 2022")
    println(io, "- re-housed quadratic 8-bit APN (secondQAM): ", r.corpus)
    println(io, "- all QAMs / quadratic APN (sample)        : ", r.all_qam, " / ", r.all_quadratic_apn)
    println(io, "- distinct ortho-derivative buckets (50)   : ", r.distinct_buckets)
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
