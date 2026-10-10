# Import the Kuznetsov (2026) quadratic-APN dataset as the bulk corpus
# `kuznetsov2026_n8`. Source: the paper's apn_all.json (566 functions, 6 CCZ
# classes incl. the four classes A–D the paper reports as new). Each function is
# re-encoded into the catalog's canonical `quadratic-coeffs-v1` (37-byte) form.
using VBF
using VBFCatalog
import SQLite
import DBInterface
import JSON3
import Dates

include(joinpath(@__DIR__, "load_sources.jl"))

# Insert the source's citation from the shared bibliography, idempotently.
include(joinpath(@__DIR__, "bibliography.jl"))

function main()
    with_source("kuznetsov2026") do root
        import_kuznetsov_file(joinpath(root,"apn_all.json"))
    end
end

function import_kuznetsov_file(APN_ALL)
    n = 8
    modulus = conway_polynomial(n)
    powtab = monomial_power_table(n, modulus)
    data = JSON3.read(read(APN_ALL, String))
    luts = [UInt8.(collect(f.sbox)) for f in data.functions]
    @info "Kuznetsov 2026 import" file = APN_ALL members = length(luts)
    encs = [encode_quadratic(SBox{n}(l); modulus = modulus, verify = true, powtab = powtab) for l in luts]

    db = load_catalog()
    try
        ensure_bib!(db, "Kuznetsov_202600")
        corpus = "kuznetsov2026_n8"
        store = build_corpus_store!(corpus, encs)
        register_corpus!(db;
            name = corpus, n = n, m = n, member_count = store.count, degree = 2,
            modulus = modulus, encoding = "quadratic-coeffs-v1",
            bytes_per_member = store.bytes_per_member,
            store_file = store.store_file, store_sha256 = store.sha256,
            family = "CCZ-rep", bib_key = "Kuznetsov_202600",
            source_repo = "kuznetsov-apn-gb-search", contributor = "VBFCatalog Kuznetsov-2026 import",
            added_date = string(Dates.now(Dates.UTC)) * "Z",
            notes = "Kuznetsov (2026), arXiv:2606.11967: 566 quadratic APN over GF(2^8) found by " *
                    "Gröbner-basis search in a self-equivalence subspace (6 CCZ classes; A–D reported new).")
        println("[kuznetsov2026] corpus=$corpus members=$(store.count) bytes/member=$(store.bytes_per_member)")
    finally
        close(db)
    end
    return nothing
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    main()
end
