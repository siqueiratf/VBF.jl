using VBF
using VBFCatalog

const EXPECTED = (corpus = 6368,)

function reproduce()
    # extension: a 3-bit quadratic APN (Gold x³) extends to a 4-bit quadratic APN
    g3 = SBox{3}(gf_monomial_lut(3, 3))
    ext = extend_quadratic_apn(g3; limit = 1)
    ext_ok = !isempty(ext) &&
             differential_uniformity(ext[1]) == 2 &&
             algebraic_degree(ext[1]) == 2
    # the trim spectrum of a quadratic APN is a non-empty EA-class multiset
    spec = trim_spectrum(SBox{4}(gf_monomial_lut(4, 3)))
    db = load_catalog()
    try
        n = corpus_length(db, "beierleleanderperrin2022_n8")
        quad_apn = all(let F = corpus_function(db, "beierleleanderperrin2022_n8", i)
                           differential_uniformity(F) == 2 && algebraic_degree(F) == 2
                       end for i in (1, n ÷ 2 + 1, n))
        (corpus = n, extension_is_apn = ext_ok,
         trim_spectrum_nonempty = !isempty(spec), quad_apn = quad_apn)
    finally
        close(db)
    end
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# Trims and extensions — Beierle–Leander–Perrin 2022")
    println(io, "- extension of a 3-bit quadratic APN is quadratic APN: ", r.extension_is_apn)
    println(io, "- trim spectrum is a non-empty EA-class multiset     : ", r.trim_spectrum_nonempty)
    println(io, "- re-housed 8-bit quadratic APN (BLP22)              : ", r.corpus, " (sampled quad-APN: ", r.quad_apn, ")")
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
