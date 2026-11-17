# The query database of the online catalog, schema vbf-query-1 (see docs/portal/POC.md).
#
# A browser reads it over HTTP Range requests, so every online query must use an index:
#   members(corpus_id, idx)   member by position              (primary key)
#   members(lut_sha256)       corpora of a concrete function   (members_lut)
#   members(sigma)            members with a signature         (members_sigma)
#   functions(lut_sha256), functions(n, is_apn, family)
# Identity is the full SHA-256 of the canonical LUT bytes (identity.jl). A signature is an
# invariant key, never an identity: equal signatures prove nothing (equivalence.jl).

const QUERY_SCHEMA = "vbf-query-1"

const QUERY_DDL = [
    "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID",
    """CREATE TABLE corpora (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, digest TEXT NOT NULL,
        n INTEGER NOT NULL, m INTEGER NOT NULL, member_count INTEGER NOT NULL, encoding TEXT NOT NULL,
        modulus INTEGER NOT NULL, bib_key TEXT, source_repo TEXT NOT NULL)""",
    """CREATE TABLE functions (id INTEGER PRIMARY KEY, n INTEGER NOT NULL, m INTEGER NOT NULL,
        lut_sha256 BLOB NOT NULL, family TEXT NOT NULL, canonical_name TEXT, algebraic_degree INTEGER,
        differential_uniformity INTEGER, linearity INTEGER, boomerang_uniformity INTEGER,
        is_apn INTEGER NOT NULL, is_permutation INTEGER NOT NULL, is_quadratic INTEGER NOT NULL,
        sigma BLOB, bib_key TEXT)""",
    """CREATE TABLE members (corpus_id INTEGER NOT NULL, idx INTEGER NOT NULL, coeffs BLOB NOT NULL,
        lut_sha256 BLOB NOT NULL, sigma BLOB, PRIMARY KEY (corpus_id, idx)) WITHOUT ROWID""",
    """CREATE TABLE refs (bib_key TEXT PRIMARY KEY, year INTEGER, title TEXT, doi TEXT) WITHOUT ROWID""",
]
const QUERY_INDEXES = [
    "CREATE INDEX members_lut ON members(lut_sha256)",
    "CREATE INDEX members_sigma ON members(sigma)",
    "CREATE INDEX functions_lut ON functions(lut_sha256)",
    "CREATE INDEX functions_filter ON functions(n, is_apn, family)",
]

"""Signature of each indexed member and curated function: (source, member_idx) => 32 bytes."""
function _signatures(index_path)
    d = Dict{Tuple{String,Int},Vector{UInt8}}()
    isfile(index_path) || return d
    idx = SQLite.DB("file:" * index_path * "?mode=ro")
    try
        for r in DBInterface.execute(idx, "SELECT source, member_idx, sigma_hash FROM ccz_sigma_index")
            d[(String(r.source), Int(r.member_idx))] = hex2bytes(r.sigma_hash)
        end
    finally
        close(idx)
    end
    d
end

"""
    build_query_db(out, db; corpora=nothing, index_path, page_size=4096) -> NamedTuple

Write the query database of the catalog `db` to `out`. Each member gets its content key (the
full SHA-256 of its decoded LUT) and, when the signature index has it, its signature.
`corpora` restricts the corpora (default: all). Returns counts and the file size.
"""
function build_query_db(out, db; corpora = nothing, index_path = sigma_index_path(), page_size = 4096,
                        prebuilt_key = VBFCatalog._prebuilt_key())
    rm(out; force = true)
    sig = _signatures(index_path)
    q = SQLite.DB(out)
    SQLite.execute(q, "PRAGMA page_size = $page_size")
    SQLite.execute(q, "PRAGMA journal_mode = DELETE")
    foreach(d -> SQLite.execute(q, d), QUERY_DDL)
    meta = only(NamedTuple(r) for r in DBInterface.execute(db, "SELECT * FROM schema_meta"))
    names = corpora === nothing ? list_corpora(db) : collect(corpora)
    nmembers = 0
    SQLite.transaction(q) do
        for (k, v) in ("schema" => QUERY_SCHEMA, "prebuilt_key" => prebuilt_key,
                       "inputs_sha256" => meta.inputs_sha256, "created_utc" => string(Dates.now(Dates.UTC)),
                       "signature_index" => isfile(index_path) ? "present" : "absent")
            DBInterface.execute(q, "INSERT INTO meta VALUES (?, ?)", (k, v))
        end
        for r in DBInterface.execute(db, "SELECT bib_key, year, doi, bibtex FROM bibliography")
            title = match(r"title\s*=\s*\{+(.*?)\}+\s*,"s, r.bibtex)
            DBInterface.execute(q, "INSERT INTO refs VALUES (?,?,?,?)",
                (r.bib_key, r.year, title === nothing ? missing : clean_tex(title[1]), coalesce(r.doi, missing)))
        end
        for r in DBInterface.execute(db, "SELECT * FROM functions ORDER BY id")
            s = get(sig, ("functions", Int(r.id)), nothing)
            DBInterface.execute(q, "INSERT INTO functions VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (r.id, r.n, r.m, hex2bytes(r.lut_sha256), r.family, r.canonical_name, r.algebraic_degree,
                 r.differential_uniformity, r.linearity, r.boomerang_uniformity, r.is_apn, r.is_permutation,
                 r.is_quadratic, s === nothing ? missing : s, r.bib_key))
        end
        stmt = DBInterface.prepare(q, "INSERT INTO members VALUES (?,?,?,?,?)")
        for (cid, name) in enumerate(sort(names))
            info = corpus_info(db, name)
            DBInterface.execute(q, "INSERT INTO corpora VALUES (?,?,?,?,?,?,?,?,?,?)",
                (cid, name, info.store_sha256, info.n, info.m, info.member_count, info.encoding,
                 info.modulus, info.bib_key, info.source_repo))
            n = Int(info.n); powtab = monomial_power_table(n, Int(info.modulus))
            idxs = Int[]; coeffs = Vector{UInt8}[]
            with_corpus_rows(db, name) do it
                for r in it
                    push!(idxs, Int(r.idx)); push!(coeffs, Vector{UInt8}(r.coeffs))
                end
            end
            luts = Vector{Vector{UInt8}}(undef, length(idxs))
            Threads.@threads for j in eachindex(idxs)
                luts[j] = sha256(canonical_lut_bytes(SBox{n}(decode_quadratic_lut(coeffs[j], n, Int(info.modulus); powtab))))
            end
            for j in eachindex(idxs)
                s = get(sig, (name, idxs[j]), nothing)
                DBInterface.execute(stmt, (cid, idxs[j], coeffs[j], luts[j], s === nothing ? missing : s))
            end
            nmembers += length(idxs)
        end
    end
    foreach(d -> SQLite.execute(q, d), QUERY_INDEXES)
    SQLite.execute(q, "ANALYZE")
    SQLite.execute(q, "VACUUM")
    close(q)
    (; members = nmembers, corpora = length(names), bytes = filesize(out))
end
