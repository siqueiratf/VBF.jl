using VBF
using VBFCatalog

const EXPECTED = (corpus = 10,)

function reproduce()
    db = load_catalog()
    try
        n = corpus_length(db, "wengtangong2013_n8")
        members = [corpus_function(db, "wengtangong2013_n8", i) for i in 1:n]
        (corpus = n,
         all_quadratic_apn = all(differential_uniformity(F) == 2 &&
                                 algebraic_degree(F) == 2 for F in members),
         # the APN-algebra / derivative matrix of every member is a QAM
         all_qam = all(is_qam(quadratic_apn_matrix(F)) for F in members))
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# APN algebra characterisation — Weng–Tan–Gong 2013")
    println(io, "- re-housed new quadratic 8-bit APN : ", r.corpus)
    println(io, "- all quadratic APN                 : ", r.all_quadratic_apn)
    println(io, "- derivative matrix is a QAM (APN)  : ", r.all_qam)
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
