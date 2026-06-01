using VBF
using VBFCatalog
using TOML

const EXPECTED = (corpus = 12923,)   # raw file count (the 12,921 new + 2 already-known)

function reproduce()
    found = search_quadratic_apn(Val(5); limit = 1)
    search_ok = !isempty(found) &&
                differential_uniformity(found[1]) == 2 &&
                algebraic_degree(found[1]) == 2
    # the actual BL22 method at n=7: the class-1 LE-automorphism constraint
    le = TOML.parsefile(joinpath(pkgdir(VBFCatalog), "data-raw",
                                 "le_automorphism_tuples", "n7.toml"))["class1"]
    le_sols = search_quadratic_apn_le(Int.(le["A"]), Int.(le["B"]);
                                      pos = Int.(le["pos"]), fix = Int.(le["fix"]), limit = 1)
    le_ok = !isempty(le_sols) && inputbits(le_sols[1]) == 7 &&
            differential_uniformity(le_sols[1]) == 2 && algebraic_degree(le_sols[1]) == 2
    db = load_catalog()
    try
        n = corpus_length(db, "beierleleander2022_n8")
        quad_apn = all(let F = corpus_function(db, "beierleleander2022_n8", i)
                           differential_uniformity(F) == 2 && algebraic_degree(F) == 2
                       end for i in (1, n ÷ 2 + 1, n))
        (corpus = n, search_finds_quadratic_apn = search_ok,
         le_search_n7_apn = le_ok, quad_apn = quad_apn)
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# Recursive tree search — Beierle–Leander 2022")
    println(io, "- plain search (Val(5)) finds a quadratic APN       : ", r.search_finds_quadratic_apn)
    println(io, "- LE-automorphism search (n=7, class 1) finds qAPN  : ", r.le_search_n7_apn)
    println(io, "- re-housed 8-bit quadratic APN (BeierleLeander)    : ", r.corpus, " (sampled quad-APN: ", r.quad_apn, ")")
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
