# Reproduction: the QAM method
# Yu, Wang, Li — Designs, Codes and Cryptography 2014  [YuWangLi2014QAM]
#
# Yu–Wang–Li give a one-to-one correspondence between quadratic APN functions
# (without linear/constant part) and Quadratic APN Matrices (QAMs): `F` is APN
# iff its derivative matrix is a QAM. BFA implements both directions
# (`quadratic_apn_matrix` / `qam_to_sbox` / `is_qam`) and a search over the
# cyclic QAM space (`search_qam`). This script checks the correspondence on the
# re-housed firstQAM corpus and reproduces the n=4 search (the single quadratic
# APN class, Gold x³).
#
# Reproduction mode: VERIFIES PUBLISHED SEARCH OUTPUT + DEMONSTRATES THE METHOD.
#   The 8179 n=8 functions have no closed formula (they are the output of a
#   cluster-scale QAM search), so they are loaded from the re-housed corpus and
#   re-verified; the QAM method itself is run from scratch at n=4
#   (search_qam(4,2) → Gold x³). Re-running it at n=8 is Phase 21f.
#
# Run standalone:  julia --project=. papers/YuWangLi2014_qam.jl

using VBF
using VBFCatalog

const EXPECTED = (corpus = 8179,)

function reproduce()
    # search the cyclic QAM space on F2^4 → recovers Gold x³
    gold4 = SBox{4}(gf_monomial_lut(4, 3))
    search_gold = any(s -> apn_ea_mugshot(s) == apn_ea_mugshot(gold4), search_qam(4, 2))
    db = load_catalog()
    try
        n = corpus_length(db, "yuwangli2014_qam_n8")
        # the QAM↔F correspondence on sampled members: APN ⇔ derivative matrix is a QAM
        qam_correspondence = all(let F = corpus_function(db, "yuwangli2014_qam_n8", i)
                                     differential_uniformity(F) == 2 &&
                                     is_qam(quadratic_apn_matrix(F))
                                 end for i in (1, n ÷ 2 + 1, n))
        (corpus = n, search_finds_gold = search_gold, qam_correspondence = qam_correspondence)
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# QAM method — Yu–Wang–Li 2014")
    println(io, "- re-housed quadratic 8-bit APN (firstQAM): ", r.corpus)
    println(io, "- QAM↔F correspondence holds on samples   : ", r.qam_correspondence)
    println(io, "- search_qam(4,2) recovers Gold x³        : ", r.search_finds_gold)
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
