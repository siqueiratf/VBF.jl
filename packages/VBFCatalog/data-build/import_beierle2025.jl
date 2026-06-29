# Import the Beierle–Langevin–Leander–Polujan–Rasoolzadeh (2025) dataset as the
# bulk corpus `beierle2025_n8`: 3,775,599 inequivalent quadratic APN over GF(2^8)
# (Zenodo 16752428 / arXiv:2508.04644). Source is the compact ANF side-file
# papers/Kuznetsov_202606/catalogs/apn8_blp2025.anf; each LUT is reconstructed and
# re-encoded into the catalog's canonical `quadratic-coeffs-v1` (37-byte) form
# (threaded, in batches).
using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates

const KUZDIR = normpath(joinpath(@__DIR__, "..", "..", "..", "papers", "Kuznetsov_202606"))
const ANF_FILE = joinpath(KUZDIR, "catalogs", "apn8_blp2025.anf")
include(joinpath(KUZDIR, "anf.jl"))
using .ANF

function ensure_bib!(db::SQLite.DB, key::AbstractString)
    entry = nothing
    for e in load_bibliography(); e.bib_key == key && (entry = e; break); end
    entry === nothing && error("bib key $key not in bibliography.bib")
    io = IOBuffer(); print(io, "@", entry.entry_type, "{", entry.bib_key)
    for (k, v) in sort(collect(entry.fields); by = first); print(io, ",\n    ", k, " = {", v, "}"); end
    print(io, "\n}")
    SQLite.execute(db, string(
        "INSERT OR IGNORE INTO bibliography (bib_key, bibtex, doi, url, year, authors) VALUES (",
        VBFCatalog._sql_quote(entry.bib_key), ", ", VBFCatalog._sql_quote(String(take!(io))), ", ",
        VBFCatalog._sql_quote(get(entry, "doi", "")), ", ", VBFCatalog._sql_quote(get(entry, "url", "")), ", ",
        parse(Int, strip(get(entry, "year", "0"))), ", ", VBFCatalog._sql_quote(get(entry, "author", "")), ")"))
end

# Stream the .anf, re-encode in threaded batches into the full encodings vector.
function reencode_all(; n::Int, modulus::Int, batch::Int = 50_000)
    powtab = monomial_power_table(n, modulus)
    encs = Vector{Vector{UInt8}}()
    buf = Vector{Vector{UInt8}}()
    flush_buf = function ()
        isempty(buf) && return
        out = Vector{Vector{UInt8}}(undef, length(buf))
        Threads.@threads for i in eachindex(buf)
            out[i] = encode_quadratic(SBox{n}(buf[i]); modulus = modulus, verify = false, powtab = powtab)
        end
        append!(encs, out); empty!(buf)
    end
    ANF.foreach_anf_lut(ANF_FILE) do lut
        push!(buf, copy(lut)); length(buf) >= batch && flush_buf()
    end
    flush_buf()
    encs
end

function main()
    isfile(ANF_FILE) || error("missing $ANF_FILE — run papers/Kuznetsov pack first")
    n = 8; modulus = conway_polynomial(n)
    @info "Beierle 2025 import" file = ANF_FILE
    t = @elapsed encs = reencode_all(; n = n, modulus = modulus)
    @info "re-encoded" members = length(encs) seconds = round(t; digits = 1)
    # spot-verify a sample round-trips (verify=false in bulk for speed)
    let pt = monomial_power_table(n, modulus)
        for i in (1, length(encs) ÷ 2, length(encs))
            F = corpus_decode_check(encs[i], n, modulus)
            differential_uniformity(F) == 2 || error("beierle2025: sample $i not APN after re-encode")
        end
    end
    db = load_catalog()
    try
        ensure_bib!(db, "Beierle_202500")
        corpus = "beierle2025_n8"
        store = build_corpus_store!(corpus, encs)
        register_corpus!(db;
            name = corpus, n = n, m = n, member_count = store.count, degree = 2,
            modulus = modulus, encoding = "quadratic-coeffs-v1",
            bytes_per_member = store.bytes_per_member,
            store_file = "corpora/" * corpus * ".sqlite", store_sha256 = store.sha256,
            family = "CCZ-rep", bib_key = "Beierle_202500",
            source_repo = "zenodo-16752428", contributor = "VBFCatalog Beierle-2025 import",
            added_date = string(Dates.now(Dates.UTC)) * "Z",
            notes = "Beierle, Langevin, Leander, Polujan, Rasoolzadeh (2025), arXiv:2508.04644 / " *
                    "Zenodo 16752428: 3,775,599 inequivalent (up to EA = CCZ for quadratic) " *
                    "quadratic APN over GF(2^8).")
        println("[beierle2025] corpus=$corpus members=$(store.count) bytes/member=$(store.bytes_per_member)")
    finally
        close(db)
    end
    return nothing
end

corpus_decode_check(enc, n, modulus) = SBox{n}(decode_quadratic_lut(enc, n, modulus))

if !isinteractive() && get(ENV, "BFA_BEIERLE2025_NO_AUTORUN", "0") != "1"
    main()
end
