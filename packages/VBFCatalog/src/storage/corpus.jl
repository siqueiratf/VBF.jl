"""
Bulk-corpus access. Large function families (hundreds of thousands to millions
of members) are kept OUT of the `functions` table — which would bloat the
committed catalog by gigabytes — and instead recorded as a single descriptor
row in `bulk_corpora`, with compact members in the catalog's `corpus_members`
table or the shared local `packages/VBFCatalog/data/members.sqlite`. Each member is packed
encoding (currently `quadratic-coeffs-v1`: the weight-≤2 univariate coefficients,
`VBF.encode_quadratic`); its full LUT is reconstructed on demand via
`VBF.decode_quadratic_lut`. Full 2ⁿ-byte LUTs are materialised lazily into a
scratch cache, never committed.
"""

import SQLite
import DBInterface
import SHA
import Scratch

"""Directory for downloaded bulk records and regenerable indexes.

Override with `BFA_DATA_DIR`; defaults to the workspace's `packages/VBFCatalog/data/`.
"""
catalog_data_dir() = abspath(get(ENV, "BFA_DATA_DIR", joinpath(pkgdir(VBFCatalog), "data")))

"""Path holding a corpus: the catalog itself or the local bulk database."""
function corpus_store_path(db::SQLite.DB, name::AbstractString)
    info = corpus_info(db, name)
    info === nothing && throw(ArgumentError("unknown corpus '$name'"))
    info.store_file in ("catalog","members.sqlite") || error("unsupported corpus store: $(info.store_file)")
    info.store_file == "catalog" ? catalog_path(db) : joinpath(catalog_data_dir(), info.store_file)
end

"""Register verified packed members against a checksum-bound dataset declaration."""
function _register_declared_corpus!(db,entry,store;source_repo=get(entry,"source_repo",get(entry,"source","immutable input")))
    store.count==entry["count"] || error("$(entry["name"]): source member count mismatch")
    get(entry,"packed_sha256",store.sha256)==store.sha256 || error("$(entry["name"]): packed digest mismatch")
    register_corpus!(db;name=entry["name"],n=8,m=8,degree=2,modulus=conway_polynomial(8),
        encoding="quadratic-coeffs-v1",member_count=store.count,bytes_per_member=store.bytes_per_member,
        store_file=store.store_file,store_sha256=store.sha256,family=get(entry,"family","quadratic-apn-8bit"),
        bib_key=get(entry,"bib_key",nothing),source_repo,contributor="VBFCatalog source import",
        added_date="",notes=entry["notes"])
    nothing
end
function corpus_store_path(name::AbstractString)
    db = load_catalog()
    try
        corpus_store_path(db, name)
    finally
        close(db)
    end
end

"""Visit packed corpus rows in increasing member order with a scoped cursor.

`f(rows)` must consume the cursor before returning. Missing stores are errors;
this API never creates an empty input database.
"""
function with_corpus_rows(f::Function, db::SQLite.DB, name::AbstractString; after::Integer=0)
    after>=0 || throw(ArgumentError("member offset must be nonnegative"))
    info=corpus_info(db,name)
    info===nothing && error("unknown corpus '$name'")
    path = corpus_store_path(db, name)
    isfile(path) || error("corpus '$name': store not found at $path")
    store = path == catalog_path(db) ? db : SQLite.DB("file:" * abspath(path) * "?mode=ro")
    rows = DBInterface.execute(store,
        "SELECT idx,coeffs FROM corpus_members WHERE corpus=? AND idx>=COALESCE(" *
        "(SELECT MAX(idx) FROM corpus_members WHERE corpus=? AND idx<=?),1) ORDER BY idx",
        (name,name,after))
    try
        f(Iterators.flatten(_corpus_chunk(row,Int(info.bytes_per_member),after) for row in rows))
    finally
        DBInterface.close!(rows)
        store === db || close(store)
    end
end

"""Expand a packed chunk while keeping copied bytes valid beyond the SQLite cursor."""
function _corpus_chunk(row,width,after)
    bytes=Vector{UInt8}(row.coeffs);start=Int(row.idx)
    width>0 && length(bytes)%width==0 || error("invalid packed corpus chunk")
    ((idx=start+i,coeffs=@view(bytes[i*width+1:(i+1)*width]))
        for i in max(0,after-start+1):(length(bytes)÷width-1))
end

"""SHA-256 of concatenated packed members in increasing idx order.

The digest binds record order and encoding bytes, independently of SQLite page
layout. Metadata supplies the fixed record size and count. No equivalence or
mathematical correctness is implied by this transport checksum.
"""
function corpus_digest(db::SQLite.DB, name::AbstractString)
    ctx = SHA.SHA2_256_CTX()
    with_corpus_rows(db, name) do rows
        for row in rows
            SHA.update!(ctx, row.coeffs)
        end
    end
    bytes2hex(SHA.digest!(ctx))
end

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
    corpus_coefficients(db, name, i) -> Vector{UInt8}

The packed encoding of member `i` (1-based) read from the side store.
"""
function corpus_coefficients(db::SQLite.DB, name::AbstractString, i::Integer)
    i > 0 || throw(ArgumentError("member index must be positive"))
    with_corpus_rows(db, name; after=i-1) do rows
        for row in rows
            row.idx == i || break
            return Vector{UInt8}(row.coeffs)
        end
        throw(BoundsError(name, i))
    end
end
function corpus_coefficients(name::AbstractString, i::Integer)
    db = load_catalog()
    try
        corpus_coefficients(db, name, i)
    finally
        close(db)
    end
end

"""
    corpus_function(db, name, i) -> SBox

Reconstruct member `i` (1-based) of corpus `name` as an `SBox`, decoding its
compact encoding to a LUT over the corpus' `GF(2ⁿ)` field.
"""
function corpus_function(db::SQLite.DB, name::AbstractString, i::Integer;powtab=nothing)
    info = corpus_info(db, name)
    info === nothing && error("unknown corpus '$name'")
    n = Int(info.n)
    mod = Int(info.modulus)
    lut = decode_quadratic_lut(corpus_coefficients(db, name, i), n, mod;powtab)
    SBox{n}(lut)
end

# ----- building / registering (dev-time importers) --------------------------

"""
    build_corpus_store!(name, encodings) -> NamedTuple

Replace the named corpus's packed records transactionally. Other corpora are
retained. By default records enter the staging catalog; `external=true` uses
the shared local bulk database. Returns its location, ordered content digest,
count and fixed encoding size. Registration supplies the dataset metadata.
"""
function build_corpus_store!(name::AbstractString, encodings; external::Bool=false)
    db = load_catalog()
    path = external ? joinpath(catalog_data_dir(), "members.sqlite") : catalog_path(db)
    external && mkpath(dirname(path))
    store = external ? SQLite.DB(path) : db
    ctx = SHA.SHA2_256_CTX(); count = 0; bytes_per_member = 0
    chunk=UInt8[];chunk_start=1
    try
        SQLite.execute(store, "CREATE TABLE IF NOT EXISTS corpus_members (corpus TEXT NOT NULL, idx INTEGER NOT NULL CHECK(idx>0), coeffs BLOB NOT NULL, PRIMARY KEY(corpus,idx)) WITHOUT ROWID")
        SQLite.transaction(store) do
            DBInterface.execute(store, "DELETE FROM corpus_members WHERE corpus=?", (name,))
            statement = DBInterface.prepare(store, "INSERT INTO corpus_members VALUES(?,?,?)")
            try
                for enc in encodings
                    count += 1
                    count == 1 && (bytes_per_member = length(enc))
                    length(enc) == bytes_per_member && bytes_per_member > 0 || error("inconsistent corpus encoding size")
                    SHA.update!(ctx, enc)
                    if external
                        DBInterface.execute(statement, (name, count, enc))
                    else
                        append!(chunk,enc)
                        if count-chunk_start+1==1024
                            DBInterface.execute(statement,(name,chunk_start,chunk))
                            empty!(chunk);chunk_start=count+1
                        end
                    end
                end
                isempty(chunk) || DBInterface.execute(statement,(name,chunk_start,chunk))
            finally
                DBInterface.close!(statement)
            end
            count > 0 || error("empty corpus")
        end
    finally
        store === db || close(store)
        close(db)
    end
    (; path, store_file=external ? "members.sqlite" : "catalog",
       sha256=bytes2hex(SHA.digest!(ctx)), count, bytes_per_member)
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
            _sql_quote(""),
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
    abspath(path) in (catalog_path(db), abspath(corpus_store_path(db,name))) &&
        throw(ArgumentError("materialization cannot overwrite its catalog or corpus input"))
    isfile(path) && rm(path)
    out = SQLite.DB(path)
    try
        SQLite.execute(
            out,
            "CREATE TABLE members (idx INTEGER PRIMARY KEY, lut BLOB NOT NULL)",
        )
        SQLite.execute(out, "BEGIN")
        with_corpus_rows(db, name) do rows
        for r in rows
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
        end
        SQLite.execute(out, "COMMIT")
    finally
        close(out)
    end
    path
end
