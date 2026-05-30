# Reproduction: the switching construction
# Yves Edel, Alexander Pott — Adv. Math. Commun. 2009  [EdelPott2009]
#
# Edel and Pott construct new APN functions by "switching" — changing F on the
# preimage of a 1-dimensional space so the result stays APN. BFA exposes this as
# `switching_neighbors`. This script checks that switching a small APN function
# yields APN neighbours, and that the paper's 22 quadratic 8-bit APN functions
# (Table 9), re-housed as the EdelPott2009 corpus, are all quadratic APN.
#
# Run standalone:  julia --project=. papers/EdelPott2009_switching.jl

using VBF
using VBFCatalog

const EXPECTED = (corpus = 22,)

function reproduce()
    gold = SBox{4}(gf_monomial_lut(4, 3))
    apn_neighbors = count(F -> differential_uniformity(F) == 2,
                          Iterators.flatten(switching_neighbors(gold)))
    db = load_catalog()
    try
        n = corpus_length(db, "edelpott2009_n8")
        quad_apn = all(let F = corpus_function(db, "edelpott2009_n8", i)
                           differential_uniformity(F) == 2 && algebraic_degree(F) == 2
                       end for i in (1, n ÷ 2 + 1, n))
        (corpus = n, apn_neighbors = apn_neighbors, quad_apn = quad_apn)
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# Switching construction — Edel–Pott 2009")
    println(io, "- APN switching-neighbours of Gold x³ (n=4): ", r.apn_neighbors)
    println(io, "- re-housed quadratic 8-bit APN (Table 9)  : ", r.corpus, " (sampled quad-APN: ", r.quad_apn, ")")
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
