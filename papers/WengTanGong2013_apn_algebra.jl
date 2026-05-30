# Reproduction: quadratic APN functions and their APN algebra
# Weng, Tan, Gong — WCC 2013  [WengTanGong2013]
#
# Weng–Tan–Gong characterise a quadratic APN function `F` by the commutative
# "APN algebra" `x ∗ y = F(x+y)+F(x)+F(y)+F(0)` — exactly the second-order
# derivative / associated bilinear form. In BFA that form is the **derivative
# matrix** `quadratic_apn_matrix(F)`, which is a QAM (`is_qam`) precisely when F
# is APN (Yu–Wang–Li). This script checks that characterisation on the paper's
# 10 new quadratic 8-bit APN functions, re-housed as the WengTanGong2013 corpus.
#
# Run standalone:  julia --project=. papers/WengTanGong2013_apn_algebra.jl

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
