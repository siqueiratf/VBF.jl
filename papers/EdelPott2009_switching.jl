using VBF
using VBFCatalog

const EXPECTED = (corpus = 23,)
const TABLE9 = normpath(joinpath(@__DIR__, "data", "EdelPott2009_table9.txt"))

"Evaluate Table 9's polynomials over Conway GF(2⁸) into S-boxes."
function table9_functions()
    mod = conway_polynomial(8)
    polys = [l for l in readlines(TABLE9) if !startswith(strip(l), "#") && !isempty(strip(l))]
    [SBox{8}(polynomial_to_lut(p, 8, mod)) for p in polys]
end

function reproduce()
    fns = table9_functions()
    quad_apn = all(differential_uniformity(F) == 2 && algebraic_degree(F) == 2 for F in fns)
    gold = SBox{4}(gf_monomial_lut(4, 3))
    apn_neighbors = count(F -> differential_uniformity(F) == 2,
                          Iterators.flatten(switching_neighbors(gold)))
    db = load_catalog()
    try
        n = corpus_length(db, "edelpott2009_n8")
        # the freshly-evaluated formulas match the re-housed corpus byte-for-byte
        corpus_shas = Set(lut_sha256_hex(corpus_function(db, "edelpott2009_n8", i)) for i in 1:n)
        recomputed_shas = Set(lut_sha256_hex(F) for F in fns)
        (n_polynomials = length(fns), corpus = n,
         all_quadratic_apn = quad_apn,
         matches_corpus = (recomputed_shas == corpus_shas),
         apn_neighbors = apn_neighbors)
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# Switching construction + Table 9 — Edel–Pott 2009")
    println(io, "- Table 9 polynomials evaluated     : ", r.n_polynomials, " (all quadratic APN: ", r.all_quadratic_apn, ")")
    println(io, "- recomputed == re-housed corpus    : ", r.matches_corpus, " (", r.corpus, " members)")
    println(io, "- APN switching-neighbours of x³(n=4): ", r.apn_neighbors)
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
