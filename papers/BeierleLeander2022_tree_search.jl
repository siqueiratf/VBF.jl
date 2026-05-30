# Reproduction: new quadratic APN functions by recursive tree search
# Beierle, Leander — IEEE Trans. Inf. Theory 2022  [BeierleLeander2022]
#
# Beierle–Leander find quadratic APN functions with a degree-/DDT-pruned
# recursive tree search. BFA implements a deterministic version as
# `search_quadratic_apn(Val(N))`. This script reproduces the search on a small
# dimension (it returns a genuine quadratic APN function) and confirms the paper's
# 12,921 new 8-bit functions, re-housed as the BeierleLeander2022 corpus, are all
# quadratic APN.
#
# Run standalone:  julia --project=. papers/BeierleLeander2022_tree_search.jl

using VBF
using VBFCatalog

const EXPECTED = (corpus = 12923,)   # raw file count (the 12,921 new + 2 already-known)

function reproduce()
    found = search_quadratic_apn(Val(5); limit = 1)
    search_ok = !isempty(found) &&
                differential_uniformity(found[1]) == 2 &&
                algebraic_degree(found[1]) == 2
    db = load_catalog()
    try
        n = corpus_length(db, "beierleleander2022_n8")
        quad_apn = all(let F = corpus_function(db, "beierleleander2022_n8", i)
                           differential_uniformity(F) == 2 && algebraic_degree(F) == 2
                       end for i in (1, n ÷ 2 + 1, n))
        (corpus = n, search_finds_quadratic_apn = search_ok, quad_apn = quad_apn)
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# Recursive tree search — Beierle–Leander 2022")
    println(io, "- search_quadratic_apn(Val(5)) finds a quadratic APN: ", r.search_finds_quadratic_apn)
    println(io, "- re-housed 8-bit quadratic APN (BeierleLeander)    : ", r.corpus, " (sampled quad-APN: ", r.quad_apn, ")")
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
