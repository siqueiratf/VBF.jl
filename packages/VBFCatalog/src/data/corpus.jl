"""
Bulk-corpus access. Large function families (hundreds of thousands to millions
of members) are kept OUT of the `functions` table — which would bloat the
committed catalog by gigabytes — and instead recorded as a single descriptor
row in `bulk_corpora`, with the members held in a compact, content-addressed
**side store** under `corpora/<name>.sqlite`. Each member is stored as a packed
encoding (currently `quadratic-coeffs-v1`: the weight-≤2 univariate coefficients,
`VBF.encode_quadratic`); its full LUT is reconstructed on demand via
`VBF.decode_quadratic_lut`. Full 2ⁿ-byte LUTs are materialised lazily into a
scratch cache, never committed.
"""

import SQLite
import DBInterface
import SHA
import Scratch

# `corpora/` sits at the VBFCatalog package root (this file is `src/data/`).
_corpora_dir() = normpath(joinpath(@__DIR__, "..", "..", "corpora"))

"""
    corpus_store_path(name) -> String

Path to the committed side store `corpora/<name>.sqlite` (the compact encodings).
"""
corpus_store_path(name::AbstractString) =
    joinpath(_corpora_dir(), String(name) * ".sqlite")

_row_namedtuple(r) = (; (c => getproperty(r, c) for c in propertynames(r))...)

"""
    list_corpora(db) -> Vector{String}

Names of the registered bulk corpora.
"""
list_corpora(db::SQLite.DB) = [
    String(r.name) for r in
    DBInterface.execute(db, "SELECT name FROM bulk_corpora ORDER BY name")
]

"""
    corpus_info(db, name) -> NamedTuple | nothing

The `bulk_corpora` descriptor row for `name` (or `nothing`).
"""
function corpus_info(db::SQLite.DB, name::AbstractString)
    sql =
        "SELECT * FROM bulk_corpora WHERE name = " *
        _sql_quote(String(name)) *
        " LIMIT 1"
    q = DBInterface.execute(db, sql)
    try
        for r in q
            return _row_namedtuple(r)
        end
        nothing
    finally
        DBInterface.close!(q)
    end
end

"""
    corpus_length(db, name) -> Int

Number of members in corpus `name` (0 if unknown).
"""
corpus_length(db::SQLite.DB, name::AbstractString) =
    (i = corpus_info(db, name); i === nothing ? 0 : Int(i.member_count))

"""
    corpus_coefficients(name, i) -> Vector{UInt8}

The packed encoding of member `i` (1-based) read from the side store.
"""
function corpus_coefficients(name::AbstractString, i::Integer)
    path = corpus_store_path(name)
    isfile(path) || error("corpus '$name': side store not found at $path")
    store = SQLite.DB(path)
    try
        for r in DBInterface.execute(
            store,
            "SELECT coeffs FROM members WHERE idx = $(Int(i)) LIMIT 1",
        )
            return Vector{UInt8}(r.coeffs)
        end
    finally
        close(store)
    end
    error("corpus '$name': no member at index $i")
end

"""
    corpus_function(db, name, i) -> SBox

Reconstruct member `i` (1-based) of corpus `name` as an `SBox`, decoding its
compact encoding to a LUT over the corpus' `GF(2ⁿ)` field.
"""
function corpus_function(db::SQLite.DB, name::AbstractString, i::Integer)
    info = corpus_info(db, name)
    info === nothing && error("unknown corpus '$name'")
    n = Int(info.n)
    mod = Int(info.modulus)
    lut = decode_quadratic_lut(corpus_coefficients(name, i), n, mod)
    SBox{n}(lut)
end

# ----- building / registering (dev-time importers) --------------------------

"""
    build_corpus_store!(name, encodings) -> NamedTuple

Create the side store `corpora/<name>.sqlite` (overwriting) with one row per
member, `members(idx INTEGER PRIMARY KEY, coeffs BLOB)`, from an iterable of
`Vector{UInt8}` `encodings` (in order). Returns
`(; path, sha256, count, bytes_per_member)`.
"""
function build_corpus_store!(name::AbstractString, encodings)
    mkpath(_corpora_dir())
    path = corpus_store_path(name)
    isfile(path) && rm(path)
    store = SQLite.DB(path)
    try
        SQLite.execute(
            store,
            "CREATE TABLE members (idx INTEGER PRIMARY KEY, coeffs BLOB NOT NULL)",
        )
        SQLite.execute(store, "BEGIN")
        idx = 0
        bpm = 0
        for enc in encodings
            idx += 1
            bpm = length(enc)
            SQLite.execute(
                store,
                "INSERT INTO members (idx, coeffs) VALUES ($idx, X'" *
                bytes2hex(enc) *
                "')",
            )
        end
        SQLite.execute(store, "COMMIT")
    finally
        close(store)
    end
    # count via the file we just wrote
    cnt = 0
    bpm = 0
    let s = SQLite.DB(path)
        try
            for r in DBInterface.execute(
                s,
                "SELECT COUNT(*) c, MAX(LENGTH(coeffs)) b FROM members",
            )
                cnt = Int(r.c)
                bpm = r.b === missing ? 0 : Int(r.b)
            end
        finally
            close(s)
        end
    end
    sha = bytes2hex(SHA.sha256(read(path)))
    (; path = path, sha256 = sha, count = cnt, bytes_per_member = bpm)
end

"""
    register_corpus!(db; name, n, m, member_count, degree, modulus, encoding,
                     bytes_per_member, store_file, store_sha256, family, bib_key,
                     source_repo, contributor, added_date, notes) -> Nothing

Insert the `bulk_corpora` descriptor row (replacing any existing row of the same
name).
"""
function register_corpus!(
    db::SQLite.DB;
    name,
    n,
    m,
    member_count,
    degree,
    modulus,
    encoding,
    bytes_per_member,
    store_file,
    store_sha256,
    family,
    bib_key,
    source_repo,
    contributor,
    added_date,
    notes,
)
    SQLite.execute(
        db,
        "DELETE FROM bulk_corpora WHERE name = " * _sql_quote(String(name)),
    )
    bib = bib_key === nothing ? "NULL" : _sql_quote(String(bib_key))
    SQLite.execute(
        db,
        string(
            "INSERT INTO bulk_corpora (name, n, m, member_count, degree, modulus, ",
            "encoding, bytes_per_member, store_file, store_sha256, family, bib_key, ",
            "source_repo, contributor, added_date, notes) VALUES (",
            _sql_quote(String(name)),
            ", ",
            Int(n),
            ", ",
            Int(m),
            ", ",
            Int(member_count),
            ", ",
            Int(degree),
            ", ",
            Int(modulus),
            ", ",
            _sql_quote(String(encoding)),
            ", ",
            Int(bytes_per_member),
            ", ",
            _sql_quote(String(store_file)),
            ", ",
            _sql_quote(String(store_sha256)),
            ", ",
            _sql_quote(String(family)),
            ", ",
            bib,
            ", ",
            _sql_quote(String(source_repo)),
            ", ",
            _sql_quote(String(contributor)),
            ", ",
            _sql_quote(String(added_date)),
            ", ",
            _sql_quote(String(notes)),
            ")",
        ),
    )
    nothing
end

# ----- on-demand full-LUT materialisation (the "big store") -----------------

_lut_cache_dir() = Scratch.get_scratch!(@__MODULE__, "corpus_luts")

"""
    materialize_corpus_luts(db, name; path=<scratch>) -> String

Reconstruct every member's full LUT and write them to a side sqlite
`members(idx INTEGER PRIMARY KEY, lut BLOB)` at `path` (default: a scratch cache,
never committed). Returns the path. This is the heavy "full-LUT" store; most uses
only need `corpus_function` (per-member, on the fly).
"""
function materialize_corpus_luts(
    db::SQLite.DB,
    name::AbstractString;
    path::AbstractString = joinpath(
        _lut_cache_dir(),
        String(name) * "_luts.sqlite",
    ),
)
    info = corpus_info(db, name)
    info === nothing && error("unknown corpus '$name'")
    n = Int(info.n)
    mod = Int(info.modulus)
    powtab = monomial_power_table(n, mod)
    isfile(path) && rm(path)
    out = SQLite.DB(path)
    src = SQLite.DB(corpus_store_path(name))
    try
        SQLite.execute(
            out,
            "CREATE TABLE members (idx INTEGER PRIMARY KEY, lut BLOB NOT NULL)",
        )
        SQLite.execute(out, "BEGIN")
        for r in DBInterface.execute(
            src,
            "SELECT idx, coeffs FROM members ORDER BY idx",
        )
            lut = decode_quadratic_lut(
                Vector{UInt8}(r.coeffs),
                n,
                mod;
                powtab = powtab,
            )
            s = SBox{n}(lut)
            SQLite.execute(
                out,
                "INSERT INTO members (idx, lut) VALUES ($(Int(r.idx)), X'" *
                bytes2hex(canonical_lut_bytes(s)) *
                "')",
            )
        end
        SQLite.execute(out, "COMMIT")
    finally
        close(src)
        close(out)
    end
    path
end
