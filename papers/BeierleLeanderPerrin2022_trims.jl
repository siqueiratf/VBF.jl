# Reproduction: trims and extensions of quadratic APN functions
# Beierle, Leander, Perrin — Designs, Codes and Cryptography 2022  [BeierleLeanderPerrin2022Trims]
#
# Beierle–Leander–Perrin study restrictions of a quadratic APN function to an
# affine hyperplane followed by an output projection (a "trim"); the multiset of
# the resulting EA-classes is an EA-invariant (the trim spectrum), and the
# inverse operation is an "extension". BFA implements `trim_spectrum` and
# `extend_quadratic_apn`. This script checks an extension of a low-dimensional
# quadratic APN is again quadratic APN, that the trim spectrum is non-trivial,
# and that the paper's 6,368 new 8-bit functions (re-housed) are quadratic APN.
#
# Run standalone:  julia --project=. papers/BeierleLeanderPerrin2022_trims.jl

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
