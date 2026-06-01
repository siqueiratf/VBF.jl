using VBF
using VBFCatalog

const EXPECTED = (corpus = 8179,)

function reproduce()
    gold4 = SBox{4}(gf_monomial_lut(4, 3))
    # the real QAM method: Algorithm 1's guess-and-determine over the full symmetric QAM space recovers the n=4 classification (the Gold x³ class)
    gd = search_qam_full(4; limit = 1)
    gd_gold = !isempty(gd) && apn_ea_mugshot(gd[1]) == apn_ea_mugshot(gold4)
    # the narrower cyclic search also recovers it on F2^4
    cyclic_gold = any(s -> apn_ea_mugshot(s) == apn_ea_mugshot(gold4), search_qam(4, 2))
    db = load_catalog()
    try
        n = corpus_length(db, "yuwangli2014_qam_n8")
        # the QAM↔F correspondence on sampled members: APN ⇔ derivative matrix is a QAM
        qam_correspondence = all(let F = corpus_function(db, "yuwangli2014_qam_n8", i)
                                     differential_uniformity(F) == 2 &&
                                     is_qam(quadratic_apn_matrix(F))
                                 end for i in (1, n ÷ 2 + 1, n))
        (corpus = n, gd_search_n4_gold = gd_gold, cyclic_gold = cyclic_gold,
         qam_correspondence = qam_correspondence)
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# QAM method — Yu–Wang–Li 2014")
    println(io, "- re-housed quadratic 8-bit APN (firstQAM)        : ", r.corpus)
    println(io, "- QAM↔F correspondence holds on samples          : ", r.qam_correspondence)
    println(io, "- search_qam_full(4) (Algorithm 1) recovers Gold : ", r.gd_search_n4_gold)
    println(io, "- search_qam(4,2) (cyclic) recovers Gold         : ", r.cyclic_gold)
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
