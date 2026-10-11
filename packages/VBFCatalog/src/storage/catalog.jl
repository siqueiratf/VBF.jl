"""
SQLite catalog of curated cryptographic functions and datasets.

# Schema philosophy
The catalog is **content-addressed by `lut_sha256`** and **provenance-tagged**:
every row carries `(family, n, lut_blob, bib_key, source_repo, contributor,
added_date)` so any computed statistic can be traced back to its
primary specification.

The schema DDL lives in `src/storage/schema.sql` (authoritative) and is
embedded as `SCHEMA_DDL` (a constant string) so the package can rebuild
a catalog from scratch without reading a separate file. Schema version
changes require an incremented `schema_version` and a fresh rebuild.

# Public surface
- [`SCHEMA_VERSION`](@ref)  — the version this code understands.
- [`catalog_path`](@ref)    — default on-disk location of the catalog.
- [`load_catalog`](@ref)    — open an existing SQLite catalog.
- [`create_catalog`](@ref)  — create a fresh (empty) catalog at the
  given path; used by `src/import/build_catalog.jl`.
- [`canonical_lut_bytes`](@ref) — produce the canonical byte serialisation
  of an `SBox` LUT, suitable for hashing or insertion into `lut_blob`.
- [`lut_sha256_hex`](@ref)  — SHA-256 of `canonical_lut_bytes`.
"""

import SQLite
import DBInterface
import SHA
import Dates

"""
    SCHEMA_VERSION :: Int

The schema version this code understands. `load_catalog` refuses
catalogs whose `schema_meta.schema_version` differs.
"""
const SCHEMA_VERSION = 9

"""
    SCHEMA_DDL :: String

Authoritative DDL from `src/storage/schema.sql`.
"""
const SCHEMA_DDL = read(joinpath(@__DIR__, "schema.sql"), String)

"""
    catalog_path() -> String

Default location of the generated SQLite catalog (`packages/VBFCatalog/src/data/catalog.sqlite`).

`ENV["BFA_CATALOG_PATH"]`, when set and non-empty, overrides it. The rebuild in
`src/import/build_catalog.jl` uses that to assemble a new catalog at a temporary
path and verify it before it replaces the committed file, so a rebuild that
cannot reproduce the catalog destroys nothing. Leave the variable unset for
normal use.
"""
function catalog_path()
    override = get(ENV, "BFA_CATALOG_PATH", "")
    isempty(override) || return normpath(override)
    joinpath(catalog_source_dir(), "catalog.sqlite")
end

"""Shared declarative catalog resources in the VBF workspace."""
catalog_source_dir() = abspath(get(ENV,"BFA_SOURCE_DIR",joinpath(pkgdir(VBFCatalog), "src", "data")))

"""Return the actual main database filename, including for read-only URI handles."""
function catalog_path(db::SQLite.DB)
    rows = DBInterface.execute(db, "PRAGMA database_list")
    try
        for row in rows
            row.name == "main" && return String(row.file)
        end
        error("catalog has no main database")
    finally
        DBInterface.close!(rows)
    end
end

"""
    is_catalog_built([path]) -> Bool

`true` iff a non-empty file exists at `path` (or the default catalog
path). Does not validate schema.
"""
is_catalog_built(path::AbstractString = catalog_path()) =
    isfile(path) && filesize(path) > 0

# --- canonical byte serialisation -------------------------------------------

"""
    canonical_lut_bytes(s::SBox{N, T}) -> Vector{UInt8}

Serialise the LUT of `s` to bytes in the canonical convention:
`ceil(m/8)` little-endian bytes per entry, in input order. The
result is what gets hashed for `lut_sha256` and stored in `lut_blob`.

For now `m == n` (square S-boxes only).
"""
function canonical_lut_bytes(s::SBox{N,T}) where {N,T}
    bytes_per_entry = cld(N, 8)
    n = 1 << N
    out = Vector{UInt8}(undef, n * bytes_per_entry)
    @inbounds for (i, v) in pairs(s.lut)
        offset = (i - 1) * bytes_per_entry
        vi = UInt(v)
        for b = 0:(bytes_per_entry-1)
            out[offset+b+1] = UInt8((vi >> (8 * b)) & 0xff)
        end
    end
    out
end

"""
    lut_sha256_hex(s::SBox) -> String

Lowercase hex string of `SHA.sha256(canonical_lut_bytes(s))`. The
catalog's UNIQUE constraint is on `(lut_sha256, n)` so this string is
the deduplication key.
"""
lut_sha256_hex(s::SBox) = bytes2hex(SHA.sha256(canonical_lut_bytes(s)))

# --- create / load / verify -------------------------------------------------

"""
    create_catalog(path::AbstractString; bfa_version, inputs_sha256, implementation_sha256)

Initialise a fresh SQLite catalog at `path` with the embedded
[`SCHEMA_DDL`](@ref). The single `schema_meta` row is populated with
`SCHEMA_VERSION` and the caller-supplied input and implementation digests.
Overwrites any existing file.
"""
function create_catalog(
    path::AbstractString;
    bfa_version::AbstractString = "0.1.0-DEV",
    inputs_sha256::AbstractString = "unknown",
    implementation_sha256::AbstractString = "unknown",
)
    isfile(path) && rm(path)
    db = SQLite.DB(path)
    # Writes use SQLite.execute; DBInterface's Cursor can block the commit.
    for stmt in _split_ddl(SCHEMA_DDL)
        isempty(strip(stmt)) && continue
        SQLite.execute(db, stmt)
    end
    # Internal-only values, safe to inline rather than parameter-bind.
    SQLite.execute(
        db,
        string(
            "INSERT INTO schema_meta (schema_version, inputs_sha256, bfa_version, implementation_sha256) VALUES (",
            Int(SCHEMA_VERSION),
            ", ",
            _sql_quote(String(inputs_sha256)),
            ", ",
            _sql_quote(String(bfa_version)),
            ", ",
            _sql_quote(String(implementation_sha256)),
            ")",
        ),
    )
    db
end

"""
    _sql_quote(s::AbstractString) -> String

SQL-quote `s`: wrap in single quotes, doubling any embedded singles.
Used only for internal, non-user-supplied strings; not a substitute for
parameter binding when handling untrusted input.
"""
_sql_quote(s::AbstractString) = "'" * replace(s, "'" => "''") * "'"

"""
    load_catalog([path]) -> SQLite.DB

Open the SQLite catalog at `path` (defaulting to [`catalog_path`](@ref)).
Throws `ArgumentError` if the file is missing or its `schema_version`
disagrees with [`SCHEMA_VERSION`](@ref).
"""
function load_catalog(path::AbstractString = catalog_path())
    if !isfile(path)
        pkg_root = normpath(joinpath(@__DIR__, "..", ".."))
        msg = string(
            "BFA catalog not found at ",
            path,
            " — run\n",
            "    julia --project=",
            joinpath(pkg_root,"src","import"),
            " ", joinpath(pkg_root,"src","import","build_catalog.jl"), "\n",
            "to create it",
        )
        throw(ArgumentError(msg))
    end
    db = SQLite.DB(path)
    _verify_schema!(db, path)
    db
end

function _verify_schema!(db::SQLite.DB, path::AbstractString)
    v = nothing
    found = false
    q = DBInterface.execute(db, "SELECT schema_version FROM schema_meta LIMIT 1")
    try
        for r in q
            v = r.schema_version
            found = true
            break
        end
    finally
        DBInterface.close!(q)
    end
    found || throw(
        ArgumentError(
            "$path has no schema_meta row — catalog is empty or corrupted",
        ),
    )
    isequal(v, SCHEMA_VERSION) || throw(
        ArgumentError(
            "$path has schema_version $v but this BFA expects $SCHEMA_VERSION; " *
            "re-run src/import/build_catalog.jl",
        ),
    )
    db
end

# Naive SQL splitter: execute() takes one statement; the DDL has no literal ';'.
function _split_ddl(ddl::AbstractString)
    stmts = String[]
    buf = IOBuffer()
    for line in eachline(IOBuffer(ddl))
        sl = strip(line)
        (startswith(sl, "--") || isempty(sl)) && continue
        println(buf, line)
        endswith(sl, ";") || continue
        push!(stmts, String(take!(buf)))
    end
    stmts
end

_utc_now_iso() = string(Dates.now(Dates.UTC)) * "Z"

"""Actual declaration and immutable dataset bytes, independent of the local cache."""
function _declaration_inputs()
    records=NamedTuple[]
    for (dir,_,files) in walkdir(catalog_source_dir()), file in sort(files)
        any(ext->endswith(file,ext),(".toml",".bib",".tsv",".gz")) || continue
        path=joinpath(dir,file)
        push!(records,(source="declarations",path=relpath(path,catalog_source_dir()),
            sha256=bytes2hex(open(SHA.sha256,path)),bytes=filesize(path)))
    end
    sort!(records;by=row->(row.source,row.path))
end

_inputs_digest(records) = bytes2hex(SHA.sha256(join([string(row.source,':',row.path,':',row.sha256,':',row.bytes)
    for row in sort(records;by=row->(row.source,row.path))],"\n")))

"""Rewrite the catalog in a fixed table/key order and bind current declared inputs.

Runtime publication uses the same canonical writer as a clean source rebuild.
Proof history and local indexes are outside this file. Close catalog handles and
hold the publication lease before replacing it.
"""
function finalize_catalog!(path;refresh_inputs=true)
    input=load_catalog(path);output=path*".canonical"
    meta=only(NamedTuple(row) for row in DBInterface.execute(input,"SELECT * FROM schema_meta"))
    records=refresh_inputs ? vcat(_declaration_inputs(),[NamedTuple(row) for row in DBInterface.execute(input,"SELECT * FROM source_inputs WHERE source!='declarations'")]) : NamedTuple[]
    digest=refresh_inputs ? _inputs_digest(records) : meta.inputs_sha256
    target=create_catalog(output;bfa_version=meta.bfa_version,inputs_sha256=digest,
        implementation_sha256=meta.implementation_sha256)
    complete=false
    try
        tables=[String(row.name) for row in DBInterface.execute(input,
            "SELECT name FROM sqlite_master WHERE type='table' AND name!='schema_meta' ORDER BY name")]
        SQLite.transaction(target) do
            for table in tables
                if refresh_inputs && table=="source_inputs"
                    for record in sort(records;by=row->(row.source,row.path))
                        SQLite.execute(target,"INSERT INTO source_inputs VALUES(?,?,?,?)",Tuple(record))
                    end
                    continue
                end
                fields=[NamedTuple(row) for row in DBInterface.execute(input,"PRAGMA table_info($table)")]
                keys=sort(filter(field->field.pk>0,fields);by=field->field.pk)
                order=join([field.name for field in (isempty(keys) ? fields : keys)],",")
                statement=DBInterface.prepare(target,"INSERT INTO $table VALUES("*join(fill("?",length(fields)),",")*")")
                try
                    # Dataset identity is its name. Assign descriptor IDs by name so
                    # publication and a clean rebuild produce the same physical rows.
                    table=="bulk_corpora" && (order="name")
                    for (id,row) in enumerate(DBInterface.execute(input,"SELECT * FROM $table ORDER BY $order"))
                        values=NamedTuple(row)
                        table=="bulk_corpora" && (values=merge(values,(;id)))
                        DBInterface.execute(statement,Tuple(values))
                    end
                finally
                    DBInterface.close!(statement)
                end
            end
        end
        complete=true
    finally
        close(target);close(input)
        complete || rm(output;force=true)
    end
    mv(output,path;force=true)
    nothing
end
