# Import the Beierle–Langevin–Leander–Polujan–Rasoolzadeh (2025) dataset as the
# bulk corpus `beierle2025_n8`: 3,775,599 inequivalent quadratic APN functions
# over GF(2^8) (Zenodo 16752428 / arXiv:2508.04644).
#
# The source is `new_apns.txt`, a 3.4 GB plain-text file with one lookup table
# per line, written as `[c0,c1,…,c255]`. The file never fits in memory as a
# single String, so the reader streams it line by line and re-encodes each LUT
# into the catalog's canonical `quadratic-coeffs-v1` (37-byte) form in threaded
# batches.
#
# Every member is re-verified before it enters the store: the LUT must have
# 2^8 entries, differential uniformity 2, and algebraic degree 2. The importer
# also computes the ortho-derivative σ-signature of each member and compares it
# against the σ-index side store BEFORE the new corpus is registered, so the
# run reports how many members are certified CCZ-inequivalent to everything the
# catalog already holds. See `VBFCatalog.sigma_hash` for why a σ mismatch is a
# proof of CCZ-inequivalence.
#
# Per the design note in VBFCatalog/src/data/corpus.jl, no `functions` rows are
# added: a family of this size lives in `bulk_corpora` plus its side store, the
# same treatment every other 8-bit quadratic-APN family gets.
using VBF
using VBFCatalog
import SQLite
import DBInterface
import SHA
import Dates

include(joinpath(@__DIR__, "load_sources.jl"))

const N = 8
const MOD8 = conway_polynomial(N)
const CORPUS = "beierle2025_n8"
const BIB_KEY = "Beierle_202500"

# --- parsing ----------------------------------------------------------------

"""
Parse one `[c0,c1,…,c255]` line into a length-2^N LUT, in place.

Returns `true` on success. A blank line, or a line whose entry count is not
2^N, returns `false` — the caller counts it as malformed rather than aborting
the 3.4 GB stream on one bad byte.
"""
function parse_lut_line!(lut::Vector{Int}, line::AbstractString)
    b = codeunits(line)
    i = 1
    len = length(b)
    while i <= len && (b[i] == UInt8('[') || b[i] == UInt8(' '))
        i += 1
    end
    k = 0
    v = 0
    digits = 0
    @inbounds while i <= len
        c = b[i]
        if UInt8('0') <= c <= UInt8('9')
            v = 10v + Int(c - UInt8('0'))
            digits += 1
        elseif c == UInt8(',') || c == UInt8(']')
            digits == 0 && return false
            k += 1
            k > length(lut) && return false
            lut[k] = v
            v = 0
            digits = 0
            c == UInt8(']') && break
        elseif c == UInt8(' ') || c == UInt8('\r') || c == UInt8('\n')
            # separator padding
        else
            return false
        end
        i += 1
    end
    digits > 0 && (k += 1; k <= length(lut) && (lut[k] = v))
    k == length(lut)
end

# --- the novelty baseline ---------------------------------------------------

"""
The set of n-dimensional σ-hashes already in the σ-index side store.

Returns `nothing` when the index is absent or does not cover every n=8 source:
a σ-absence certifies novelty only against what was actually indexed, so a
partial baseline must not be reported as a novelty certificate.
"""
function sigma_baseline(n::Integer)
    path = sigma_index_path()
    isfile(path) || return nothing
    idx = SQLite.DB(path)
    try
        has_cov = false
        for _ in DBInterface.execute(
            idx,
            "SELECT name FROM sqlite_master WHERE type='table' AND name='sigma_coverage'")
            has_cov = true
        end
        has_cov || return nothing
        for r in DBInterface.execute(
            idx,
            "SELECT source FROM sigma_coverage WHERE indexed = 0 AND n IN ($(Int(n)), -1)")
            @warn "σ-index does not cover a source; novelty cannot be certified" source=String(r.source)
            return nothing
        end
        s = Set{String}()
        for r in DBInterface.execute(
            idx, "SELECT DISTINCT sigma_hash FROM ccz_sigma_index WHERE n = $(Int(n))")
            push!(s, String(r.sigma_hash))
        end
        return s
    finally
        close(idx)
    end
end

# --- the streaming import ---------------------------------------------------

struct ImportStats
    lines::Int
    malformed::Int
    not_quadratic_apn::Int
    duplicate::Int
    accepted::Int
    sigma_known::Int          # σ already present in the pre-import index
    sigma_new::Int            # σ absent  ⇒ certified CCZ-inequivalent to the catalog
    distinct_sigma_new::Int
end

"""
Stream `path`, validate and re-encode every member, and return
`(encodings, stats)`.

`baseline` is the pre-import σ set from [`sigma_baseline`](@ref), or `nothing`
to skip the novelty tally.
"""
function stream_members(path::AbstractString; baseline::Union{Nothing,Set{String}},
                        batch::Int = 50_000, powtab)
    nthreads = Threads.nthreads()
    encs = Vector{Vector{UInt8}}()
    seen = Set{Vector{UInt8}}()
    newsig = Set{String}()
    lines = malformed = notqapn = dup = 0
    known = novel = 0
    buf = String[]
    t0 = time()

    flush_buf = function ()
        isempty(buf) && return
        out = Vector{Union{Nothing,Tuple{Vector{UInt8},String}}}(nothing, length(buf))
        Threads.@threads for i in eachindex(buf)
            lut = Vector{Int}(undef, 1 << N)
            parse_lut_line!(lut, buf[i]) || continue
            F = SBox{N}(lut)
            (differential_uniformity(F) == 2 && algebraic_degree(F) == 2) || continue
            out[i] = (encode_quadratic(F; modulus = MOD8, verify = false, powtab = powtab),
                      sigma_hash(F))
        end
        for i in eachindex(buf)
            r = out[i]
            if r === nothing
                # distinguish a malformed line from a well-formed non-member
                lut = Vector{Int}(undef, 1 << N)
                if parse_lut_line!(lut, buf[i])
                    notqapn += 1
                else
                    malformed += 1
                end
                continue
            end
            enc, sh = r
            if enc in seen
                dup += 1
                continue
            end
            push!(seen, enc)
            push!(encs, enc)
            if baseline !== nothing
                if sh in baseline
                    known += 1
                else
                    novel += 1
                    push!(newsig, sh)
                end
            end
        end
        empty!(buf)
        GC.gc(false)
        el = time() - t0
        println("  … $(lines) lines, $(length(encs)) accepted, ",
                "$(round(lines / max(el, 1e-9); digits = 0)) lines/s")
        flush(stdout)
    end

    open(path, "r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            lines += 1
            push!(buf, line)
            length(buf) >= batch && flush_buf()
        end
    end
    flush_buf()

    (encs, ImportStats(lines, malformed, notqapn, dup, length(encs),
                       known, novel, length(newsig)))
end

function ensure_bib!(db::SQLite.DB, key::AbstractString)
    entry = nothing
    for e in load_bibliography()
        e.bib_key == key && (entry = e; break)
    end
    entry === nothing && error("bib key $key not in bibliography.bib")
    io = IOBuffer()
    print(io, "@", entry.entry_type, "{", entry.bib_key)
    for (k, v) in sort(collect(entry.fields); by = first)
        print(io, ",\n    ", k, " = {", v, "}")
    end
    print(io, "\n}")
    fld(k) = haskey(entry.fields, k) ? entry.fields[k] : ""
    SQLite.execute(db, string(
        "INSERT OR IGNORE INTO bibliography (bib_key, bibtex, doi, url, year, authors) VALUES (",
        VBFCatalog._sql_quote(entry.bib_key), ", ",
        VBFCatalog._sql_quote(String(take!(io))), ", ",
        VBFCatalog._sql_quote(fld("doi")), ", ",
        VBFCatalog._sql_quote(fld("url")), ", ",
        parse(Int, strip(isempty(fld("year")) ? "0" : fld("year"))), ", ",
        VBFCatalog._sql_quote(fld("author")), ")"))
end

function main()
    with_source("beierle2025") do dir
        path = joinpath(dir, "new_apns.txt")
        isfile(path) || error("beierle2025: $path not found")
        bfa_sha = try
            readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`)
        catch
            "unknown"
        end
        added = string(Dates.now(Dates.UTC)) * "Z"
        @info "Beierle 2025 import" path bytes=filesize(path) threads=Threads.nthreads()

        baseline = sigma_baseline(N)
        if baseline === nothing
            @warn "no complete σ-index; the novelty tally is SKIPPED " *
                  "(build it with build_sigma_index.jl, then re-run)"
        else
            println("[beierle2025] novelty baseline: $(length(baseline)) distinct σ at n=$N")
        end

        powtab = monomial_power_table(N, MOD8)
        t = @elapsed ((encs, st) = stream_members(path; baseline = baseline, powtab = powtab))
        isempty(encs) && error("beierle2025: no quadratic-APN members parsed from $path")

        println("[beierle2025] parsed in $(round(t; digits = 1))s: ",
                "lines=$(st.lines) accepted=$(st.accepted) duplicate=$(st.duplicate) ",
                "non-quadratic-APN=$(st.not_quadratic_apn) malformed=$(st.malformed)")
        if baseline !== nothing
            println("[beierle2025] novelty: $(st.sigma_new) members have a σ absent from the ",
                    "catalog ($(st.distinct_sigma_new) distinct new σ); ",
                    "$(st.sigma_known) share a σ with an existing entry")
        end

        # spot-check the round trip on a sample: the bulk encode runs verify=false
        for i in (1, cld(length(encs), 2), length(encs))
            F = SBox{N}(decode_quadratic_lut(encs[i], N, MOD8; powtab = powtab))
            differential_uniformity(F) == 2 ||
                error("beierle2025: member $i is not APN after the round trip")
            algebraic_degree(F) == 2 ||
                error("beierle2025: member $i is not quadratic after the round trip")
        end

        db = load_catalog()
        try
            ensure_bib!(db, BIB_KEY)
            store = build_corpus_store!(CORPUS, encs)
            notes = string(
                "Beierle, Langevin, Leander, Polujan, Rasoolzadeh (2025), ",
                "arXiv:2508.04644 / Zenodo 16752428 (new_apns.txt): ",
                st.accepted, " pairwise inequivalent quadratic APN functions over GF(2^8) ",
                "(EA = CCZ for quadratic APN, Yoshiara). ",
                baseline === nothing ? "Novelty not tallied at import time." :
                    string(st.sigma_new, " members carry a σ-signature absent from the ",
                           "pre-import catalog, certifying them CCZ-inequivalent to every ",
                           "catalogued function. "),
                "The side store is REGENERABLE and not committed: rebuild it with ",
                "`make -C packages/VBFCatalog/data-build beierle2025` and BFA_BEIERLE2025_PATH ",
                "pointing at a directory holding new_apns.txt.")
            register_corpus!(db;
                name = CORPUS, n = N, m = N, member_count = store.count, degree = 2,
                modulus = MOD8, encoding = "quadratic-coeffs-v1",
                bytes_per_member = store.bytes_per_member,
                store_file = "corpora/" * CORPUS * ".sqlite", store_sha256 = store.sha256,
                family = "quadratic-apn-8bit", bib_key = BIB_KEY,
                source_repo = "bfa@$bfa_sha|zenodo-16752428",
                contributor = "BFA Beierle-2025 bulk import (automated)",
                added_date = added, notes = notes)
            println("[beierle2025] corpus=$(CORPUS) members=$(store.count) ",
                    "bytes/member=$(store.bytes_per_member) ",
                    "store=$(round(filesize(store.path) / 2^20; digits = 1)) MiB ",
                    "sha256=$(store.sha256)")
        finally
            close(db)
        end
    end
    return nothing
end

if !isinteractive() && get(ENV, "BFA_BEIERLE2025_NO_AUTORUN", "0") != "1"
    main()
end
