"""
SQLite catalog of every cryptographic function known to BFA.

# Schema philosophy
The catalog is **content-addressed by `lut_sha256`** and **provenance-tagged**:
every row carries `(family, n, lut_blob, bib_key, source_repo, contributor,
added_date)` so any computed statistic can be traced back to its
primary specification.

The schema DDL lives in `src/data/schema.sql` (authoritative) and is
embedded as `SCHEMA_DDL` (a constant string) so the package can rebuild
a catalog from scratch without reading a separate file. Schema version
bumps require both an incremented `schema_version` value *and* a
migration script under `data-build/migrations/`.

# Public surface
- [`SCHEMA_VERSION`](@ref)  — the version this code understands.
- [`catalog_path`](@ref)    — default on-disk location of the catalog.
- [`load_catalog`](@ref)    — open an existing SQLite catalog.
- [`create_catalog`](@ref)  — create a fresh (empty) catalog at the
  given path; used by `data-build/build_catalog.jl`.
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
const SCHEMA_VERSION = 1

"""
    SCHEMA_DDL :: String

Authoritative DDL embedded at package-build time. Identical content to
`src/data/schema.sql`.
"""
const SCHEMA_DDL = read(joinpath(@__DIR__, "schema.sql"), String)

"""
    catalog_path() -> String

Default location of the SQLite catalog (`BFA_catalog.sqlite` at the
package root).
"""
catalog_path() = normpath(joinpath(@__DIR__, "..", "..", "BFA_catalog.sqlite"))

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
function canonical_lut_bytes(s::SBox{N, T}) where {N, T}
    bytes_per_entry = cld(N, 8)
    n = 1 << N
    out = Vector{UInt8}(undef, n * bytes_per_entry)
    @inbounds for (i, v) in pairs(s.lut)
        offset = (i - 1) * bytes_per_entry
        vi = UInt(v)
        for b in 0:bytes_per_entry - 1
            out[offset + b + 1] = UInt8((vi >> (8 * b)) & 0xff)
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
    create_catalog(path::AbstractString; bfa_version, git_sha)

Initialise a fresh SQLite catalog at `path` with the embedded
[`SCHEMA_DDL`](@ref). The single `schema_meta` row is populated with
`SCHEMA_VERSION`, the current UTC time, and the caller-supplied
`bfa_version` / `git_sha` strings. Overwrites any existing file.
"""
function create_catalog(path::AbstractString;
                         bfa_version::AbstractString = "0.1.0-DEV",
                         git_sha::AbstractString = "unknown")
    isfile(path) && rm(path)
    db = SQLite.DB(path)
    # Use SQLite.execute, not DBInterface.execute, for write statements:
    # DBInterface.execute returns a Cursor that holds resources until GC,
    # which under --check-bounds=yes can block the implicit transaction
    # commit. SQLite.execute returns nothing and releases the statement
    # synchronously — what we want for DDL + writes.
    for stmt in _split_ddl(SCHEMA_DDL)
        isempty(strip(stmt)) && continue
        SQLite.execute(db, stmt)
    end
    # Internal-only values (never user input) — safe to inline rather
    # than parameter-bind. Avoids further interactions with the SQLite.jl
    # 1.8 cursor lifetime issue.
    SQLite.execute(
        db,
        string(
            "INSERT INTO schema_meta (schema_version, built_at, bfa_version, git_sha) VALUES (",
            Int(SCHEMA_VERSION), ", ",
            _sql_quote(_utc_now_iso()), ", ",
            _sql_quote(String(bfa_version)), ", ",
            _sql_quote(String(git_sha)), ")"))
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
        msg = string("BFA catalog not found at ", path, " — run\n",
                     "    julia --project=", pkg_root, " data-build/build_catalog.jl\n",
                     "to create it")
        throw(ArgumentError(msg))
    end
    db = SQLite.DB(path)
    _verify_schema!(db, path)
    db
end

function _verify_schema!(db::SQLite.DB, path::AbstractString)
    # SQLite.jl 1.4–1.8 anti-pattern: `collect(DBInterface.execute(...))` yields
    # stale Row references because the cursor moves past the last row by the
    # time `collect` returns. Always extract values inside the iteration loop
    # (or use `first()` for single-row results).
    v = nothing
    found = false
    for r in DBInterface.execute(db, "SELECT schema_version FROM schema_meta LIMIT 1")
        v = r.schema_version
        found = true
        break
    end
    found ||
        throw(ArgumentError("$path has no schema_meta row — catalog is empty or corrupted"))
    isequal(v, SCHEMA_VERSION) ||
        throw(ArgumentError(
            "$path has schema_version $v but this BFA expects $SCHEMA_VERSION; " *
            "re-run data-build/build_catalog.jl"))
    db
end

# Naive SQL splitter: SQLite.jl's execute() handles only one statement at a
# time. The schema DDL is a static, human-written file with no semicolons
# in string literals, so splitting on ";" is safe here.
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
